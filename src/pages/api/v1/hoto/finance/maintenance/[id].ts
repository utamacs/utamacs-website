export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// PATCH — update a maintenance record (auth: finance.enter; admin anytime, others same-day only)
// Editable: paid_date, payment_mode, reference_number, amount
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const sb = getSupabaseServiceClient();
    const { data: existing, error: fetchErr } = await sb
      .from('maintenance_records')
      .select('id, flat_number, period_month, period_year, created_at, recorded_by')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Maintenance record not found' }, { status: 404 });
    }

    const rec = existing as any;

    // Non-admins can only edit records they entered, and only on the same day
    if (!user.isAdmin) {
      const today = new Date().toISOString().slice(0, 10);
      const createdDay = rec.created_at?.slice(0, 10);
      if (createdDay !== today) {
        return Response.json({
          error: 'CONFLICT',
          message: 'Maintenance records can only be edited on the day they are entered. Contact an admin for later corrections.',
        }, { status: 409 });
      }
      if (rec.recorded_by !== user.id) {
        return Response.json({ error: 'FORBIDDEN', message: 'Only the recorder can edit this record' }, { status: 403 });
      }
    }

    const body = await request.json() as {
      paid_date?: string | null;
      payment_mode?: string | null;
      reference_number?: string | null;
      amount?: number;
    };

    const updates: Record<string, unknown> = {};
    if (body.paid_date !== undefined) updates.paid_date = body.paid_date ?? null;
    if (body.payment_mode !== undefined) updates.payment_mode = body.payment_mode?.trim() ?? null;
    if (body.reference_number !== undefined) updates.reference_number = body.reference_number?.trim() ?? null;
    if (body.amount !== undefined) {
      if (!body.amount || body.amount <= 0) {
        return Response.json({ error: 'VALIDATION_ERROR', message: 'amount must be a positive number' }, { status: 400 });
      }
      updates.amount = body.amount;
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('maintenance_records')
      .update(updates)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'maintenance_records', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
