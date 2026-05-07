export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import * as crypto from 'crypto';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const policyId = params.id!;

    const sb = getSupabaseServiceClient();
    const { data: policy, error: pErr } = await sb
      .from('policies')
      .select('id, title, status, acknowledgement_required')
      .eq('id', policyId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pErr || !policy) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (policy.status !== 'active') return Response.json({ error: 'VALIDATION_ERROR', message: 'Policy is not active' }, { status: 400 });

    const clientIp = extractClientIP(request);
    const ipHash = clientIp ? crypto.createHash('sha256').update(clientIp).digest('hex') : null;

    const { data, error } = await sb
      .from('policy_acknowledgements')
      .insert({ policy_id: policyId, user_id: user.id, ip_hash: ipHash })
      .select('id, acked_at')
      .single();

    if (error) {
      if (error.code === '23505') return Response.json({ error: 'ALREADY_ACKNOWLEDGED' }, { status: 409 });
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'policy_acknowledgements', resourceId: policyId,
      ip: clientIp,
      newValues: { policy_title: policy.title },
    });

    return Response.json({ acknowledged: true, acked_at: data.acked_at }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
