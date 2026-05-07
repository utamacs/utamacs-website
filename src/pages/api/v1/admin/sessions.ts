export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/admin/sessions — list portal users with last sign-in metadata (admin only)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();

    const rules = await getRules(sb, SOCIETY_ID, ['SESSION_ACTIVE_WINDOW_MINUTES']);
    const activeWindowMins = ruleInt(rules, 'SESSION_ACTIVE_WINDOW_MINUTES', 60);

    // Fetch auth users via Supabase Admin API
    const { data: { users }, error: authErr } = await sb.auth.admin.listUsers({ perPage: 500 });
    if (authErr) throw Object.assign(new Error(authErr.message), { status: 500 });

    // Fetch profiles for display name/role enrichment
    const { data: profiles } = await sb
      .from('profiles')
      .select('id, full_name, unit_number, portal_role, is_admin')
      .eq('society_id', SOCIETY_ID);

    const profileMap = new Map((profiles ?? []).map((p: any) => [p.id, p]));
    const oneHourAgo = new Date(Date.now() - activeWindowMins * 60 * 1000).toISOString();

    const sessions = (users ?? []).map((u: any) => {
      const profile = profileMap.get(u.id);
      return {
        id: u.id,
        email: u.email,
        full_name: profile?.full_name ?? null,
        unit_number: profile?.unit_number ?? null,
        portal_role: profile?.portal_role ?? 'member',
        is_admin: profile?.is_admin ?? false,
        last_sign_in_at: u.last_sign_in_at ?? null,
        is_active: u.last_sign_in_at ? u.last_sign_in_at >= oneHourAgo : false,
        created_at: u.created_at,
        banned_until: u.banned_until ?? null,
      };
    }).sort((a: any, b: any) => {
      // Active sessions first, then by last sign-in desc
      if (a.is_active !== b.is_active) return a.is_active ? -1 : 1;
      return (b.last_sign_in_at ?? '') > (a.last_sign_in_at ?? '') ? 1 : -1;
    });

    return Response.json(sessions);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE /api/v1/admin/sessions?user_id=<uuid> — force sign-out a user (admin only)
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const targetId = url.searchParams.get('user_id') ?? '';
    if (!UUID_RE.test(targetId)) return Response.json({ error: 'VALIDATION', message: 'Valid user_id required' }, { status: 400 });
    if (targetId === user.id) return Response.json({ error: 'VALIDATION', message: 'Cannot revoke your own session' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb.auth.admin.signOut(targetId, 'global');
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'user_session', resourceId: targetId,
      ip: extractClientIP(request),
      newValues: { action: 'force_signout', target_user: targetId },
    });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
