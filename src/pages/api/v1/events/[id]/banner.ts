export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};
const MAX_SIZE = 5 * 1024 * 1024; // 5 MB

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

    // Verify event exists and belongs to this society
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

    if (buffer.length > MAX_SIZE) {
      return Response.json(
        { error: 'FILE_TOO_LARGE', message: 'File exceeds the 5 MB limit.' },
        { status: 400 },
      );
    }

    const storageKey = `events/${SOCIETY_ID}/${eventId}/${crypto.randomUUID()}.${ext}`;
    const storage = new SupabaseStorageService();
    const { storageKey: uploadedKey } = await storage.upload('event-banners', storageKey, buffer, file.type);

    // Delete old banner if one existed
    if (event.banner_key) {
      try { await storage.delete('event-banners', event.banner_key); } catch { /* non-fatal */ }
    }

    // Persist the new banner_key on the event row
    const { error: updateError } = await sb
      .from('events')
      .update({ banner_key: uploadedKey })
      .eq('id', eventId);

    if (updateError) throw Object.assign(new Error(updateError.message), { status: 500 });

    // Return a signed URL valid for 1 hour
    const signedUrl = await storage.getSignedUrl('event-banners', uploadedKey, 3600);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'events', resourceId: eventId,
      ip: extractClientIP(request),
      newValues: { banner_key: uploadedKey },
    });

    return Response.json({ banner_key: uploadedKey, url: signedUrl }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
