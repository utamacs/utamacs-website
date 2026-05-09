export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_CATEGORIES = [
  'electrical','plumbing','fire_safety','hvac',
  'civil','security','it','general','mechanical',
] as const;
const VALID_STATUS = ['active','under_maintenance','decommissioned'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb    = getSupabaseServiceClient();
    const today = new Date().toISOString().split('T')[0];
    const cut90 = (() => { const d = new Date(); d.setDate(d.getDate() + 90); return d.toISOString().slice(0, 10); })();

    const rules      = await getRules(sb, SOCIETY_ID, ['ASSET_SERVICE_WARNING_DAYS']);
    const warnDays   = ruleInt(rules, 'ASSET_SERVICE_WARNING_DAYS', 30);
    const warnCutoff = (() => { const d = new Date(); d.setDate(d.getDate() + warnDays); return d.toISOString().slice(0, 10); })();

    const category   = url.searchParams.get('category');
    const status     = url.searchParams.get('status');
    const locationId = url.searchParams.get('location_id');
    const expirySoon = url.searchParams.get('expiry_soon'); // 'amc' | 'warranty'

    let query = sb
      .from('infrastructure_assets')
      .select(`
        id, name, asset_code, category, make, model, serial_number,
        capacity, quantity, supplier,
        installation_date, warranty_expiry,
        next_service_date, last_service_date,
        amc_vendor_id, amc_vendor, amc_start, amc_end, amc_amount,
        location_notes, status, is_active, notes, created_at,
        location_id,
        locations ( id, name, zone_type ),
        vendors ( id, name )
      `)
      .eq('society_id', SOCIETY_ID)
      .order('category')
      .order('asset_code', { nullsFirst: false })
      .order('name');

    if (category && VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
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

    let assets = (data ?? []).map((a: Record<string, unknown>) => ({
      ...a,
      amc_expired:      a.amc_end        && (a.amc_end as string)        < today,
      warranty_expired: a.warranty_expiry && (a.warranty_expiry as string) < today,
      service_overdue:  a.next_service_date && (a.next_service_date as string) < today,
      service_due_soon: a.next_service_date && (a.next_service_date as string) >= today
                        && (a.next_service_date as string) <= warnCutoff,
      amc_due_soon:     a.amc_end && (a.amc_end as string) >= today && (a.amc_end as string) <= cut90,
    }));

    if (expirySoon === 'amc') {
      assets = assets.filter(a => a.amc_expired || a.amc_due_soon);
    } else if (expirySoon === 'warranty') {
      assets = assets.filter(a => !a.warranty_expired && (a as Record<string, unknown>).warranty_expiry && ((a as Record<string, unknown>).warranty_expiry as string) <= cut90);
    }

    return new Response(JSON.stringify(assets), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as Record<string, unknown>;
    const { name, category } = body;

    if (!name || typeof name !== 'string' || !name.trim()) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'name is required.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (!category || !VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Valid category is required.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (body.status && !VALID_STATUS.includes(body.status as typeof VALID_STATUS[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid status.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (body.location_id && !UUID_RE.test(body.location_id as string)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid location_id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (body.amc_vendor_id && !UUID_RE.test(body.amc_vendor_id as string)) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Invalid amc_vendor_id.' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('infrastructure_assets')
      .insert({
        society_id:       SOCIETY_ID,
        name:             sanitizePlainText((name as string).trim()),
        asset_code:       body.asset_code       ? (body.asset_code as string).trim()       : null,
        category,
        make:             body.make             ? (body.make as string).trim()             : null,
        model:            body.model            ? (body.model as string).trim()            : null,
        serial_number:    body.serial_number    ? (body.serial_number as string).trim()    : null,
        capacity:         body.capacity         ? (body.capacity as string).trim()         : null,
        quantity:         body.quantity         ? Number(body.quantity)                    : 1,
        supplier:         body.supplier         ? (body.supplier as string).trim()         : null,
        installation_date:body.installation_date || null,
        warranty_expiry:  body.warranty_expiry  || null,
        next_service_date:body.next_service_date|| null,
        location_id:      body.location_id      || null,
        location_notes:   body.location_notes   ? (body.location_notes as string).trim()  : null,
        amc_vendor_id:    body.amc_vendor_id    || null,
        amc_vendor:       body.amc_vendor       ? (body.amc_vendor as string).trim()      : null,
        amc_start:        body.amc_start        || null,
        amc_end:          body.amc_end          || null,
        amc_amount:       body.amc_amount       ? Number(body.amc_amount)                 : null,
        status:           body.status           || 'active',
        is_active:        body.status !== 'decommissioned',
        notes:            body.notes            ? (body.notes as string).trim()            : null,
      })
      .select('id')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'infrastructure_assets', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { name: (name as string).trim(), category },
    });

    return new Response(JSON.stringify({ id: data.id }), {
      status: 201, headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
