export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleBool } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID      = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const RAZORPAY_KEY_ID = import.meta.env.RAZORPAY_KEY_ID ?? '';
const RAZORPAY_SECRET = import.meta.env.RAZORPAY_KEY_SECRET ?? '';
const RAZORPAY_API    = 'https://api.razorpay.com/v1';

// POST /api/v1/finance/dues/:id/order
// Creates a Razorpay order for the outstanding balance on a dues record.
// Returns { order_id, amount_paise, key_id } — client opens Razorpay checkout with these.
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const duesId = params.id ?? '';
    if (!UUID_RE.test(duesId)) return Response.json({ error: 'VALIDATION', message: 'invalid dues id' }, { status: 400 });

    if (!RAZORPAY_KEY_ID || !RAZORPAY_SECRET) {
      return Response.json({ error: 'NOT_CONFIGURED', message: 'Razorpay credentials not configured' }, { status: 503 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['RAZORPAY_ENABLED']);
    if (!ruleBool(rules, 'RAZORPAY_ENABLED', false)) {
      return Response.json({ error: 'DISABLED', message: 'Online payments are not enabled for this society' }, { status: 403 });
    }

    const { data: due, error: dueErr } = await sb
      .from('maintenance_dues')
      .select('id, user_id, total_amount, amount_paid, status')
      .eq('id', duesId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (dueErr || !due) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (due.status === 'paid' || due.status === 'waived') {
      return Response.json({ error: 'CONFLICT', message: `Dues already ${due.status}` }, { status: 409 });
    }

    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');
    if (!isExec && due.user_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const outstanding = Math.max(0, Number(due.total_amount) - Number(due.amount_paid ?? 0));
    if (outstanding < 1) return Response.json({ error: 'VALIDATION', message: 'No outstanding amount' }, { status: 400 });

    // Amount in paise (Razorpay requires integer paise)
    const amountPaise = Math.round(outstanding * 100);

    // Create Razorpay order via REST API
    const rpRes = await fetch(`${RAZORPAY_API}/orders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_SECRET}`).toString('base64')}`,
      },
      body: JSON.stringify({
        amount:   amountPaise,
        currency: 'INR',
        receipt:  `utamacs-${duesId.slice(-8)}`,
        notes: {
          dues_id:    duesId,
          society_id: SOCIETY_ID,
          user_id:    user.id,
        },
      }),
      signal: AbortSignal.timeout(8_000),
    });

    if (!rpRes.ok) {
      const rpErr = await rpRes.json().catch(() => ({})) as any;
      throw Object.assign(new Error(rpErr?.error?.description ?? 'Razorpay order creation failed'), { status: 502 });
    }

    const rpOrder = await rpRes.json() as any;

    // Persist the order record
    await sb.from('online_payment_orders').insert({
      society_id:        SOCIETY_ID,
      dues_id:           duesId,
      user_id:           user.id,
      razorpay_order_id: rpOrder.id,
      amount:            outstanding,
      currency:          'INR',
      status:            'created',
    });

    return Response.json({
      order_id:     rpOrder.id,
      amount_paise: amountPaise,
      outstanding,
      key_id:       RAZORPAY_KEY_ID,
      currency:     'INR',
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
