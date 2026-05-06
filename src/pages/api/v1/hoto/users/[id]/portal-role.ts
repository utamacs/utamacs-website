export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_ROLES = ['member', 'executive', 'secretary', 'president'] as const;
const TREASURER_TITLES = new Set(['Treasurer', 'Joint Treasurer']);

// PUT — update a member's portal_role and committee_title
// Auth: admin required
// Body: { portal_role, committee_title?, reason }
// - Validates portal_role against the 4 valid values
// - Fetches current profile; records change_type accordingly
// - Handles Treasurer/Joint Treasurer finance feature overrides
// - Logs to role_change_log and hoto_audit_log
export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) {
      return Response.json(
        { error: 'UNAUTHORIZED', message: 'Authentication required' },
        { status: 401 },
      );
    }

    requireAdmin(user);

    const targetUserId = params.id!;

    const body = await request.json() as {
      portal_role?: string;
      committee_title?: string;
      reason?: string;
    };

    if (!body.portal_role || !VALID_ROLES.includes(body.portal_role as typeof VALID_ROLES[number])) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: `portal_role must be one of: ${VALID_ROLES.join(', ')}` },
        { status: 400 },
      );
    }

    if (!body.reason?.trim()) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'reason is required' },
        { status: 400 },
      );
    }

    const newRole = body.portal_role;
    const newTitle = body.committee_title?.trim() ?? null;
    const reason = body.reason.trim();

    const sb = getSupabaseServiceClient();

    // Fetch current profile
    const { data: current, error: fetchErr } = await sb
      .from('profiles')
      .select('id, portal_role, committee_title, is_active')
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !current) {
      return Response.json(
        { error: 'NOT_FOUND', message: 'Member not found in this society' },
        { status: 404 },
      );
    }

    const oldRole = (current as any).portal_role ?? 'member';
    const oldTitle = (current as any).committee_title ?? null;

    const roleChanged = oldRole !== newRole;
    const titleChanged = oldTitle !== newTitle;

    // Determine change_type
    let changeType: string;
    if (roleChanged && titleChanged) {
      changeType = 'ROLE_AND_TITLE';
    } else if (roleChanged) {
      changeType = 'ROLE_ONLY';
    } else if (titleChanged) {
      changeType = 'TITLE_ONLY';
    } else {
      changeType = 'NO_CHANGE';
    }

    // UPDATE profiles
    const { data: updatedProfile, error: updateErr } = await sb
      .from('profiles')
      .update({
        portal_role: newRole,
        committee_title: newTitle,
      })
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // INSERT role_change_log
    const { error: logErr } = await sb.from('role_change_log').insert({
      society_id: SOCIETY_ID,
      user_id: targetUserId,
      changed_by: user.id,
      old_role: oldRole,
      new_role: newRole,
      old_title: oldTitle,
      new_title: newTitle,
      change_type: changeType,
      reason,
    });

    if (logErr) console.error('[portal-role] role_change_log insert failed:', logErr.message);

    // Handle Treasurer/Joint Treasurer finance feature overrides
    const oldIsTreasurer = oldTitle !== null && TREASURER_TITLES.has(oldTitle);
    const newIsTreasurer = newTitle !== null && TREASURER_TITLES.has(newTitle);

    if (!oldIsTreasurer && newIsTreasurer) {
      // Newly designated as Treasurer/Joint Treasurer — grant finance.view and finance.enter
      const overrides = ['finance.view', 'finance.enter'].map((feature) => ({
        society_id: SOCIETY_ID,
        user_id: targetUserId,
        feature,
        enabled: true,
        reason: 'Treasurer title designation',
        granted_by: user.id,
      }));
      const { error: oErr } = await sb.from('user_feature_overrides').insert(overrides);
      if (oErr) console.error('[portal-role] treasurer override grant failed:', oErr.message);
    } else if (oldIsTreasurer && !newIsTreasurer) {
      // Removing Treasurer designation — revoke finance.view and finance.enter overrides
      const { error: rErr } = await sb
        .from('user_feature_overrides')
        .update({ revoked_at: new Date().toISOString() })
        .eq('society_id', SOCIETY_ID)
        .eq('user_id', targetUserId)
        .in('feature', ['finance.view', 'finance.enter'])
        .is('revoked_at', null);
      if (rErr) console.error('[portal-role] treasurer override revoke failed:', rErr.message);
    }

    // INSERT hoto_audit_log
    const { error: auditErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'ROLE_CHANGE',
      resource_type: 'profiles',
      resource_id: targetUserId,
      old_values: { portal_role: oldRole, committee_title: oldTitle },
      new_values: { portal_role: newRole, committee_title: newTitle, reason },
    });
    if (auditErr) console.error('[portal-role] hoto_audit_log insert failed:', auditErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'ROLE_CHANGE',
      resourceType: 'profiles',
      resourceId: targetUserId,
      ip: extractClientIP(request),
      oldValues: { portal_role: oldRole, committee_title: oldTitle },
      newValues: { portal_role: newRole, committee_title: newTitle },
    });

    return Response.json({ success: true, profile: updatedProfile });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
