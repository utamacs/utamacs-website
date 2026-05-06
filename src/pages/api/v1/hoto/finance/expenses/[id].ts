export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — expense detail (auth: finance.view)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.view');

    const { data, error } = await getSupabaseServiceClient()
      .from('governance_expenses')
      .select('*')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) {
      return Response.json({ error: 'NOT_FOUND', message: 'Expense not found' }, { status: 404 });
    }

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — update expense metadata (auth: finance.enter, same-day edits only)
// Editable: payee, purpose, payment_mode, reference_number, is_recurring, byelaw_authority
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const sb = getSupabaseServiceClient();
    const { data: existing, error: fetchErr } = await sb
      .from('governance_expenses')
      .select('id, expense_date, sanctioned_by')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Expense not found' }, { status: 404 });
    }

    // Only the recorder or an admin can edit; only on the same day
    const today = new Date().toISOString().slice(0, 10);
    if ((existing as any).expense_date !== today && !user.isAdmin) {
      return Response.json({
        error: 'CONFLICT',
        message: 'Expenses can only be edited on the day they are recorded',
      }, { status: 409 });
    }

    if ((existing as any).sanctioned_by !== user.id && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN', message: 'Only the recorder can edit this expense' }, { status: 403 });
    }

    const body = await request.json() as Record<string, unknown>;
    const allowed = ['payee', 'purpose', 'payment_mode', 'reference_number', 'is_recurring', 'byelaw_authority'];
    const updates: Record<string, unknown> = {};
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('governance_expenses')
      .update(updates)
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'governance_expenses', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
