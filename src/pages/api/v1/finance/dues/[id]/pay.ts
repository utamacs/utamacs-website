export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_MODES = new Set(['cash','cheque','upi','neft','rtgs','online']);

// POST /api/v1/finance/dues/:id/pay
// Records a payment against a dues record, supporting partial payments and
// advance credits (when paid amount exceeds outstanding balance).
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const duesId = params.id ?? '';
    if (!UUID_RE.test(duesId)) return Response.json({ error: 'VALIDATION', message: 'invalid dues id' }, { status: 400 });

    const body = await request.json();
    const amount = Number(body.amount ?? 0);
    if (!amount || amount <= 0) return Response.json({ error: 'VALIDATION', message: 'amount must be > 0' }, { status: 400 });
    if (!VALID_MODES.has(body.payment_mode)) return Response.json({ error: 'VALIDATION', message: 'invalid payment_mode' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    // Fetch the dues record
    const { data: due, error: dueErr } = await sb
      .from('maintenance_dues')
      .select('id, user_id, total_amount, amount_paid, status, penalty_amount, gst_amount')
      .eq('id', duesId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (dueErr || !due) return Response.json({ error: 'NOT_FOUND', message: 'Dues record not found' }, { status: 404 });
    if (due.status === 'paid' || due.status === 'waived') {
      return Response.json({ error: 'CONFLICT', message: `This dues record is already ${due.status}` }, { status: 409 });
    }

    // Members can only pay their own dues; exec can pay for any member
    const isExec = user.isAdmin ||
      ['executive','secretary','president'].includes(user.portalRole ?? '') ||
      ['executive','admin'].includes(user.role ?? '');
    if (!isExec && due.user_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const alreadyPaid  = Number(due.amount_paid ?? 0);
    const totalDue     = Number(due.total_amount);
    const outstanding  = Math.max(0, totalDue - alreadyPaid);
    const paidNow      = Math.min(amount, outstanding + 0.005); // don't over-allocate beyond due
    const excess       = Math.max(0, amount - outstanding);
    const newAmountPaid = alreadyPaid + paidNow;

    let newStatus: string;
    if (newAmountPaid >= totalDue - 0.005) {
      newStatus = 'paid';
    } else {
      newStatus = 'partially_paid';
    }

    // 1. Insert payment (immutable — no UPDATE/DELETE)
    const { data: payment, error: payErr } = await sb
      .from('payments')
      .insert({
        society_id:      SOCIETY_ID,
        dues_id:         duesId,
        user_id:         due.user_id,
        amount,
        payment_mode:    body.payment_mode,
        transaction_ref: String(body.transaction_ref ?? '').trim() || null,
        tds_deducted:    Number(body.tds_deducted ?? 0),
        recorded_by:     user.id,
        paid_at:         body.paid_at ?? new Date().toISOString(),
      })
      .select()
      .single();

    if (payErr) throw Object.assign(new Error(payErr.message), { status: 500 });

    // 2. Insert payment allocation
    await sb.from('payment_allocations').insert({
      payment_id:       payment.id,
      dues_id:          duesId,
      amount_allocated: paidNow,
    });

    // 3. Update dues: amount_paid, status, paid_at (if now fully paid)
    const duesUpdate: Record<string, unknown> = { amount_paid: newAmountPaid, status: newStatus };
    if (newStatus === 'paid') duesUpdate.paid_at = payment.paid_at;
    await sb.from('maintenance_dues').update(duesUpdate).eq('id', duesId);

    // 4. If excess amount, create a member credit
    let credit = null;
    if (excess > 0.005) {
      const { data: creditRow } = await sb
        .from('member_credits')
        .insert({
          society_id:     SOCIETY_ID,
          user_id:        due.user_id,
          amount:         Math.round(excess * 100) / 100,
          source_payment: payment.id,
          notes:          `Advance credit from payment ${payment.receipt_number}`,
        })
        .select()
        .single();
      credit = creditRow;
    }

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId:    user.id,
      action:    'PAYMENT',
      resourceType: 'payments',
      resourceId:   payment.id,
      newValues: { amount, payment_mode: body.payment_mode, dues_id: duesId, new_status: newStatus },
      ip: extractClientIP(request),
    });

    return Response.json({
      payment,
      dues_status:   newStatus,
      amount_paid:   newAmountPaid,
      outstanding:   Math.max(0, totalDue - newAmountPaid),
      credit_created: credit ? { id: credit.id, amount: credit.amount } : null,
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
