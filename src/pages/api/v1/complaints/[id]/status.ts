import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_STATUS = ['Open','Assigned','In_Progress','Waiting_for_User','Resolved','Closed','Reopened'] as const;

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'complaints', 'update',
    );

    const { id } = params;
    const body = await request.json() as { status?: string; note?: string; assigned_to?: string | null };

    // Must have at least status or assigned_to
    if (!body.status && body.assigned_to === undefined) {
      return new Response(JSON.stringify({ error: 'status or assigned_to is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (body.status && !VALID_STATUS.includes(body.status as typeof VALID_STATUS[number])) {
      return new Response(JSON.stringify({ error: 'Invalid status value' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data: before, error: fetchErr } = await sb
      .from('complaints').select().eq('id', id).eq('society_id', SOCIETY_ID).single();
    if (fetchErr || !before) {
      return new Response(JSON.stringify({ error: 'Complaint not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }

    const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (body.status) {
      updates['status'] = body.status;
      if (body.status === 'Resolved') updates['resolved_at'] = new Date().toISOString();
      if (body.status === 'Closed') updates['closed_at'] = new Date().toISOString();
      // Auto-set to Assigned when assigning
      if (body.assigned_to && body.status === 'Open') updates['status'] = 'Assigned';
    }
    if (body.assigned_to !== undefined) {
      updates['assigned_to'] = body.assigned_to;
      // If no explicit status given and status is Open, auto-advance to Assigned
      if (!body.status && (before as any).status === 'Open' && body.assigned_to) {
        updates['status'] = 'Assigned';
      }
    }

    const { data, error } = await sb
      .from('complaints')
      .update(updates)
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      userId: user.id,
      societyId: user.societyId,
      action: 'UPDATE',
      resourceType: 'complaints',
      resourceId: id,
      oldValues: before,
      newValues: data,
      ip: extractClientIP(request),
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
