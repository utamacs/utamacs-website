export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list delivery logs (all exec/admin/guard; member sees only their unit)
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();
    const date = url.searchParams.get('date') ?? new Date().toISOString().slice(0, 10);
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);

    let query = sb
      .from('delivery_logs')
      .select('id, unit_id, courier_company, tracking_number, received_at, collected_at, collected_by, logged_by, units(unit_number, block)')
      .eq('society_id', SOCIETY_ID)
      .gte('received_at', `${date}T00:00:00.000Z`)
      .lte('received_at', `${date}T23:59:59.999Z`)
      .order('received_at', { ascending: false })
      .limit(limit);

    // Members see only their unit
    if (user.role === 'member') {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if (profile?.unit_id) query = query.eq('unit_id', profile.unit_id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — log a new delivery (security guard / exec / admin)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['security_guard', 'executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only security guards and executives can log deliveries' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      unit_id?: string;
      courier_company?: string;
      tracking_number?: string;
    };

    if (!body.unit_id) {
      return new Response(JSON.stringify({ error: 'unit_id is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify unit belongs to this society
    const { data: unit } = await sb.from('units').select('id').eq('id', body.unit_id).eq('society_id', SOCIETY_ID).single();
    if (!unit) {
      return new Response(JSON.stringify({ error: 'Unit not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('delivery_logs')
      .insert({
        society_id: SOCIETY_ID,
        unit_id: body.unit_id,
        courier_company: body.courier_company ? sanitizePlainText(body.courier_company) : null,
        tracking_number: body.tracking_number ? sanitizePlainText(body.tracking_number) : null,
        received_at: new Date().toISOString(),
        logged_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'delivery_logs', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { unit_id: body.unit_id },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
