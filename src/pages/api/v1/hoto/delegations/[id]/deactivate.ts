export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// Feature granted per delegation_type — mirrors delegations/index.ts
const DELEGATION_FEATURE_MAP: Record<string, string> = {
  PRESIDENT_TO_VP: 'hoto.approve_president',
  SECRETARY_TO_JOINT_SEC: 'hoto.approve_secretary',
};

// POST — deactivate an active delegation and revoke the delegate's feature override
// Auth: admin required
// - UPDATEs approval_delegations SET active=false, deactivated_at=NOW()
// - Revokes the feature override (sets revoked_at=NOW()) for the delegate
// - INSERTs hoto_audit_log
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) {
      return Response.json(
        { error: 'UNAUTHORIZED', message: 'Authentication required' },
        { status: 401 },
      );
    }

    requireAdmin(user);

    const delegationId = params.id!;
    const sb = getSupabaseServiceClient();

    // Fetch the delegation to ensure it exists and is active
    const { data: delegation, error: fetchErr } = await sb
      .from('approval_delegations')
      .select('id, to_user_id, from_role, delegation_type, active')
      .eq('id', delegationId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !delegation) {
      return Response.json(
        { error: 'NOT_FOUND', message: 'Delegation not found' },
        { status: 404 },
      );
    }

    if (!(delegation as any).active) {
      return Response.json(
        { error: 'CONFLICT', message: 'Delegation is already inactive' },
        { status: 409 },
      );
    }

    const toUserId = (delegation as any).to_user_id;
    const delegationType = (delegation as any).delegation_type;

    // UPDATE approval_delegations SET active=false, deactivated_at=NOW()
    const { error: updateErr } = await sb
      .from('approval_delegations')
      .update({ active: false, deactivated_at: new Date().toISOString() })
      .eq('id', delegationId)
      .eq('active', true);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // Revoke the feature override for the delegate (set revoked_at=NOW())
    const featureToRevoke = DELEGATION_FEATURE_MAP[delegationType];
    if (featureToRevoke) {
      const { error: revokeErr } = await sb
        .from('user_feature_overrides')
        .update({ revoked_at: new Date().toISOString() })
        .eq('society_id', SOCIETY_ID)
        .eq('user_id', toUserId)
        .eq('feature', featureToRevoke)
        .is('revoked_at', null);

      if (revokeErr) console.error('[deactivate] feature override revoke failed:', revokeErr.message);
    }

    // INSERT hoto_audit_log
    const { error: auditErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'DELEGATION_DEACTIVATE',
      resource_type: 'approval_delegations',
      resource_id: delegationId,
      old_values: { active: true },
      new_values: {
        active: false,
        to_user_id: toUserId,
        feature_revoked: featureToRevoke ?? null,
      },
    });
    if (auditErr) console.error('[deactivate] hoto_audit_log insert failed:', auditErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'UPDATE',
      resourceType: 'approval_delegations',
      resourceId: delegationId,
      ip: extractClientIP(request),
      oldValues: { active: true },
      newValues: { active: false, feature_revoked: featureToRevoke ?? null },
    });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
