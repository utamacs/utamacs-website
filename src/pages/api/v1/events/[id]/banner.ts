export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

// GET — return a signed download URL for the event banner (all authenticated members)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    await validateJWT(request);
    const eventId = params.id!;
    if (!UUID_RE.test(eventId)) {
      return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    }
    const sb = getSupabaseServiceClient();
    const { data: event } = await sb
      .from('events')
      .select('banner_key')
      .eq('id', eventId)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!event?.banner_key) {
      return Response.json({ error: 'NOT_FOUND', message: 'No banner image uploaded.' }, { status: 404 });
    }

    const url = await getDocumentDownloadUrl(event.banner_key);
    return Response.json({ url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST (exec only) — upload banner image for an event
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role) && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN', message: 'Exec access required.' }, { status: 403 });
    }

    const eventId = params.id!;
    if (!UUID_RE.test(eventId)) {
      return Response.json({ error: 'INVALID_ID', message: 'Invalid event id.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_EVENTS_MB']);
    const maxSize = ruleInt(rules, 'UPLOAD_LIMIT_EVENTS_MB', 5) * 1024 * 1024;

    const { data: event } = await sb
      .from('events')
      .select('id, banner_key')
      .eq('id', eventId)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!event) {
      return Response.json({ error: 'NOT_FOUND', message: 'Event not found.' }, { status: 404 });
    }

    const formData = await request.formData();
    const file = formData.get('file') as File | null;

    if (!file) {
      return Response.json({ error: 'NO_FILE', message: 'A file field is required in the form data.' }, { status: 400 });
    }

    const ext = ALLOWED_MIME[file.type];
    if (!ext) {
      return Response.json(
        { error: 'INVALID_TYPE', message: 'Only JPEG, PNG, and WebP images are allowed.' },
        { status: 400 },
      );
    }

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);

    if (buffer.length > maxSize) {
      return Response.json(
        { error: 'FILE_TOO_LARGE', message: `File exceeds the ${ruleInt(rules, 'UPLOAD_LIMIT_EVENTS_MB', 5)} MB limit.` },
        { status: 400 },
      );
    }

    const githubPath = docPath.eventBanner(eventId, ext);
    const result = await commitDocument(githubPath, buffer, `docs: event ${eventId} banner`);

    const { error: updateError } = await sb
      .from('events')
      .update({ banner_key: result.githubPath })
      .eq('id', eventId);

    if (updateError) throw Object.assign(new Error(updateError.message), { status: 500 });

    const url = await getDocumentDownloadUrl(result.githubPath);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'events', resourceId: eventId,
      ip: extractClientIP(request),
      newValues: { banner_key: result.githubPath },
    });

    return Response.json({ banner_key: result.githubPath, url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
