export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_CATEGORIES = [
  'electrical','plumbing','fire_safety','hvac',
  'civil','security','it','general','mechanical',
] as const;
const VALID_STATUS = ['active','under_maintenance','decommissioned'] as const;

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { id } = params;
    if (!id || !UUID_RE.test(id)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid asset id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as Record<string, unknown>;

    if (body.category !== undefined && !VALID_CATEGORIES.includes(body.category as typeof VALID_CATEGORIES[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid category.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (body.status !== undefined && !VALID_STATUS.includes(body.status as typeof VALID_STATUS[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid status.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (body.location_id && !UUID_RE.test(body.location_id as string)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid location_id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const patch: Record<string, unknown> = {};
    if (body.name           !== undefined) patch.name            = sanitizePlainText((body.name as string).trim());
    if (body.asset_code     !== undefined) patch.asset_code      = body.asset_code ? (body.asset_code as string).trim() : null;
    if (body.category       !== undefined) patch.category        = body.category;
    if (body.make           !== undefined) patch.make            = body.make   ? (body.make as string).trim()   : null;
    if (body.model          !== undefined) patch.model           = body.model  ? (body.model as string).trim()  : null;
    if (body.serial_number  !== undefined) patch.serial_number   = body.serial_number ? (body.serial_number as string).trim() : null;
    if (body.capacity       !== undefined) patch.capacity        = body.capacity ? (body.capacity as string).trim() : null;
    if (body.quantity       !== undefined) patch.quantity        = Number(body.quantity);
    if (body.supplier       !== undefined) patch.supplier        = body.supplier ? (body.supplier as string).trim() : null;
    if (body.installation_date !== undefined) patch.installation_date = body.installation_date || null;
    if (body.warranty_expiry   !== undefined) patch.warranty_expiry   = body.warranty_expiry   || null;
    if (body.next_service_date !== undefined) patch.next_service_date = body.next_service_date || null;
    if (body.location_id    !== undefined) patch.location_id     = body.location_id || null;
    if (body.location_notes !== undefined) patch.location_notes  = body.location_notes ? (body.location_notes as string).trim() : null;
    if (body.amc_vendor     !== undefined) patch.amc_vendor      = body.amc_vendor ? (body.amc_vendor as string).trim() : null;
    if (body.amc_vendor_id  !== undefined) patch.amc_vendor_id   = body.amc_vendor_id || null;
    if (body.amc_start      !== undefined) patch.amc_start       = body.amc_start || null;
    if (body.amc_end        !== undefined) patch.amc_end         = body.amc_end   || null;
    if (body.amc_amount     !== undefined) patch.amc_amount      = body.amc_amount ? Number(body.amc_amount) : null;
    if (body.status         !== undefined) {
      patch.status    = body.status;
      patch.is_active = body.status !== 'decommissioned';
    }
    if (body.notes !== undefined) patch.notes = body.notes ? (body.notes as string).trim() : null;

    if (Object.keys(patch).length === 0) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'No fields to update.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('infrastructure_assets')
      .update(patch)
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'infrastructure_assets', resourceId: id,
      ip: extractClientIP(request), newValues: patch,
    });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// Soft-delete: set status → decommissioned
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { id } = params;
    if (!id || !UUID_RE.test(id)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid asset id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('infrastructure_assets')
      .update({ status: 'decommissioned', is_active: false })
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'infrastructure_assets', resourceId: id,
      ip: extractClientIP(request), newValues: { status: 'decommissioned' },
    });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
