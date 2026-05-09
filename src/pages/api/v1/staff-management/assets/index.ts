export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_CATEGORY = ['electrical','plumbing','fire_safety','hvac','civil','security','it','general','mechanical'] as const;
const VALID_STATUS   = ['active','under_maintenance','decommissioned'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb   = getSupabaseServiceClient();

    const category   = url.searchParams.get('category');
    const status     = url.searchParams.get('status');
    const locationId = url.searchParams.get('location_id');
    const expirySoon = url.searchParams.get('expiry_soon'); // 'amc' | 'warranty' | 'both'

    let query = sb
      .from('assets')
      .select(`
        id, name, asset_code, category, make, model, serial_number,
        capacity, quantity, supplier, amc_vendor, amc_start_date, amc_end_date,
        install_date, warranty_expiry, location_notes, status, notes, created_at,
        location_id,
        locations ( id, name, zone_type )
      `)
      .eq('society_id', SOCIETY_ID)
      .order('category')
      .order('asset_code', { nullsFirst: false })
      .order('name');

    if (category && VALID_CATEGORY.includes(category as typeof VALID_CATEGORY[number])) {
      query = query.eq('category', category);
    }
    if (status && VALID_STATUS.includes(status as typeof VALID_STATUS[number])) {
      query = query.eq('status', status);
    }
    if (locationId && UUID_RE.test(locationId)) {
      query = query.eq('location_id', locationId);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    let assets = data ?? [];

    // Filter: AMC or warranty expiring within 90 days
    if (expirySoon) {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() + 90);
      const cutoffStr = cutoff.toISOString().slice(0, 10);
      const today     = new Date().toISOString().slice(0, 10);

      assets = assets.filter((a: Record<string, unknown>) => {
        const checkAmc = expirySoon === 'amc' || expirySoon === 'both';
        const checkWar = expirySoon === 'warranty' || expirySoon === 'both';
        const amcDue   = checkAmc && a.amc_end_date && (a.amc_end_date as string) <= cutoffStr;
        const warDue   = checkWar && a.warranty_expiry && (a.warranty_expiry as string) <= cutoffStr
                         && (a.warranty_expiry as string) >= today;
        return amcDue || warDue;
      });
    }

    return new Response(JSON.stringify(assets), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'FORBIDDEN', message: 'Exec access required.' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
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

    if (!name || typeof name !== 'string' || !name.trim()) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'name is required.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (!category || !VALID_CATEGORY.includes(category as typeof VALID_CATEGORY[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Valid category is required.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (status && !VALID_STATUS.includes(status as typeof VALID_STATUS[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid status value.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (location_id && !UUID_RE.test(location_id as string)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid location_id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb.from('assets').insert({
      society_id:     SOCIETY_ID,
      name:           (name as string).trim(),
      asset_code:     asset_code ? (asset_code as string).trim() : null,
      category,
      make:           make   ? (make as string).trim()   : null,
      model:          model  ? (model as string).trim()  : null,
      serial_number:  serial_number ? (serial_number as string).trim() : null,
      capacity:       capacity      ? (capacity as string).trim()      : null,
      quantity:       quantity      ? Number(quantity) : 1,
      supplier:       supplier      ? (supplier as string).trim()      : null,
      location_id:    location_id   || null,
      location_notes: location_notes ? (location_notes as string).trim() : null,
      install_date:   install_date   || null,
      warranty_expiry:warranty_expiry || null,
      amc_vendor:     amc_vendor     ? (amc_vendor as string).trim()    : null,
      amc_start_date: amc_start_date || null,
      amc_end_date:   amc_end_date   || null,
      status:         status || 'active',
      notes:          notes ? (notes as string).trim() : null,
      created_by:     user.id,
    }).select('id').single();

    if (error) {
      if (error.code === '23505') {
        return new Response(JSON.stringify({ error: 'CONFLICT', message: 'An asset with this code already exists.' }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    return new Response(JSON.stringify({ id: data.id }), {
      status: 201, headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
