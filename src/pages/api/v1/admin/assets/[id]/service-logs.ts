export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('asset_maintenance_logs')
      .select('id, service_date, service_type, description, cost, next_service_date, performed_by, created_at, vendors(name)')
      .eq('asset_id', params.id!)
      .order('service_date', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      service_date?: string; service_type?: string; description?: string;
      cost?: number; vendor_id?: string; next_service_date?: string;
    };

    if (!body.service_date || !body.service_type) {
      return new Response(JSON.stringify({ error: 'service_date and service_type are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify asset belongs to this society
    const { data: asset } = await sb
      .from('infrastructure_assets')
      .select('id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!asset) {
      return new Response(JSON.stringify({ error: 'Asset not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data, error } = await sb
      .from('asset_maintenance_logs')
      .insert({
        asset_id: params.id!,
        service_date: body.service_date,
        service_type: sanitizePlainText(body.service_type),
        description: body.description ? sanitizePlainText(body.description) : null,
        cost: body.cost ?? null,
        vendor_id: body.vendor_id ?? null,
        next_service_date: body.next_service_date ?? null,
        performed_by: user.id,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Update next_service_date on the asset itself
    if (body.next_service_date) {
      await sb
        .from('infrastructure_assets')
        .update({ next_service_date: body.next_service_date })
        .eq('id', params.id!);
    }

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
