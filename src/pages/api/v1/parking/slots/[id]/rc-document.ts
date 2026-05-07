export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
};
const MAX_SIZE = 5 * 1024 * 1024;

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const slotId = params.id!;
    if (!UUID_RE.test(slotId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: slot } = await sb
      .from('parking_slots')
      .select('id, slot_number')
      .eq('id', slotId)
      .eq('society_id', SOCIETY_ID)
      .single();
    if (!slot) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    if (!file) return Response.json({ error: 'NO_FILE', message: 'No file provided.' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext) {
      return Response.json({ error: 'INVALID_TYPE', message: 'Only PDF, JPEG, PNG, or WebP files allowed.' }, { status: 400 });
    }

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > MAX_SIZE) {
      return Response.json({ error: 'TOO_LARGE', message: 'File must be under 5 MB.' }, { status: 400 });
    }

    const key = `parking/${SOCIETY_ID}/${slotId}/${crypto.randomUUID()}.${ext}`;
    const storage = new SupabaseStorageService();
    const { storageKey } = await storage.upload('parking-docs', key, buffer, file.type);

    await sb.from('parking_slots').update({ rc_doc_key: storageKey }).eq('id', slotId);

    await writeAuditLog({
      userId: user.id,
      societyId: SOCIETY_ID,
      action: 'UPDATE',
      resourceType: 'parking_slot',
      resourceId: slotId,
      ip: extractClientIP(request),
      newValues: { rc_doc_key: storageKey },
    });

    const signedUrl = await storage.getSignedUrl('parking-docs', storageKey, 3600);
    return Response.json({ storage_key: storageKey, signed_url: signedUrl }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
