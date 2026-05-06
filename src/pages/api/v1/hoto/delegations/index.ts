export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_FROM_ROLES = ['president', 'secretary'] as const;

// Feature granted per delegation_type
const DELEGATION_FEATURE_MAP: Record<string, string> = {
  PRESIDENT_TO_VP: 'hoto.approve_president',
  SECRETARY_TO_JOINT_SEC: 'hoto.approve_secretary',
};

// GET — list active approval delegations with delegate profile info
// Auth: executive or above (portal_role in executive/secretary/president) or admin
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) {
      return Response.json(
        { error: 'UNAUTHORIZED', message: 'Authentication required' },
        { status: 401 },
      );
    }

    // Require at least executive role
    const allowedRoles = new Set(['executive', 'secretary', 'president']);
    if (!allowedRoles.has(user.portalRole) && !user.isAdmin) {
      return Response.json(
        { error: 'FORBIDDEN', message: 'Executive role or higher required' },
        { status: 403 },
      );
    }

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('approval_delegations')
      .select(`
        id, from_role, to_user_id, delegation_type, reason,
        created_at, active,
        delegate:profiles!approval_delegations_to_user_id_fkey(full_name, portal_role, committee_title)
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('active', true)
      .order('created_at', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create a new approval delegation
// Auth: admin required
// Body: { from_role, to_user_id, reason, delegation_type }
// - Validates from_role is 'president' or 'secretary'
// - Validates to_user_id exists and has portal_role='executive'
// - Checks no existing active delegation of same from_role
// - INSERTs approval_delegations
// - Grants user_feature_override for the delegate
// - INSERTs hoto_audit_log
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) {
      return Response.json(
        { error: 'UNAUTHORIZED', message: 'Authentication required' },
        { status: 401 },
      );
    }

    requireAdmin(user);

    const body = await request.json() as {
      from_role?: string;
      to_user_id?: string;
      reason?: string;
      delegation_type?: string;
    };

    if (!body.from_role || !VALID_FROM_ROLES.includes(body.from_role as typeof VALID_FROM_ROLES[number])) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: `from_role must be one of: ${VALID_FROM_ROLES.join(', ')}` },
        { status: 400 },
      );
    }

    if (!body.to_user_id?.trim()) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'to_user_id is required' },
        { status: 400 },
      );
    }

    if (!body.reason?.trim()) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'reason is required' },
        { status: 400 },
      );
    }

    if (!body.delegation_type?.trim() || !DELEGATION_FEATURE_MAP[body.delegation_type]) {
      return Response.json(
        {
          error: 'VALIDATION_ERROR',
          message: `delegation_type must be one of: ${Object.keys(DELEGATION_FEATURE_MAP).join(', ')}`,
        },
        { status: 400 },
      );
    }

    const fromRole = body.from_role;
    const toUserId = body.to_user_id.trim();
    const reason = body.reason.trim();
    const delegationType = body.delegation_type;

    const sb = getSupabaseServiceClient();

    // Validate to_user_id exists and has portal_role='executive'
    const { data: delegateProfile, error: profileErr } = await sb
      .from('profiles')
      .select('id, full_name, portal_role')
      .eq('id', toUserId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (profileErr || !delegateProfile) {
      return Response.json(
        { error: 'NOT_FOUND', message: 'Delegate user not found in this society' },
        { status: 404 },
      );
    }

    if ((delegateProfile as any).portal_role !== 'executive') {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'Delegate must have portal_role of executive' },
        { status: 400 },
      );
    }

    // Check no existing active delegation of the same from_role
    const { data: existing } = await sb
      .from('approval_delegations')
      .select('id')
      .eq('society_id', SOCIETY_ID)
      .eq('from_role', fromRole)
      .eq('active', true)
      .maybeSingle();

    if (existing) {
      return Response.json(
        {
          error: 'CONFLICT',
          message: `An active delegation already exists for from_role '${fromRole}'. Deactivate it first.`,
        },
        { status: 409 },
      );
    }

    // INSERT approval_delegations
    const { data: delegation, error: insertErr } = await sb
      .from('approval_delegations')
      .insert({
        society_id: SOCIETY_ID,
        from_role: fromRole,
        to_user_id: toUserId,
        reason,
        delegation_type: delegationType,
        active: true,
        activated_by: user.id,
      })
      .select()
      .single();

    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    // Grant feature override to the delegate
    const featureToGrant = DELEGATION_FEATURE_MAP[delegationType];
    const { error: overrideErr } = await sb.from('user_feature_overrides').insert({
      society_id: SOCIETY_ID,
      user_id: toUserId,
      feature: featureToGrant,
      enabled: true,
      reason: `Delegation: ${delegationType} (id: ${(delegation as any).id})`,
      granted_by: user.id,
    });

    if (overrideErr) console.error('[delegations] feature override grant failed:', overrideErr.message);

    // INSERT hoto_audit_log
    const { error: auditErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'DELEGATION_CREATE',
      resource_type: 'approval_delegations',
      resource_id: String((delegation as any).id),
      old_values: null,
      new_values: {
        to_user_id: toUserId,
        from_role: fromRole,
        delegation_type: delegationType,
        feature_granted: featureToGrant,
        reason,
      },
    });
    if (auditErr) console.error('[delegations] hoto_audit_log insert failed:', auditErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'CREATE',
      resourceType: 'approval_delegations',
      resourceId: (delegation as any).id,
      ip: extractClientIP(request),
      newValues: { from_role: fromRole, to_user_id: toUserId, delegation_type: delegationType },
    });

    return Response.json(delegation, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
