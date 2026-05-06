export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireAdmin } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — deactivate a member account
// Auth: admin required
// Body: { reason }
// - UPDATEs profiles.is_active = false
// - INSERTs hoto_audit_log entry
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

    const targetUserId = params.id!;

    // Prevent admin from deactivating themselves
    if (targetUserId === user.id) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'Cannot deactivate your own account' },
        { status: 400 },
      );
    }

    const body = await request.json() as { reason?: string };

    if (!body.reason?.trim()) {
      return Response.json(
        { error: 'VALIDATION_ERROR', message: 'reason is required' },
        { status: 400 },
      );
    }

    const reason = body.reason.trim();
    const sb = getSupabaseServiceClient();

    // Verify the target user belongs to this society
    const { data: current, error: fetchErr } = await sb
      .from('profiles')
      .select('id, is_active, full_name')
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !current) {
      return Response.json(
        { error: 'NOT_FOUND', message: 'Member not found in this society' },
        { status: 404 },
      );
    }

    if (!(current as any).is_active) {
      return Response.json(
        { error: 'CONFLICT', message: 'Member is already deactivated' },
        { status: 409 },
      );
    }

    // UPDATE profiles.is_active = false
    const { error: updateErr } = await sb
      .from('profiles')
      .update({ is_active: false })
      .eq('id', targetUserId)
      .eq('society_id', SOCIETY_ID);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // INSERT hoto_audit_log
    const { error: auditErr } = await sb.from('hoto_audit_log').insert({
      society_id: SOCIETY_ID,
      actor_id: user.id,
      action: 'DEACTIVATE_USER',
      resource_type: 'profiles',
      resource_id: targetUserId,
      old_values: { is_active: true },
      new_values: { is_active: false, reason },
    });
    if (auditErr) console.error('[deactivate] hoto_audit_log insert failed:', auditErr.message);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'UPDATE',
      resourceType: 'profiles',
      resourceId: targetUserId,
      ip: extractClientIP(request),
      oldValues: { is_active: true },
      newValues: { is_active: false, reason },
    });

    return Response.json({ success: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
