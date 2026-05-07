export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText, sanitizeHTML } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'policies.view');
    const sb = getSupabaseServiceClient();

    const isPrivileged = hasFeature(user, 'policies.manage');
    const statusFilter = url.searchParams.get('status') ?? (isPrivileged ? '' : 'active');

    let query = sb
      .from('policies')
      .select('id, title, description, policy_type, version, effective_date, acknowledgement_required, gate_portal_access, status, created_at, created_by')
      .eq('society_id', SOCIETY_ID)
      .order('effective_date', { ascending: false });

    if (statusFilter) query = query.eq('status', statusFilter);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // For members: include whether they've acknowledged each policy
    let ackSet = new Set<string>();
    if (data?.length) {
      const { data: acks } = await sb
        .from('policy_acknowledgements')
        .select('policy_id')
        .eq('user_id', user.id)
        .in('policy_id', data.map((p: any) => p.id));
      ackSet = new Set((acks ?? []).map((a: any) => a.policy_id));
    }

    const policies = (data ?? []).map((p: any) => ({
      ...p,
      acknowledged: ackSet.has(p.id),
    }));

    return Response.json(policies);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'policies.manage');

    const body = await request.json() as Record<string, unknown>;
    const { title, description, policy_type, body: pBody, video_url, version, effective_date, acknowledgement_required, gate_portal_access, status } = body;

    if (!title || !policy_type) return Response.json({ error: 'VALIDATION_ERROR', message: 'title and policy_type are required' }, { status: 400 });

    const VALID_TYPES = ['text', 'pdf', 'video_url'];
    if (!VALID_TYPES.includes(String(policy_type))) return Response.json({ error: 'VALIDATION_ERROR', message: 'policy_type must be text, pdf, or video_url' }, { status: 400 });

    const VALID_STATUS = ['draft', 'active', 'superseded'];
    const pStatus = VALID_STATUS.includes(String(status)) ? String(status) : 'draft';

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('policies')
      .insert({
        society_id:               SOCIETY_ID,
        title:                    sanitizePlainText(String(title)),
        description:              description ? sanitizePlainText(String(description)).slice(0, 1000) : null,
        policy_type:              String(policy_type),
        body:                     policy_type === 'text' && pBody ? sanitizeHTML(String(pBody)) : null,
        video_url:                policy_type === 'video_url' && video_url ? String(video_url).slice(0, 500) : null,
        version:                  Number.isInteger(Number(version)) ? Number(version) : 1,
        effective_date:           effective_date ? String(effective_date) : new Date().toISOString().slice(0, 10),
        acknowledgement_required: Boolean(acknowledgement_required),
        gate_portal_access:       Boolean(gate_portal_access),
        status:                   pStatus,
        created_by:               user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'policies', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { title: data.title, policy_type: data.policy_type, status: data.status },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
