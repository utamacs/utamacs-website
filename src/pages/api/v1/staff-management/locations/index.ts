export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_ZONE = ['block','common_area','utility','amenity','external'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const zone   = url.searchParams.get('zone_type');
    const active = url.searchParams.get('active') !== 'false';

    let query = sb
      .from('locations')
      .select('id, name, name_hi, name_te, zone_type, is_active')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', active)
      .order('zone_type')
      .order('name');

    if (zone && VALID_ZONE.includes(zone as typeof VALID_ZONE[number])) {
      query = query.eq('zone_type', zone);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'FORBIDDEN' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
    }

    const body = await request.json() as Record<string, unknown>;
    const { name, zone_type } = body;

    if (!name || typeof name !== 'string' || !name.trim()) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'name is required.' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }
    if (!zone_type || !VALID_ZONE.includes(zone_type as typeof VALID_ZONE[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Valid zone_type is required.' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('locations')
      .insert({
        society_id: SOCIETY_ID,
        name:       String(name).trim().slice(0, 100),
        name_hi:    typeof body.name_hi === 'string' ? body.name_hi.trim().slice(0, 100) || null : null,
        name_te:    typeof body.name_te === 'string' ? body.name_te.trim().slice(0, 100) || null : null,
        zone_type,
      })
      .select('id')
      .single();

    if (error) {
      if (error.code === '23505') {
        return new Response(JSON.stringify({ error: 'CONFLICT', message: 'A location with this name already exists.' }), { status: 409, headers: { 'Content-Type': 'application/json' } });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'locations', resourceId: data!.id,
      ip: extractClientIP(request),
      newValues: { name: String(name).trim(), zone_type },
    });

    return new Response(JSON.stringify({ id: data!.id }), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
