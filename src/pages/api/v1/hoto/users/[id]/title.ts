export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_TITLES = [
  'President', 'Vice President',
  'General Secretary', 'Joint Secretary',
  'Treasurer', 'Joint Treasurer',
  'Executive Member',
] as const;

// PATCH — update only a member's committee_title (no role change, no feature overrides)
// Auth: admin required
// Body: { committee_title }
// - INSERTs role_change_log with change_type='TITLE_ONLY'
// - Does NOT alter any feature overrides (that is handled by portal-role.ts)
export const PATCH: APIRoute = async ({ request, params }) => {
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

    const body = await request.json() as { committee_title?: string };

    // committee_title may be null/empty string to clear the title
    const newTitle = typeof body.committee_title === 'string'
      ? (body.committee_title.trim() || null)
      : null;

    if (newTitle && !VALID_TITLES.includes(newTitle as typeof VALID_TITLES[number])) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: `committee_title must be one of: ${VALID_TITLES.join(', ')} (or blank)` },
        { status: 400 },
      );
    }

    const sb = getSupabaseServiceClient();

    // Fetch current profile so we can record old value
    const { data: current, error: fetchErr } = await sb
      .from('profiles')
      .select('id, portal_role, committee_title')
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !current) {
      return Response.json(
        { error: 'NOT_FOUND', message: 'Member not found in this society' },
        { status: 404 },
      );
    }

    const oldTitle = (current as any).committee_title ?? null;
    const currentRole = (current as any).portal_role ?? 'member';

    // UPDATE profiles.committee_title only
    const { data: updatedProfile, error: updateErr } = await sb
      .from('profiles')
      .update({ committee_title: newTitle })
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // INSERT role_change_log with change_type='TITLE_ONLY'
    const { error: logErr } = await sb.from('role_change_log').insert({
      society_id: SOCIETY_ID,
      user_id: targetUserId,
      changed_by: user.id,
      old_role: currentRole,
      new_role: currentRole,
      old_title: oldTitle,
      new_title: newTitle,
      change_type: 'TITLE_ONLY',
      reason: 'Committee title update',
    });

    if (logErr) console.error('[title] role_change_log insert failed:', logErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'UPDATE',
      resourceType: 'profiles',
      resourceId: targetUserId,
      ip: extractClientIP(request),
      oldValues: { committee_title: oldTitle },
      newValues: { committee_title: newTitle },
    });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
