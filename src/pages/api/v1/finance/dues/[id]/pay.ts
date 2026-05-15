export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/**
 * POST /api/v1/finance/dues/:id/pay
 * Manual (offline) payment recording. Supports partial and excess payments.
 * Body: { amount, payment_mode, transaction_ref?, paid_at?, tds_deducted? }
 *
 * Accounting rules:
 *  - alreadyPaid = due.amount_paid ?? 0
 *  - outstanding  = max(0, total_amount - alreadyPaid)
 *  - paidNow      = min(amount, outstanding + 0.005)   -- 0.005 rounding tolerance
 *  - excess       = max(0, amount - outstanding)
 *  - newAmountPaid = alreadyPaid + paidNow
 *  - newStatus    = 'paid' if newAmountPaid >= total_amount - 0.005 else 'partially_paid'
 *
 * Records: payments → payment_allocations → updates maintenance_dues
 * If excess: creates member_credits record
 */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const duesId = params.id ?? '';
    if (!UUID_RE.test(duesId)) {
      return Response.json({ error: 'VALIDATION', message: 'invalid dues id' }, { status: 400 });
    }

    const body = await request.json() as {
      amount?: number;
      payment_mode?: string;
      transaction_ref?: string;
      paid_at?: string;
      tds_deducted?: number;
    };

    if (!body.amount || body.amount <= 0) {
      return Response.json({ error: 'VALIDATION', message: 'amount must be positive' }, { status: 400 });
    }

    const VALID_MODES = ['cash', 'upi', 'cheque', 'neft', 'rtgs', 'online', 'bank_transfer'];
    if (!body.payment_mode || !VALID_MODES.includes(body.payment_mode)) {
      return Response.json({ error: 'VALIDATION', message: `payment_mode must be one of: ${VALID_MODES.join(', ')}` }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: due, error: dueErr } = await sb
      .from('maintenance_dues')
      .select('id, user_id, total_amount, amount_paid, status')
      .eq('id', duesId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (dueErr || !due) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Members can only pay their own dues; exec/admin can pay on behalf
    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');

    if (!isExec && due.user_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    if (due.status === 'paid' || due.status === 'waived') {
      return Response.json({ error: 'CONFLICT', message: `Due is already ${due.status}` }, { status: 409 });
    }

    const totalDue    = Number(due.total_amount);
    const alreadyPaid = Number(due.amount_paid ?? 0);
    const outstanding = Math.max(0, totalDue - alreadyPaid);
    const paidNow     = Math.min(body.amount, outstanding + 0.005);
    const excess      = Math.max(0, body.amount - outstanding);
    const newAmountPaid = alreadyPaid + paidNow;
    const newStatus   = newAmountPaid >= totalDue - 0.005 ? 'paid' : 'partially_paid';

    const paidAt = body.paid_at ? new Date(body.paid_at).toISOString() : new Date().toISOString();

    // INSERT payment (immutable)
    const { data: payment, error: payErr } = await sb
      .from('payments')
      .insert({
        society_id:      SOCIETY_ID,
        dues_id:         duesId,
        user_id:         due.user_id,
        amount:          body.amount,
        payment_mode:    body.payment_mode,
        transaction_ref: body.transaction_ref?.trim() || null,
        paid_at:         paidAt,
        tds_deducted:    body.tds_deducted ?? null,
        status:          'completed',
      })
      .select('id')
      .single();

    if (payErr || !payment) throw Object.assign(new Error(payErr?.message ?? 'payment insert failed'), { status: 500 });

    // INSERT payment allocation
    await sb.from('payment_allocations').insert({
      payment_id:       payment.id,
      dues_id:          duesId,
      amount_allocated: paidNow,
    });

    // UPDATE maintenance_dues
    await sb.from('maintenance_dues')
      .update({ status: newStatus, amount_paid: newAmountPaid, paid_at: newStatus === 'paid' ? paidAt : null })
      .eq('id', duesId)
      .eq('society_id', SOCIETY_ID);

    // If excess, create member credit
    let creditCreated = false;
    if (excess > 0.005) {
      await sb.from('member_credits').insert({
        society_id:    SOCIETY_ID,
        user_id:       due.user_id,
        amount:        Math.round(excess * 100) / 100,
        source_payment: payment.id,
        applied_to_dues: duesId,
        notes:         `Excess from payment ${payment.id.slice(0, 8)}`,
        status:        'available',
      });
      creditCreated = true;
    }

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'PAYMENT',
      resourceType: 'payments',
      resourceId:   payment.id,
      ip:           extractClientIP(request),
      newValues: {
        dues_id: duesId,
        amount: body.amount,
        paid_now: paidNow,
        excess,
        new_status: newStatus,
        payment_mode: body.payment_mode,
      },
    });

    return Response.json({
      payment: { id: payment.id },
      dues_status:    newStatus,
      amount_paid:    newAmountPaid,
      outstanding:    Math.max(0, totalDue - newAmountPaid),
      credit_created: creditCreated,
      excess:         creditCreated ? Math.round(excess * 100) / 100 : 0,
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
