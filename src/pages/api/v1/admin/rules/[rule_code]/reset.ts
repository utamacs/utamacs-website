export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST — reset a rule's current_value back to its default_value (admin only)
// Body: { change_reason }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin access required' }, { status: 403 });

    const ruleCode = params.rule_code!;
    const body = await request.json() as { change_reason?: string };

    if (!body.change_reason?.toString().trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'change_reason is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('rules')
      .select('id, rule_code, is_locked, default_value, current_value')
      .eq('rule_code', ruleCode)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) {
      return Response.json({ error: 'NOT_FOUND', message: `Rule '${ruleCode}' not found` }, { status: 404 });
    }

    if ((existing as any).is_locked) {
      return Response.json({ error: 'FORBIDDEN', message: 'Locked rules cannot be reset' }, { status: 403 });
    }

    const { data: updated, error } = await sb
      .from('rules')
      .update({
        current_value: (existing as any).default_value,
        changed_by: user.id,
        changed_at: new Date().toISOString(),
        change_reason: `RESET: ${body.change_reason.toString().trim()}`,
      })
      .eq('rule_code', ruleCode)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'rules', resourceId: ruleCode,
      ip: extractClientIP(request),
      newValues: { current_value: (existing as any).default_value, action: 'RESET' },
    });

    return Response.json(updated);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
