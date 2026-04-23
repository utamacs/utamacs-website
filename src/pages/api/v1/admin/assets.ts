export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_CATEGORIES = ['Lift','Generator','Pump','CCTV','Fire_Safety','Gate','Electrical','Other'] as const;

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const today = new Date().toISOString().split('T')[0];

    const { data, error } = await sb
      .from('infrastructure_assets')
      .select('id, name, category, make, model, serial_number, installation_date, warranty_expiry, next_service_date, amc_start, amc_end, amc_amount, vendors(name)')
      .eq('society_id', SOCIETY_ID)
      .order('category')
      .order('name');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Flag assets needing attention
    const assets = (data ?? []).map((a: any) => ({
      ...a,
      amc_expired: a.amc_end && a.amc_end < today,
      warranty_expired: a.warranty_expiry && a.warranty_expiry < today,
      service_overdue: a.next_service_date && a.next_service_date < today,
      service_due_soon: a.next_service_date && a.next_service_date >= today &&
        new Date(a.next_service_date).getTime() - Date.now() < 30 * 24 * 60 * 60 * 1000,
    }));

    return new Response(JSON.stringify(assets), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      name?: string; category?: string; make?: string; model?: string;
      serial_number?: string; installation_date?: string; warranty_expiry?: string;
      next_service_date?: string; amc_vendor_id?: string;
      amc_start?: string; amc_end?: string; amc_amount?: number;
    };

    if (!body.name?.trim() || !body.category) {
      return new Response(JSON.stringify({ error: 'name and category are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!VALID_CATEGORIES.includes(body.category as typeof VALID_CATEGORIES[number])) {
      return new Response(JSON.stringify({ error: `category must be one of: ${VALID_CATEGORIES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('infrastructure_assets')
      .insert({
        society_id: SOCIETY_ID,
        name: sanitizePlainText(body.name),
        category: body.category,
        make: body.make ?? null,
        model: body.model ?? null,
        serial_number: body.serial_number ?? null,
        installation_date: body.installation_date ?? null,
        warranty_expiry: body.warranty_expiry ?? null,
        next_service_date: body.next_service_date ?? null,
        amc_vendor_id: body.amc_vendor_id ?? null,
        amc_start: body.amc_start ?? null,
        amc_end: body.amc_end ?? null,
        amc_amount: body.amc_amount ?? null,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'infrastructure_assets', resourceId: data.id,
      ip: extractClientIP(request), newValues: { name: data.name, category: data.category },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
