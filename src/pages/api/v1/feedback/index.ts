export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const VALID_CATEGORIES = ['general','maintenance','safety','amenities','management','events','other'];
const VALID_STATUSES   = ['open','acknowledged','in_progress','resolved','closed'];
const VALID_PRIORITIES = ['low','normal','high','urgent'];

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive', 'admin'].includes(user.role);
    const url = new URL(request.url);

    const status   = url.searchParams.get('status');
    const category = url.searchParams.get('category');
    const limit    = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10), 200);

    let query = sb
      .from('feedbacks')
      .select(`
        id, category, subject, rating, is_anonymous, status, priority,
        response, responded_at, created_at, updated_at,
        ${isPrivileged ? 'submitted_by, body, unit_id, responded_by,' : ''}
        units(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (!isPrivileged) {
      // Members see only their own
      query = (query as any).eq('submitted_by', user.id);
    } else {
      if (status && VALID_STATUSES.includes(status)) query = (query as any).eq('status', status);
      if (category && VALID_CATEGORIES.includes(category)) query = (query as any).eq('category', category);
    }

    const { data, error } = await query;
    if (error) throw error;

    // Hide author identity for anonymous feedback shown to exec
    const sanitized = ((data ?? []) as any[]).map((f: any) => {
      if (f.is_anonymous && isPrivileged) {
        return { ...f, submitted_by: null, unit_id: null };
      }
      return f;
    });

    return Response.json(sanitized);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as Record<string, unknown>;

    const subject = String(body.subject ?? '').trim();
    const fbBody  = String(body.body ?? '').trim();
    const category = String(body.category ?? 'general');
    const isAnon  = body.is_anonymous === true;

    if (subject.length < 3) {
      return Response.json({ error: 'VALIDATION', message: 'Subject must be at least 3 characters.' }, { status: 400 });
    }
    if (fbBody.length < 10) {
      return Response.json({ error: 'VALIDATION', message: 'Feedback must be at least 10 characters.' }, { status: 400 });
    }
    if (!VALID_CATEGORIES.includes(category)) {
      return Response.json({ error: 'INVALID_CATEGORY' }, { status: 400 });
    }

    const rating = body.rating ? parseInt(String(body.rating), 10) : null;
    if (rating !== null && (isNaN(rating) || rating < 1 || rating > 5)) {
      return Response.json({ error: 'INVALID_RATING', message: 'Rating must be 1–5.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
    const unitId = (profile as any)?.unit_id ?? null;

    const { data, error } = await sb
      .from('feedbacks')
      .insert({
        society_id:   SOCIETY_ID,
        category,
        subject:      sanitizePlainText(subject).slice(0, 200),
        body:         sanitizePlainText(fbBody).slice(0, 2000),
        rating:       rating ?? null,
        submitted_by: user.id,
        unit_id:      isAnon ? null : unitId,
        is_anonymous: isAnon,
        status: 'open',
        priority: VALID_PRIORITIES.includes(String(body.priority ?? '')) ? String(body.priority) : 'normal',
      })
      .select()
      .single();

    if (error) throw error;

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'CREATE', resourceType: 'feedback',
      resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { category, subject: subject.slice(0, 50) },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — exec responds to or updates status of feedback
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const isPrivileged = ['executive', 'admin'].includes(user.role);

    const body = await request.json() as { id?: string; status?: string; response?: string; priority?: string };
    const feedbackId = body.id;

    if (!feedbackId || !UUID_RE.test(feedbackId)) {
      return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data: existing } = await sb
      .from('feedbacks')
      .select('id, submitted_by, status')
      .eq('id', feedbackId)
      .eq('society_id', SOCIETY_ID)
      .single();
    if (!existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const updates: Record<string, unknown> = {};

    if (isPrivileged) {
      if (body.status && VALID_STATUSES.includes(body.status)) updates.status = body.status;
      if (body.priority && VALID_PRIORITIES.includes(body.priority)) updates.priority = body.priority;
      if (body.response !== undefined) {
        updates.response     = body.response ? sanitizePlainText(body.response).slice(0, 2000) : null;
        updates.responded_by  = user.id;
        updates.responded_at  = new Date().toISOString();
        if (!updates.status) updates.status = 'acknowledged';
      }
    } else {
      // Member can only edit their own open feedback
      if ((existing as any).submitted_by !== user.id) {
        return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
      }
      if ((existing as any).status !== 'open') {
        return Response.json({ error: 'LOCKED', message: 'Cannot edit feedback that is already being processed.' }, { status: 409 });
      }
      // Members can only close their own feedback
      if (body.status === 'closed') updates.status = 'closed';
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'NO_CHANGES' }, { status: 400 });
    }

    const { data: old } = await sb.from('feedbacks').select('*').eq('id', feedbackId).single();
    const { data, error } = await sb.from('feedbacks').update(updates).eq('id', feedbackId).select().single();
    if (error) throw error;

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'feedback', resourceId: feedbackId,
      ip: extractClientIP(request),
      oldValues: { status: (old as any).status },
      newValues: { status: updates.status, has_response: !!updates.response },
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
