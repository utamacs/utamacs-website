export const prerender = false;
import type { APIRoute } from 'astro';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
};

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const slotId = params.id!;
    if (!UUID_RE.test(slotId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_PARKING_MB']);
    const maxSize = ruleInt(rules, 'UPLOAD_LIMIT_PARKING_MB', 5) * 1024 * 1024;

    const { data: slot } = await sb
      .from('parking_slots')
      .select('id, slot_number, unit_id')
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
    if (buffer.length > maxSize) {
      return Response.json({ error: 'TOO_LARGE', message: `File must be under ${ruleInt(rules, 'UPLOAD_LIMIT_PARKING_MB', 5)} MB.` }, { status: 400 });
    }

    const unitId = (slot as any).unit_id ?? slotId;
    const githubPath = docPath.parking(unitId, slotId, 'rc', ext);
    const result = await commitDocument(githubPath, buffer, `docs: parking slot ${slotId} RC document`);

    await sb.from('parking_slots').update({ rc_doc_key: result.githubPath }).eq('id', slotId);

    await writeAuditLog({
      userId: user.id,
      societyId: SOCIETY_ID,
      action: 'UPDATE',
      resourceType: 'parking_slot',
      resourceId: slotId,
      ip: extractClientIP(request),
      newValues: { rc_doc_key: result.githubPath },
    });

    const signed_url = await getDocumentDownloadUrl(result.githubPath);
    return Response.json({ storage_key: result.githubPath, signed_url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
