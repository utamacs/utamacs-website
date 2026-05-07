export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('amc_contracts')
      .select('*, vendors(id, name, category, phone, email), amc_service_logs(*, profiles(full_name))')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: error.code === 'PGRST116' ? 404 : 500 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const { data: existing, error: fetchErr } = await sb
      .from('amc_contracts')
      .select('id, equipment_name, end_date')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const body = await request.json() as Record<string, unknown>;
    const allowed = ['vendor_id','equipment_name','equipment_type','scope','start_date','end_date','amount','payment_frequency','notes','is_active'];
    const updates: Record<string, unknown> = {};
    for (const k of allowed) {
      if (body[k] !== undefined) {
        updates[k] = typeof body[k] === 'string' ? sanitizePlainText(String(body[k])) : body[k];
      }
    }

    if (updates.equipment_name) updates.equipment_name = sanitizePlainText(String(updates.equipment_name));

    const { data, error } = await sb
      .from('amc_contracts')
      .update(updates)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id, action: 'UPDATE',
      resourceType: 'amc_contracts', resourceId: params.id!,
      ip: extractClientIP(request),
      oldValues: { equipment_name: existing.equipment_name, end_date: existing.end_date },
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (user.role !== 'admin') return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('amc_contracts')
      .update({ is_active: false })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
