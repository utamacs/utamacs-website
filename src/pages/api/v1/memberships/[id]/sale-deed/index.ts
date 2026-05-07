export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BUCKET = 'member-documents';
const ALLOWED_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

// POST /api/v1/memberships/[id]/sale-deed — upload sale deed document
// Member uploads for their own application; exec can upload for any
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;

    const { data: membership, error: fetchErr } = await sb
      .from('memberships')
      .select('id, profile_id, status, sale_deed_key')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !membership) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    if (!isPrivileged && membership.profile_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    if (!file) return Response.json({ error: 'VALIDATION', message: 'file field required' }, { status: 400 });

    if (!ALLOWED_MIME[file.type]) {
      return Response.json({ error: 'VALIDATION', message: 'Only PDF, JPEG, PNG allowed' }, { status: 400 });
    }

    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    if (buffer.length > MAX_BYTES) {
      return Response.json({ error: 'VALIDATION', message: 'File exceeds 10 MB limit' }, { status: 400 });
    }

    const ext = ALLOWED_MIME[file.type];
    const key = `sale-deeds/${SOCIETY_ID}/${id}.${ext}`;

    const storageService = new SupabaseStorageService();
    await storageService.upload(BUCKET, key, buffer, file.type);

    const { data: updated, error: updateErr } = await sb
      .from('memberships')
      .update({ sale_deed_key: key, status: membership.status === 'applied' ? 'fees_pending' : membership.status })
      .eq('id', id)
      .select('id, sale_deed_key, status')
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    await writeAuditLog({
      userId: user.id,
      action: 'UPDATE',
      resourceType: 'membership_sale_deed',
      resourceId: id,
      oldValues: { sale_deed_key: membership.sale_deed_key },
      newValues: { sale_deed_key: key },
    });

    return Response.json({ id, sale_deed_key: key, status: updated?.status });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// GET /api/v1/memberships/[id]/sale-deed — get signed URL for sale deed
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;

    const { data: membership } = await sb
      .from('memberships')
      .select('id, profile_id, sale_deed_key')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!membership) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (!isPrivileged && membership.profile_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }
    if (!membership.sale_deed_key) {
      return Response.json({ error: 'NOT_FOUND', message: 'No sale deed uploaded yet' }, { status: 404 });
    }

    const storageService = new SupabaseStorageService();
    const signedUrl = await storageService.getSignedUrl(BUCKET, membership.sale_deed_key, 3600);

    await writeAuditLog({
      userId: user.id,
      action: 'READ',
      resourceType: 'membership_sale_deed',
      resourceId: id,
      oldValues: null,
      newValues: { accessed_at: new Date().toISOString() },
    });

    return Response.json({ signed_url: signedUrl, expires_in: 3600 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
