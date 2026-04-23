import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_ROLES = ['member', 'executive', 'admin', 'security_guard', 'vendor'] as const;

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);

    // Only admin can change roles
    if (user.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Only admins can change member roles' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const targetUserId = params.id!;

    // Prevent admin from changing their own role
    if (targetUserId === user.id) {
      return new Response(JSON.stringify({ error: 'Cannot change your own role' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as { role?: string; expires_at?: string | null };

    if (!body.role || !VALID_ROLES.includes(body.role as typeof VALID_ROLES[number])) {
      return new Response(JSON.stringify({ error: `role must be one of: ${VALID_ROLES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify target user belongs to this society
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

    // Fetch old role for audit
    const { data: oldRole } = await sb
      .from('user_roles')
      .select('role, expires_at')
      .eq('user_id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    // Upsert role
    const { data, error } = await sb
      .from('user_roles')
      .upsert({
        user_id: targetUserId,
        society_id: SOCIETY_ID,
        role: body.role,
        granted_by: user.id,
        granted_at: new Date().toISOString(),
        expires_at: body.expires_at ?? null,
      }, { onConflict: 'user_id,society_id' })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'ROLE_CHANGE', resourceType: 'user_roles', resourceId: targetUserId,
      ip: extractClientIP(request),
      oldValues: oldRole ? { role: (oldRole as any).role } : undefined,
      newValues: { role: body.role, expires_at: body.expires_at ?? null },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
