export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_STATUSES = ['draft', 'issued', 'in_progress', 'completed', 'disputed', 'closed'] as const;
type WorkOrderStatus = typeof VALID_STATUSES[number];

// Status transitions allowed per role:
// exec/admin: any → any
// vendor: issued → in_progress, in_progress → completed
const VENDOR_ALLOWED: Partial<Record<WorkOrderStatus, WorkOrderStatus[]>> = {
  issued:      ['in_progress'],
  in_progress: ['completed'],
};

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('work_orders')
      .select('*, vendors(id, name, category, email, phone)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: error.code === 'PGRST116' ? 404 : 500 });

    // Vendor can only view their own work orders
    if (user.role === 'vendor') {
      const { data: vendorProfile } = await sb.from('vendors').select('id').eq('email', user.id).single();
      if (!vendorProfile || data.vendor_id !== vendorProfile.id) {
        throw Object.assign(new Error('Not found'), { status: 404 });
      }
    } else if (!['executive', 'admin'].includes(user.role)) {
      throw Object.assign(new Error('Forbidden'), { status: 403 });
    }

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

/** PATCH /api/v1/vendors/work-orders/:id — update status (and optionally final_amount, notes) */
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const isExec = ['executive', 'admin'].includes(user.role);
    const isVendor = user.role === 'vendor';

    if (!isExec && !isVendor) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const sb = getSupabaseServiceClient();

    // Fetch existing work order
    const { data: existing, error: fetchErr } = await sb
      .from('work_orders')
      .select('id, status, vendor_id, created_by, title, vendors(name, email)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    }

    // Vendor: verify the work order belongs to them
    if (isVendor) {
      const { data: vendorProfile } = await sb.from('vendors').select('id').eq('email', user.id).single();
      if (!vendorProfile || existing.vendor_id !== vendorProfile.id) {
        return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
      }
    }

    const body = await request.json() as {
      status?: string;
      final_amount?: number;
      notes?: string;
    };

    const newStatus = body.status as WorkOrderStatus | undefined;
    const oldStatus = existing.status as WorkOrderStatus;

    // Validate status transition
    if (newStatus) {
      if (!VALID_STATUSES.includes(newStatus)) {
        return Response.json({ error: 'VALIDATION_ERROR', message: `Invalid status: ${newStatus}` }, { status: 400 });
      }
      if (isVendor) {
        const allowed = VENDOR_ALLOWED[oldStatus] ?? [];
        if (!allowed.includes(newStatus)) {
          return Response.json({
            error: 'VALIDATION_ERROR',
            message: `Vendor cannot transition from '${oldStatus}' to '${newStatus}'`,
          }, { status: 422 });
        }
      }
    }

    const updates: Record<string, unknown> = {};
    if (newStatus) {
      updates.status = newStatus;
      if (newStatus === 'completed') updates.completed_at = new Date().toISOString();
    }
    if (isExec && body.final_amount !== undefined) updates.final_amount = body.final_amount;
    if (body.notes !== undefined) updates.notes = body.notes;

    if (Object.keys(updates).length === 0) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No valid fields to update' }, { status: 400 });
    }

    const { data: updated, error: updErr } = await sb
      .from('work_orders')
      .update(updates)
      .eq('id', params.id!)
      .select()
      .single();

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'work_orders', resourceId: params.id!,
      ip: extractClientIP(request),
      oldValues: { status: oldStatus },
      newValues: updates,
    });

    // Notify relevant parties of status change (fire-and-forget)
    if (newStatus && newStatus !== oldStatus) {
      const vendorName = (existing.vendors as any)?.name ?? 'Vendor';
      const orderTitle = existing.title;

      // Notify exec/admin if vendor moved status forward
      if (isVendor) {
        Promise.resolve(
          sb.from('notifications').insert({
            society_id: SOCIETY_ID,
            user_id: existing.created_by,
            type: 'work_order_update',
            title: 'Work Order Updated',
            body: `${vendorName} marked "${orderTitle}" as ${newStatus.replace('_', ' ')}.`,
            reference_type: 'work_orders',
            reference_id: params.id!,
          }),
        ).catch(() => {});
      } else {
        // Exec updated status — notify the vendor's linked user if they have an account
        const vendorEmail = (existing.vendors as any)?.email;
        if (vendorEmail) {
          const { data: vendorUser } = await sb
            .from('profiles')
            .select('id')
            .eq('email', vendorEmail)
            .maybeSingle();
          if (vendorUser) {
            Promise.resolve(
              sb.from('notifications').insert({
                society_id: SOCIETY_ID,
                user_id: vendorUser.id,
                type: 'work_order_update',
                title: 'Work Order Status Changed',
                body: `Work order "${orderTitle}" has been moved to ${newStatus.replace('_', ' ')}.`,
                reference_type: 'work_orders',
                reference_id: params.id!,
              }),
            ).catch(() => {});
          }
        }
      }
    }

    return Response.json(updated);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
