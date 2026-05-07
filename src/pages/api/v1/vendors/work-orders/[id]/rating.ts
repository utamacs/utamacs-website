export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/** POST /api/v1/vendors/work-orders/:id/rating — exec rates vendor after work order close */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const sb = getSupabaseServiceClient();

    const { data: wo } = await sb
      .from('work_orders')
      .select('id, vendor_id, status')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!wo) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (!['completed', 'closed'].includes(wo.status)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Can only rate completed or closed work orders' }, { status: 422 });
    }

    const body = await request.json() as { rating?: number; comment?: string };
    const rating = Number(body.rating);
    if (!rating || rating < 1 || rating > 5 || !Number.isInteger(rating)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'rating must be an integer between 1 and 5' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('vendor_ratings')
      .upsert({
        society_id:    SOCIETY_ID,
        work_order_id: params.id!,
        vendor_id:     wo.vendor_id,
        rating,
        comment:       body.comment ? sanitizePlainText(body.comment) : null,
        rated_by:      user.id,
      }, { onConflict: 'work_order_id' })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'vendor_ratings', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { rating, vendor_id: wo.vendor_id, work_order_id: params.id! },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

/** GET /api/v1/vendors/work-orders/:id/rating — fetch existing rating for this work order */
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data } = await sb
      .from('vendor_ratings')
      .select('rating, comment, rated_by, created_at')
      .eq('work_order_id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    return Response.json(data ?? null);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
