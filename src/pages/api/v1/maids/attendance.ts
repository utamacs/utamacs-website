export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list attendance (member: own unit; exec: filtered by maid/unit/date)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.view');
    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');
    const url = new URL(request.url);

    let query = sb
      .from('maid_attendance')
      .select(`
        id, maid_id, unit_id, date, entry_time, exit_time, notes, created_at,
        maids(full_name, work_type),
        units(unit_number, block)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });

    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      const unitId = (profile as any)?.unit_id;
      if (!unitId) return Response.json([]);
      query = (query as any).eq('unit_id', unitId);
    } else {
      const maidId = url.searchParams.get('maid_id');
      const unitId = url.searchParams.get('unit_id');
      const from   = url.searchParams.get('from');
      const to     = url.searchParams.get('to');
      if (maidId && UUID_RE.test(maidId)) query = (query as any).eq('maid_id', maidId);
      if (unitId && UUID_RE.test(unitId)) query = (query as any).eq('unit_id', unitId);
      if (from) query = (query as any).gte('date', from);
      if (to)   query = (query as any).lte('date', to);
    }

    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10), 200);
    query = (query as any).limit(limit);

    const { data, error } = await query;
    if (error) throw error;
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — log attendance entry
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'maids.manage');
    const body = await request.json() as {
      maid_id?: string; unit_id?: string;
      date?: string; entry_time?: string; exit_time?: string; notes?: string;
    };

    if (!body.maid_id || !body.unit_id || !body.date) {
      return Response.json({ error: 'MISSING_FIELDS', message: 'maid_id, unit_id, and date are required.' }, { status: 400 });
    }
    if (!UUID_RE.test(body.maid_id) || !UUID_RE.test(body.unit_id)) {
      return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const isPrivileged = hasFeature(user, 'maids.manage');

    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      if ((profile as any)?.unit_id !== body.unit_id) {
        return Response.json({ error: 'FORBIDDEN', message: 'You can only log attendance for your own unit.' }, { status: 403 });
      }
    }

    // Upsert: one record per maid+unit+date
    const { data, error } = await sb
      .from('maid_attendance')
      .upsert({
        society_id: SOCIETY_ID,
        maid_id:    body.maid_id,
        unit_id:    body.unit_id,
        date:       body.date,
        entry_time: body.entry_time || null,
        exit_time:  body.exit_time  || null,
        marked_by:  user.id,
        notes:      body.notes ? sanitizePlainText(body.notes).slice(0, 200) : null,
      }, { onConflict: 'maid_id,unit_id,date' })
      .select()
      .single();

    if (error) throw error;
    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
