export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — submit a 1-5 star rating after complaint is resolved/closed
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const complaintId = params.id!;

    const sb = getSupabaseServiceClient();
    const { data: complaint, error: cErr } = await sb
      .from('complaints')
      .select('id, society_id, raised_by, status')
      .eq('id', complaintId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (cErr || !complaint) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (complaint.raised_by !== user.id) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    if (!['Resolved', 'Closed'].includes(complaint.status))
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Can only rate resolved or closed complaints' }, { status: 400 });

    const body = await request.json() as { rating?: unknown; feedback?: unknown };
    const rating = Number(body.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5)
      return Response.json({ error: 'VALIDATION_ERROR', message: 'rating must be an integer between 1 and 5' }, { status: 400 });

    const feedback = body.feedback != null ? String(body.feedback).trim().slice(0, 500) || null : null;

    const { data, error } = await sb
      .from('complaint_ratings')
      .upsert({
        society_id:   SOCIETY_ID,
        complaint_id: complaintId,
        rated_by:     user.id,
        rating,
        feedback,
      }, { onConflict: 'complaint_id,rated_by' })
      .select('id, rating, feedback, created_at')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'complaint_ratings', resourceId: complaintId,
      ip: extractClientIP(request),
      newValues: { rating, feedback },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// GET — fetch the caller's rating for this complaint
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const complaintId = params.id!;

    const sb = getSupabaseServiceClient();
    const { data } = await sb
      .from('complaint_ratings')
      .select('id, rating, feedback, created_at')
      .eq('complaint_id', complaintId)
      .eq('rated_by', user.id)
      .single();

    return Response.json(data ?? null);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
