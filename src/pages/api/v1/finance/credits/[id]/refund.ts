export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/**
 * POST /api/v1/finance/credits/:id/refund
 * Exec-only. Creates an immutable payment_refunds record and marks the credit as refunded.
 * Body: { refund_mode, transaction_ref?, notes? }
 *
 * Refund amount equals the full credit amount (partial refunds not supported —
 * split credits first if needed).
 */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');

    if (!isExec) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const creditId = params.id ?? '';
    if (!UUID_RE.test(creditId)) {
      return Response.json({ error: 'VALIDATION', message: 'invalid credit id' }, { status: 400 });
    }

    const body = await request.json() as {
      refund_mode?: string;
      transaction_ref?: string;
      notes?: string;
    };

    const VALID_MODES = ['bank_transfer', 'cheque', 'cash', 'upi'];
    if (!body.refund_mode || !VALID_MODES.includes(body.refund_mode)) {
      return Response.json({
        error: 'VALIDATION',
        message: `refund_mode must be one of: ${VALID_MODES.join(', ')}`,
      }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: credit, error: creditErr } = await sb
      .from('member_credits')
      .select('id, user_id, amount, status, society_id')
      .eq('id', creditId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (creditErr || !credit) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    if (credit.status !== 'available') {
      return Response.json({
        error: 'CONFLICT',
        message: `Credit is already ${credit.status} and cannot be refunded`,
      }, { status: 409 });
    }

    const refundedAt = new Date().toISOString();

    // Insert immutable refund record
    const { data: refund, error: refundErr } = await sb
      .from('payment_refunds')
      .insert({
        society_id:     SOCIETY_ID,
        credit_id:      creditId,
        user_id:        credit.user_id,
        approved_by:    user.id,
        amount:         credit.amount,
        refund_mode:    body.refund_mode,
        transaction_ref: body.transaction_ref?.trim() || null,
        notes:          body.notes?.trim() || null,
        refunded_at:    refundedAt,
      })
      .select('id')
      .single();

    if (refundErr || !refund) {
      throw Object.assign(new Error(refundErr?.message ?? 'refund insert failed'), { status: 500 });
    }

    // Mark credit as refunded
    await sb
      .from('member_credits')
      .update({ status: 'refunded', refunded_at: refundedAt })
      .eq('id', creditId)
      .eq('society_id', SOCIETY_ID);

    // Notify member (non-fatal)
    void sb.from('notifications').insert({
      society_id:      SOCIETY_ID,
      user_id:         credit.user_id,
      title:           'Credit Refunded',
      body:            `Your advance credit of ₹${Number(credit.amount).toLocaleString('en-IN')} has been refunded via ${body.refund_mode.replace('_', ' ')}${body.transaction_ref ? ` (ref: ${body.transaction_ref})` : ''}.`,
      type:            'payment',
      reference_table: 'payment_refunds',
      reference_id:    refund.id,
      is_read:         false,
      channel:         'in_app',
      status:          'sent',
    });

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'PAYMENT',
      resourceType: 'payment_refunds',
      resourceId:   refund.id,
      ip:           extractClientIP(request),
      newValues: {
        credit_id:    creditId,
        member_id:    credit.user_id,
        amount:       credit.amount,
        refund_mode:  body.refund_mode,
        transaction_ref: body.transaction_ref ?? null,
      },
    });

    return Response.json({
      ok:        true,
      refund_id: refund.id,
      amount:    credit.amount,
      refund_mode: body.refund_mode,
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
