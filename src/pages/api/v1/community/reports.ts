export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const VALID_REASONS = ['spam', 'offensive', 'misinformation', 'harassment', 'other'] as const;
type ReportReason = typeof VALID_REASONS[number];

const VALID_STATUSES = ['reviewed', 'dismissed', 'actioned'] as const;
type ReportStatus = typeof VALID_STATUSES[number];

// GET (community.moderate) — list pending reports
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'community.moderate');

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('community_post_reports')
      .select(`
        id, post_id, reason, details, status, created_at, reported_by,
        community_posts(body, submitted_by)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST (any authenticated member) — submit a report
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as {
      post_id?: string;
      reason?: string;
      details?: string;
    };

    if (!body.post_id || !UUID_RE.test(body.post_id)) {
      return Response.json({ error: 'INVALID_POST_ID', message: 'A valid post_id is required.' }, { status: 400 });
    }

    if (!body.reason || !VALID_REASONS.includes(body.reason as ReportReason)) {
      return Response.json(
        { error: 'INVALID_REASON', message: `reason must be one of: ${VALID_REASONS.join(', ')}` },
        { status: 400 },
      );
    }

    const sb = getSupabaseServiceClient();

    // Verify the post belongs to this society
    const { data: post } = await sb
      .from('community_posts')
      .select('id')
      .eq('id', body.post_id)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!post) {
      return Response.json({ error: 'NOT_FOUND', message: 'Post not found.' }, { status: 404 });
    }

    const { data, error } = await sb
      .from('community_post_reports')
      .insert({
        society_id: SOCIETY_ID,
        post_id: body.post_id,
        reason: body.reason as ReportReason,
        details: body.details ? sanitizePlainText(body.details).slice(0, 300) : null,
        reported_by: user.id,
        status: 'pending',
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'community_post_reports', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { post_id: body.post_id, reason: body.reason },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH (community.moderate) — update report status
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'community.moderate');

    const body = await request.json() as { id?: string; status?: string };

    if (!body.id || !UUID_RE.test(body.id)) {
      return Response.json({ error: 'INVALID_ID', message: 'A valid report id is required.' }, { status: 400 });
    }

    if (!body.status || !VALID_STATUSES.includes(body.status as ReportStatus)) {
      return Response.json(
        { error: 'INVALID_STATUS', message: `status must be one of: ${VALID_STATUSES.join(', ')}` },
        { status: 400 },
      );
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('community_post_reports')
      .select('id, status')
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Report not found.' }, { status: 404 });
    }

    const { data, error } = await sb
      .from('community_post_reports')
      .update({ status: body.status as ReportStatus, reviewed_by: user.id, reviewed_at: new Date().toISOString() })
      .eq('id', body.id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'community_post_reports', resourceId: body.id,
      ip: extractClientIP(request),
      oldValues: { status: existing.status },
      newValues: { status: body.status },
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
