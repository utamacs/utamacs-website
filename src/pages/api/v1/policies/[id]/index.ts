export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText, sanitizeHTML } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive', 'secretary', 'president', 'admin'].includes(user.portalRole ?? user.role);

    const { data, error } = await sb
      .from('policies')
      .select('*')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (data.status !== 'active' && !isPrivileged) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Generate signed URL for PDF (1-hour expiry per DPDPA)
    let document_url: string | null = null;
    if (data.document_key) {
      try {
        const storage = new SupabaseStorageService();
        document_url = await storage.getSignedUrl('policy-documents', data.document_key, 3600);
      } catch { /* non-fatal */ }
    }

    // Check if this user has acknowledged
    const { data: ack } = await sb
      .from('policy_acknowledgements')
      .select('acked_at')
      .eq('policy_id', params.id!)
      .eq('user_id', user.id)
      .maybeSingle();

    // Exec: fetch total acknowledgement count
    let ack_count: number | null = null;
    if (isPrivileged) {
      const { count } = await sb
        .from('policy_acknowledgements')
        .select('*', { count: 'exact', head: true })
        .eq('policy_id', params.id!);
      ack_count = count;
    }

    return Response.json({
      ...data,
      document_url,
      acknowledged: !!ack,
      acked_at: ack?.acked_at ?? null,
      ack_count,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const isPrivileged = ['executive', 'secretary', 'president', 'admin'].includes(user.portalRole ?? user.role);
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

    if ('title' in body)                    updates.title = sanitizePlainText(String(body.title)).slice(0, 200);
    if ('description' in body)              updates.description = body.description ? sanitizePlainText(String(body.description)).slice(0, 1000) : null;
    if ('body' in body)                     updates.body = body.body ? sanitizeHTML(String(body.body)) : null;
    if ('video_url' in body)                updates.video_url = body.video_url ? String(body.video_url).slice(0, 500) : null;
    if ('effective_date' in body)           updates.effective_date = body.effective_date;
    if ('acknowledgement_required' in body) updates.acknowledgement_required = Boolean(body.acknowledgement_required);
    if ('gate_portal_access' in body)       updates.gate_portal_access = Boolean(body.gate_portal_access);
    if ('status' in body) {
      const VALID = ['draft', 'active', 'superseded'];
      if (VALID.includes(String(body.status))) updates.status = body.status;
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('policies')
      .update(updates)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'policies', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
