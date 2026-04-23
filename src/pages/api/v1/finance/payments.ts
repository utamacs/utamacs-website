import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'payments', 'create',
    );

    const body = await request.json() as {
      dues_id?: string;
      amount?: number;
      payment_mode?: string;
      transaction_ref?: string;
      paid_at?: string;
      tds_deducted?: number;
    };

    if (!body.dues_id || !body.amount || !body.payment_mode) {
      return new Response(JSON.stringify({ error: 'dues_id, amount and payment_mode are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify the due belongs to this society
    const { data: due, error: dueErr } = await sb
      .from('maintenance_dues')
      .select('id, user_id, total_amount, status')
      .eq('id', body.dues_id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (dueErr || !due) {
      return new Response(JSON.stringify({ error: 'Due not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }

    // Members can only pay their own dues
    if (user.role === 'member' && due.user_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
    }

    const { data: payment, error: payErr } = await sb
      .from('payments')
      .insert({
        society_id: SOCIETY_ID,
        dues_id: body.dues_id,
        user_id: due.user_id,
        amount: body.amount,
        payment_mode: body.payment_mode,
        transaction_ref: body.transaction_ref ?? null,
        tds_deducted: body.tds_deducted ?? 0,
        recorded_by: user.id,
        paid_at: body.paid_at ?? new Date().toISOString(),
      })
      .select()
      .single();

    if (payErr) throw Object.assign(new Error(payErr.message), { status: 500 });

    // Update due status
    const newStatus = body.amount >= due.total_amount ? 'paid' : 'partially_paid';
    await sb.from('maintenance_dues').update({ status: newStatus, paid_at: payment.paid_at }).eq('id', body.dues_id);

    await writeAuditLog({
      userId: user.id,
      societyId: user.societyId,
      action: 'PAYMENT',
      resourceType: 'payments',
      resourceId: payment.id,
      newValues: payment,
      ip: extractClientIP(request),
    });

    return new Response(JSON.stringify(payment), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
