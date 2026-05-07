export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/** POST /api/v1/admin/amc/:id/service-logs — record a service visit */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();

    // Verify AMC contract belongs to this society
    const { data: contract } = await sb
      .from('amc_contracts')
      .select('id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!contract) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const body = await request.json() as { service_date?: string; engineer_name?: string; remarks?: string; expense_id?: string };
    if (!body.service_date) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'service_date is required' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('amc_service_logs')
      .insert({
        society_id:    SOCIETY_ID,
        amc_id:        params.id!,
        service_date:  body.service_date,
        engineer_name: body.engineer_name ? sanitizePlainText(body.engineer_name) : null,
        remarks:       body.remarks ? sanitizePlainText(body.remarks) : null,
        expense_id:    body.expense_id ?? null,
        created_by:    user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
