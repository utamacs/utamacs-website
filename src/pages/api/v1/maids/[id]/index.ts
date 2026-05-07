export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_WORK_TYPES = ['cleaning','cooking','babysitting','elder_care','gardening','laundry','multiple','other'];

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.view');
    const maidId = params.id!;
    if (!UUID_RE.test(maidId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');

    const fields = isPrivileged
      ? 'id, full_name, phone, id_type, id_number, agency_name, work_type, is_active, police_verified, verification_date, photo_key, id_doc_key, registered_at'
      : 'id, full_name, work_type, agency_name, is_active, police_verified, photo_key, registered_at';

    const { data, error } = await sb
      .from('maids')
      .select(fields)
      .eq('id', maidId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.manage');

    const maidId = params.id!;
    if (!UUID_RE.test(maidId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: existing } = await sb
      .from('maids')
      .select('id')
      .eq('id', maidId)
      .eq('society_id', SOCIETY_ID)
      .single();
    if (!existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const body = await request.json() as Record<string, unknown>;
    const updates: Record<string, unknown> = {};

    if (body.full_name !== undefined) updates.full_name = sanitizePlainText(String(body.full_name)).slice(0, 100);
    if (body.phone !== undefined) updates.phone = body.phone ? sanitizePlainText(String(body.phone)).slice(0, 15) : null;
    if (body.agency_name !== undefined) updates.agency_name = body.agency_name ? sanitizePlainText(String(body.agency_name)).slice(0, 100) : null;
    if (body.work_type !== undefined && VALID_WORK_TYPES.includes(String(body.work_type))) updates.work_type = body.work_type;
    if (body.is_active !== undefined) updates.is_active = Boolean(body.is_active);
    if (body.police_verified !== undefined) {
      updates.police_verified = Boolean(body.police_verified);
      if (body.police_verified) {
        updates.verified_by = user.id;
        updates.verification_date = body.verification_date ? String(body.verification_date) : new Date().toISOString().slice(0, 10);
      }
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'NO_CHANGES' }, { status: 400 });
    }

    const { data: old } = await sb.from('maids').select('*').eq('id', maidId).single();
    const { data, error } = await sb.from('maids').update(updates).eq('id', maidId).select().single();
    if (error) throw error;

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'maid', resourceId: maidId,
      ip: extractClientIP(request),
      oldValues: old as Record<string, unknown>,
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
