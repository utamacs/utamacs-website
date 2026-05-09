export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_CATEGORY = ['electrical','plumbing','fire_safety','hvac','civil','security','it','general','mechanical'] as const;
const VALID_STATUS   = ['active','under_maintenance','decommissioned'] as const;

export const GET: APIRoute = async ({ request, params }) => {
  try {
    await validateJWT(request);
    const { id } = params;
    if (!id || !UUID_RE.test(id)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid asset id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('assets')
      .select(`
        id, name, asset_code, category, make, model, serial_number,
        capacity, quantity, supplier, amc_vendor, amc_start_date, amc_end_date,
        install_date, warranty_expiry, location_notes, status, notes, created_at, created_by,
        location_id,
        locations ( id, name, zone_type )
      `)
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: 'NOT_FOUND', message: 'Asset not found.' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'FORBIDDEN', message: 'Exec access required.' }), {
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
    const {
      name, category, make, model, serial_number, asset_code,
      capacity, quantity, supplier, location_id, location_notes,
      install_date, warranty_expiry,
      amc_vendor, amc_start_date, amc_end_date,
      status, notes,
    } = body;

    if (name !== undefined && (!name || typeof name !== 'string' || !(name as string).trim())) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'name cannot be empty.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (category !== undefined && !VALID_CATEGORY.includes(category as typeof VALID_CATEGORY[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid category.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (status !== undefined && !VALID_STATUS.includes(status as typeof VALID_STATUS[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid status value.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (location_id && !UUID_RE.test(location_id as string)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid location_id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const patch: Record<string, unknown> = {};
    if (name           !== undefined) patch.name           = (name as string).trim();
    if (asset_code     !== undefined) patch.asset_code     = asset_code ? (asset_code as string).trim() : null;
    if (category       !== undefined) patch.category       = category;
    if (make           !== undefined) patch.make           = make  ? (make as string).trim()  : null;
    if (model          !== undefined) patch.model          = model ? (model as string).trim() : null;
    if (serial_number  !== undefined) patch.serial_number  = serial_number ? (serial_number as string).trim() : null;
    if (capacity       !== undefined) patch.capacity       = capacity ? (capacity as string).trim() : null;
    if (quantity       !== undefined) patch.quantity       = Number(quantity);
    if (supplier       !== undefined) patch.supplier       = supplier ? (supplier as string).trim() : null;
    if (location_id    !== undefined) patch.location_id    = location_id || null;
    if (location_notes !== undefined) patch.location_notes = location_notes ? (location_notes as string).trim() : null;
    if (install_date   !== undefined) patch.install_date   = install_date   || null;
    if (warranty_expiry!== undefined) patch.warranty_expiry= warranty_expiry || null;
    if (amc_vendor     !== undefined) patch.amc_vendor     = amc_vendor ? (amc_vendor as string).trim() : null;
    if (amc_start_date !== undefined) patch.amc_start_date = amc_start_date || null;
    if (amc_end_date   !== undefined) patch.amc_end_date   = amc_end_date   || null;
    if (status         !== undefined) patch.status         = status;
    if (notes          !== undefined) patch.notes          = notes ? (notes as string).trim() : null;

    if (Object.keys(patch).length === 0) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'No fields to update.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('assets')
      .update(patch)
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// Soft-delete: set status to 'decommissioned'
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'FORBIDDEN', message: 'Exec access required.' }), {
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
      .from('assets')
      .update({ status: 'decommissioned' })
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
