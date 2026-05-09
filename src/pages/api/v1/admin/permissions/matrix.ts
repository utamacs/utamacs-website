export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { ALL_FEATURES } from '@lib/features';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const ROLES = ['member', 'executive', 'secretary', 'president', 'staff', 'supervisor', 'afm'] as const;

// GET — full role-feature permission matrix (admin only)
// Returns: { matrix: { [feature]: { [role]: { enabled, is_locked } } }, roles, features }
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('feature_permissions')
      .select('role, feature, enabled, is_locked, last_changed_at')
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Build matrix: feature → role → { enabled, is_locked }
    const matrix: Record<string, Record<string, { enabled: boolean; is_locked: boolean; last_changed_at: string | null }>> = {};
    for (const row of data ?? []) {
      if (!matrix[row.feature]) matrix[row.feature] = {};
      matrix[row.feature][row.role] = {
        enabled: row.enabled,
        is_locked: row.is_locked,
        last_changed_at: row.last_changed_at,
      };
    }

    return Response.json({ matrix, roles: ROLES, features: ALL_FEATURES });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — bulk update role-feature permissions (admin only, locked rows rejected)
// Body: { changes: Array<{ role, feature, enabled }> }
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const body = await request.json() as {
      changes?: Array<{ role: string; feature: string; enabled: boolean }>;
    };

    if (!Array.isArray(body.changes) || !body.changes.length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'changes array is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Load current locked state to reject any attempt to toggle locked rows
    const { data: existing } = await sb
      .from('feature_permissions')
      .select('role, feature, is_locked')
      .eq('society_id', SOCIETY_ID);

    const lockedSet = new Set(
      (existing ?? []).filter(r => r.is_locked).map(r => `${r.role}:${r.feature}`)
    );

    const rejected: string[] = [];
    const toUpsert: Array<{
      society_id: string; role: string; feature: string; enabled: boolean;
      is_locked: boolean; last_changed_by: string; last_changed_at: string;
    }> = [];

    for (const change of body.changes) {
      if (!ROLES.includes(change.role as typeof ROLES[number])) {
        return Response.json({ error: 'VALIDATION_ERROR', message: `Unknown role: ${change.role}` }, { status: 400 });
      }
      if (!ALL_FEATURES.includes(change.feature as typeof ALL_FEATURES[number])) {
        return Response.json({ error: 'VALIDATION_ERROR', message: `Unknown feature: ${change.feature}` }, { status: 400 });
      }
      const key = `${change.role}:${change.feature}`;
      if (lockedSet.has(key)) {
        rejected.push(key);
        continue;
      }
      toUpsert.push({
        society_id: SOCIETY_ID,
        role: change.role,
        feature: change.feature,
        enabled: change.enabled,
        is_locked: false,
        last_changed_by: user.id,
        last_changed_at: new Date().toISOString(),
      });
    }

    if (rejected.length === body.changes.length) {
      return Response.json({
        error: 'FORBIDDEN',
        message: `All changes were rejected — these permissions are locked: ${rejected.join(', ')}`,
      }, { status: 403 });
    }

    if (toUpsert.length) {
      const { error: upsertErr } = await sb
        .from('feature_permissions')
        .upsert(toUpsert, { onConflict: 'society_id,role,feature' });

      if (upsertErr) throw Object.assign(new Error(upsertErr.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'feature_permissions', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { changes_count: toUpsert.length, rejected_count: rejected.length },
    });

    return Response.json({
      updated: toUpsert.length,
      rejected: rejected.length > 0 ? rejected : undefined,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
