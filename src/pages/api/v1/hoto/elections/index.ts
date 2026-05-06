export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_ROLES = ['member', 'executive', 'secretary', 'president'] as const;
const VALID_TITLES = [
  'President', 'Vice President',
  'General Secretary', 'Joint Secretary',
  'Treasurer', 'Joint Treasurer',
  'Executive Member',
] as const;
const TREASURER_TITLES = new Set(['Treasurer', 'Joint Treasurer']);

// GET — list election events ordered by created_at DESC with total_role_changes
// Auth: admin required
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) {
      return Response.json(
        { error: 'UNAUTHORIZED', message: 'Authentication required' },
        { status: 401 },
      );
    }

    requireAdmin(user);

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('election_events')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — record a committee election; atomically applies all role changes
// Auth: admin required
// Body: {
//   election_date: string (ISO date),
//   description: string,
//   changes: Array<{ user_id, new_role, new_title, reason }>
// }
// Atomically (via Promise.all):
//   (a) INSERT election_events
//   (b) per change: fetch current profile, UPDATE profiles, INSERT role_change_log (change_type='ELECTION')
//   (c) Handle Treasurer finance overrides per user (same logic as portal-role.ts)
//   (d) UPDATE election_events.total_role_changes
//   (e) INSERT hoto_audit_log
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
      election_date?: string;
      description?: string;
      changes?: Array<{ user_id?: string; new_role?: string; new_title?: string; reason?: string }>;
    };

    if (!body.election_date?.trim()) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'election_date is required' },
        { status: 400 },
      );
    }

    if (!body.description?.trim()) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'description is required' },
        { status: 400 },
      );
    }

    if (!Array.isArray(body.changes) || body.changes.length === 0) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'changes must be a non-empty array' },
        { status: 400 },
      );
    }

    // Validate each change entry
    for (let i = 0; i < body.changes.length; i++) {
      const c = body.changes[i];
      if (!c.user_id) {
        return Response.json(
          { error: 'VALIDATION_ERROR', message: `changes[${i}].user_id is required` },
          { status: 400 },
        );
      }
      if (!c.new_role || !VALID_ROLES.includes(c.new_role as typeof VALID_ROLES[number])) {
        return Response.json(
          { error: 'VALIDATION_ERROR', message: `changes[${i}].new_role must be one of: ${VALID_ROLES.join(', ')}` },
          { status: 400 },
        );
      }
      if (!c.reason?.trim()) {
        return Response.json(
          { error: 'VALIDATION_ERROR', message: `changes[${i}].reason is required` },
          { status: 400 },
        );
      }
      const titleStr = c.new_title?.trim();
      if (titleStr && !VALID_TITLES.includes(titleStr as typeof VALID_TITLES[number])) {
        return Response.json(
          { error: 'VALIDATION_ERROR', message: `changes[${i}].new_title must be one of: ${VALID_TITLES.join(', ')} (or blank)` },
          { status: 400 },
        );
      }
    }

    const sb = getSupabaseServiceClient();

    // (a) INSERT election_events
    const { data: electionEvent, error: electionErr } = await sb
      .from('election_events')
      .insert({
        society_id: SOCIETY_ID,
        election_date: body.election_date.trim(),
        description: body.description.trim(),
        conducted_by: user.id,
        total_role_changes: 0,
      })
      .select()
      .single();

    if (electionErr) throw Object.assign(new Error(electionErr.message), { status: 500 });

    const electionId = (electionEvent as any).id;

    // (b) + (c) Process each change concurrently
    const changeResults = await Promise.all(
      body.changes.map(async (change) => {
        const targetUserId = change.user_id!;
        const newRole = change.new_role!;
        const newTitle = change.new_title?.trim() ?? null;
        const changeReason = change.reason!.trim();

        // Fetch current profile
        const { data: current } = await sb
          .from('profiles')
          .select('id, portal_role, committee_title')
          .eq('id', targetUserId)
          .eq('society_id', SOCIETY_ID)
          .single();

        const oldRole = (current as any)?.portal_role ?? 'member';
        const oldTitle = (current as any)?.committee_title ?? null;

        // UPDATE profiles
        const { error: updateErr } = await sb
          .from('profiles')
          .update({
            portal_role: newRole,
            committee_title: newTitle,
          })
          .eq('id', targetUserId)
          .eq('society_id', SOCIETY_ID);

        if (updateErr) {
          console.error(`[elections] profiles update failed for ${targetUserId}:`, updateErr.message);
        }

        // INSERT role_change_log with change_type='ELECTION'
        const { error: logErr } = await sb.from('role_change_log').insert({
          society_id: SOCIETY_ID,
          user_id: targetUserId,
          changed_by: user.id,
          old_role: oldRole,
          new_role: newRole,
          old_title: oldTitle,
          new_title: newTitle,
          change_type: 'ELECTION',
          reason: changeReason,
          election_event_id: electionId,
        });

        if (logErr) {
          console.error(`[elections] role_change_log failed for ${targetUserId}:`, logErr.message);
        }

        // Handle Treasurer finance overrides
        const oldIsTreasurer = oldTitle !== null && TREASURER_TITLES.has(oldTitle);
        const newIsTreasurer = newTitle !== null && TREASURER_TITLES.has(newTitle);

        if (!oldIsTreasurer && newIsTreasurer) {
          const overrides = ['finance.view', 'finance.enter'].map((feature) => ({
            society_id: SOCIETY_ID,
            user_id: targetUserId,
            feature,
            enabled: true,
            reason: 'Treasurer title designation',
            granted_by: user.id,
          }));
          const { error: oErr } = await sb.from('user_feature_overrides').insert(overrides);
          if (oErr) console.error(`[elections] treasurer grant failed for ${targetUserId}:`, oErr.message);
        } else if (oldIsTreasurer && !newIsTreasurer) {
          const { error: rErr } = await sb
            .from('user_feature_overrides')
            .update({ revoked_at: new Date().toISOString() })
            .eq('society_id', SOCIETY_ID)
            .eq('user_id', targetUserId)
            .in('feature', ['finance.view', 'finance.enter'])
            .is('revoked_at', null);
          if (rErr) console.error(`[elections] treasurer revoke failed for ${targetUserId}:`, rErr.message);
        }

        return { user_id: targetUserId, old_role: oldRole, new_role: newRole };
      }),
    );

    // (d) UPDATE election_events.total_role_changes
    const { error: countErr } = await sb
      .from('election_events')
      .update({ total_role_changes: changeResults.length })
      .eq('id', electionId);

    if (countErr) console.error('[elections] total_role_changes update failed:', countErr.message);

    // (e) INSERT hoto_audit_log
    const { error: auditHotoErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'ELECTION',
      resource_type: 'election_events',
      resource_id: electionId,
      old_values: null,
      new_values: {
        election_date: body.election_date,
        description: body.description,
        changes_count: changeResults.length,
      },
    });
    if (auditHotoErr) console.error('[elections] hoto_audit_log insert failed:', auditHotoErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'UPDATE',
      resourceType: 'election_events',
      resourceId: electionId,
      ip: extractClientIP(request),
      newValues: {
        election_date: body.election_date,
        description: body.description,
        changes_count: changeResults.length,
      },
    });

    return Response.json(
      { election_event: electionEvent, changes_count: changeResults.length },
      { status: 201 },
    );
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
