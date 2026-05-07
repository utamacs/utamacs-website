export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_PAYMENT_MODES = ['cash', 'upi', 'bank_transfer', 'credit', 'other'] as const;

// GET /api/v1/water-tankers — list deliveries (newest first), with optional ?month=YYYY-MM
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const month = url.searchParams.get('month'); // YYYY-MM
    const summary = url.searchParams.get('summary') === 'true';

    if (summary) {
      const { data, error } = await sb
        .from('water_monthly_summary')
        .select('*')
        .eq('society_id', SOCIETY_ID)
        .order('month', { ascending: false })
        .limit(12);
      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      return Response.json(data ?? []);
    }

    let query = sb
      .from('water_tankers')
      .select('id, delivery_date, supplier_name, tanker_capacity_kl, tanker_count, total_kl, cost_per_kl, total_cost, payment_mode, invoice_number, notes, created_at, created_by')
      .eq('society_id', SOCIETY_ID)
      .order('delivery_date', { ascending: false });

    if (month && /^\d{4}-\d{2}$/.test(month)) {
      const start = `${month}-01`;
      const end = new Date(new Date(start).setMonth(new Date(start).getMonth() + 1)).toISOString().slice(0, 10);
      query = query.gte('delivery_date', start).lt('delivery_date', end);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/water-tankers — log a new delivery (exec only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const supplier_name = sanitizePlainText(String(body.supplier_name ?? '')).trim();
    const delivery_date = String(body.delivery_date ?? '');
    const tanker_capacity_kl = Number(body.tanker_capacity_kl);
    const tanker_count = Number(body.tanker_count ?? 1);

    if (!supplier_name) return Response.json({ error: 'VALIDATION', message: 'Supplier name required' }, { status: 400 });
    if (!/^\d{4}-\d{2}-\d{2}$/.test(delivery_date)) return Response.json({ error: 'VALIDATION', message: 'delivery_date must be YYYY-MM-DD' }, { status: 400 });
    if (!tanker_capacity_kl || tanker_capacity_kl <= 0) return Response.json({ error: 'VALIDATION', message: 'tanker_capacity_kl must be positive' }, { status: 400 });
    if (!Number.isInteger(tanker_count) || tanker_count < 1) return Response.json({ error: 'VALIDATION', message: 'tanker_count must be a positive integer' }, { status: 400 });

    const total_cost = body.total_cost !== undefined ? Number(body.total_cost) : (body.cost_per_kl !== undefined ? Number(body.cost_per_kl) * tanker_capacity_kl * tanker_count : null);
    const payment_mode = body.payment_mode ? String(body.payment_mode) : null;
    if (payment_mode && !VALID_PAYMENT_MODES.includes(payment_mode as typeof VALID_PAYMENT_MODES[number])) {
      return Response.json({ error: 'VALIDATION', message: `payment_mode must be one of: ${VALID_PAYMENT_MODES.join(', ')}` }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('water_tankers')
      .insert({
        society_id: SOCIETY_ID,
        delivery_date,
        supplier_name,
        tanker_capacity_kl,
        tanker_count,
        cost_per_kl: body.cost_per_kl !== undefined ? Number(body.cost_per_kl) : null,
        total_cost: total_cost ?? null,
        payment_mode: payment_mode ?? null,
        invoice_number: body.invoice_number ? sanitizePlainText(String(body.invoice_number)).slice(0, 100) : null,
        notes: body.notes ? sanitizePlainText(String(body.notes)).slice(0, 1000) : null,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'water_tanker', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { delivery_date, supplier_name, total_kl: tanker_capacity_kl * tanker_count },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/water-tankers?id=<uuid> — remove a log entry (admin only)
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Valid id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb.from('water_tankers').delete().eq('id', id).eq('society_id', SOCIETY_ID);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
