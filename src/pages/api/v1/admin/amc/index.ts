export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_TYPES = ['lift','generator','pump','cctv','fire_system','hvac','intercom','solar','other'] as const;
const VALID_FREQ  = ['monthly','quarterly','half_yearly','annual','one_time'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const expiringSoon = url.searchParams.get('expiring_soon'); // '30' days

    let q = sb
      .from('amc_contracts')
      .select('*, vendors(id, name, category, phone), amc_service_logs(id, service_date, engineer_name)')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('end_date', { ascending: true });

    if (expiringSoon) {
      const days = parseInt(expiringSoon) || 30;
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() + days);
      q = q.lte('end_date', cutoff.toISOString().slice(0, 10));
    }

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const { equipment_name, equipment_type, vendor_id, scope, start_date, end_date, amount, payment_frequency, notes } = body;

    if (!equipment_name || !start_date || !end_date) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'equipment_name, start_date, and end_date are required' }, { status: 400 });
    }
    if (equipment_type && !VALID_TYPES.includes(equipment_type as any)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: `equipment_type must be one of: ${VALID_TYPES.join(', ')}` }, { status: 400 });
    }
    if (new Date(end_date as string) <= new Date(start_date as string)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'end_date must be after start_date' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('amc_contracts')
      .insert({
        society_id:        SOCIETY_ID,
        vendor_id:         vendor_id ?? null,
        equipment_name:    sanitizePlainText(String(equipment_name)),
        equipment_type:    VALID_TYPES.includes(equipment_type as any) ? equipment_type : 'other',
        scope:             scope ? sanitizePlainText(String(scope)) : null,
        start_date:        String(start_date),
        end_date:          String(end_date),
        amount:            amount ? Number(amount) : null,
        payment_frequency: VALID_FREQ.includes(payment_frequency as any) ? payment_frequency : 'annual',
        notes:             notes ? sanitizePlainText(String(notes)) : null,
        created_by:        user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id, action: 'CREATE',
      resourceType: 'amc_contracts', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { equipment_name: data.equipment_name, end_date: data.end_date },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
