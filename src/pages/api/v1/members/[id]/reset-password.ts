export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST /api/v1/members/:id/reset-password
// Admin-only: directly sets a new password for a society member without sending
// a reset email. Bypasses the public forgot-password rate limit intentionally —
// this endpoint requires a valid admin JWT so it cannot be abused by strangers.
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);

    if (user.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Only admins can reset member passwords' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const targetUserId = params.id!;

    if (targetUserId === user.id) {
      return new Response(JSON.stringify({ error: 'Use the regular password change flow for your own account' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as { password?: string };
    const password = body.password?.trim() ?? '';

    if (password.length < 8) {
      return new Response(JSON.stringify({ error: 'Password must be at least 8 characters' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify the target user belongs to this society before touching their account
    const { data: profile } = await sb
      .from('profiles')
      .select('id, full_name')
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!profile) {
      return new Response(JSON.stringify({ error: 'Member not found in this society' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { error } = await sb.auth.admin.updateUserById(targetUserId, { password });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'PASSWORD_RESET', resourceType: 'auth.users', resourceId: targetUserId,
      ip: extractClientIP(request),
      newValues: { reset_by: user.id, member_name: (profile as any).full_name },
    });

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
