export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// GET — list approvals (member: own unit; exec: all or filtered by maid_id/unit_id)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.view');
    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');
    const url = new URL(request.url);

    let query = sb
      .from('maid_unit_approvals')
      .select(`
        id, maid_id, unit_id, is_active, notes, approved_at,
        maids(full_name, work_type, phone, police_verified, photo_key),
        units(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('approved_at', { ascending: false });

    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      const unitId = (profile as any)?.unit_id;
      if (!unitId) return Response.json([]);
      query = (query as any).eq('unit_id', unitId);
    } else {
      const maidId = url.searchParams.get('maid_id');
      const unitId = url.searchParams.get('unit_id');
      if (maidId && UUID_RE.test(maidId)) query = (query as any).eq('maid_id', maidId);
      if (unitId && UUID_RE.test(unitId)) query = (query as any).eq('unit_id', unitId);
    }

    const { data, error } = await query;
    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — approve a maid for a unit (member: own unit; exec: any unit)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.approve');
    const body = await request.json() as { maid_id?: string; unit_id?: string; notes?: string };

    if (!body.maid_id || !body.unit_id) {
      return Response.json({ error: 'MISSING_FIELDS', message: 'maid_id and unit_id are required.' }, { status: 400 });
    }
    if (!UUID_RE.test(body.maid_id) || !UUID_RE.test(body.unit_id)) {
      return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');

    // Non-exec can only approve for their own unit
    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if ((profile as any)?.unit_id !== body.unit_id) {
        return Response.json({ error: 'FORBIDDEN', message: 'You can only approve maids for your own unit.' }, { status: 403 });
      }
    }

    // Upsert: if previously deactivated, re-activate
    const { data, error } = await sb
      .from('maid_unit_approvals')
      .upsert({
        society_id: SOCIETY_ID,
        maid_id: body.maid_id,
        unit_id: body.unit_id,
        approved_by: user.id,
        notes: body.notes ? sanitizePlainText(body.notes).slice(0, 300) : null,
        is_active: true,
        approved_at: new Date().toISOString(),
      }, { onConflict: 'maid_id,unit_id' })
      .select()
      .single();

    if (error) throw error;

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'CREATE', resourceType: 'maid_approval',
      resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { maid_id: body.maid_id, unit_id: body.unit_id },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — deactivate an approval
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.approve');
    const body = await request.json() as { id?: string; is_active?: boolean };
    const approvalId = body.id;

    if (!approvalId || !UUID_RE.test(approvalId)) {
      return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');

    // Check ownership if not exec
    const { data: approval } = await sb
      .from('maid_unit_approvals')
      .select('unit_id')
      .eq('id', approvalId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!approval) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if ((profile as any)?.unit_id !== (approval as any).unit_id) {
        return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
      }
    }

    const { data, error } = await sb
      .from('maid_unit_approvals')
      .update({ is_active: body.is_active ?? false })
      .eq('id', approvalId)
      .select()
      .single();

    if (error) throw error;
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
