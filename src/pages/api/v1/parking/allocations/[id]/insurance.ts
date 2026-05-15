export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
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
  'application/pdf': 'pdf',
};

// POST — upload / replace insurance document for an allocation
// GET  — return signed download URL for existing insurance document
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const allocId = params.id ?? '';
    if (!UUID_RE.test(allocId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const { data: alloc } = await sb
      .from('parking_allocations')
      .select('id, unit_id, user_id, society_id')
      .eq('id', allocId)
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'active')
      .single();
    if (!alloc) return Response.json({ error: 'NOT_FOUND', message: 'Allocation not found or not active.' }, { status: 404 });

    // Allow the allocation owner or exec/admin
    const isOwner    = alloc.user_id === user.id;
    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isOwner && !isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const rules   = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_PARKING_MB']);
    const maxSize = ruleInt(rules, 'UPLOAD_LIMIT_PARKING_MB', 5) * 1024 * 1024;

    const fd   = await request.formData();
    const file = fd.get('file') as File | null;
    if (!file) return Response.json({ error: 'NO_FILE', message: 'No file provided.' }, { status: 400 });

    const ext = ALLOWED_MIME[file.type];
    if (!ext) return Response.json({ error: 'INVALID_TYPE', message: 'Only PDF, JPEG, or PNG allowed.' }, { status: 400 });

    const buffer = Buffer.from(await file.arrayBuffer());
    if (buffer.length > maxSize) {
      return Response.json({ error: 'TOO_LARGE', message: `File must be under ${ruleInt(rules, 'UPLOAD_LIMIT_PARKING_MB', 5)} MB.` }, { status: 400 });
    }

    const insuranceExpiry = fd.get('insurance_expiry') as string | null;
    const expiryDate = insuranceExpiry && /^\d{4}-\d{2}-\d{2}$/.test(insuranceExpiry) ? insuranceExpiry : null;

    const githubPath = docPath.parking(alloc.unit_id, allocId, 'insurance', ext);
    const result     = await commitDocument(githubPath, buffer, `docs: parking allocation ${allocId} insurance document`);

    const updatePayload: Record<string, unknown> = { insurance_key: result.githubPath };
    if (expiryDate) updatePayload.insurance_expiry = expiryDate;
    await sb.from('parking_allocations').update(updatePayload).eq('id', allocId);

    // append-only audit log
    await sb.from('parking_audit').insert({
      society_id:    SOCIETY_ID,
      slot_id:       (await sb.from('parking_allocations').select('slot_id').eq('id', allocId).single()).data?.slot_id,
      allocation_id: allocId,
      action:        'INSURANCE_UPLOADED',
      actor_id:      user.id,
      unit_id:       alloc.unit_id,
      notes:         expiryDate ? `Expiry: ${expiryDate}` : null,
    });

    await writeAuditLog({
      userId: user.id,
      societyId: SOCIETY_ID,
      action: 'UPDATE',
      resourceType: 'parking_allocation',
      resourceId: allocId,
      ip: extractClientIP(request),
      newValues: updatePayload,
    });

    const signed_url = await getDocumentDownloadUrl(result.githubPath);
    return Response.json({ insurance_key: result.githubPath, insurance_expiry: expiryDate, signed_url }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const allocId = params.id ?? '';
    if (!UUID_RE.test(allocId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: alloc } = await sb
      .from('parking_allocations')
      .select('user_id, insurance_key, insurance_expiry, society_id')
      .eq('id', allocId)
      .eq('society_id', SOCIETY_ID)
      .single();
    if (!alloc) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const isOwner    = alloc.user_id === user.id;
    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isOwner && !isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    if (!alloc.insurance_key) return Response.json({ error: 'NOT_FOUND', message: 'No insurance document on file.' }, { status: 404 });

    const url = await getDocumentDownloadUrl(alloc.insurance_key);
    return Response.json({ url, insurance_expiry: alloc.insurance_expiry });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
