export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: { isAdmin: boolean; portalRole?: string | null; role?: string | null }) {
  return user.isAdmin ||
    ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
    ['executive', 'admin'].includes(user.role ?? '');
}

// GET /api/v1/admin/holidays?year=2025
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const year = parseInt(url.searchParams.get('year') ?? String(new Date().getFullYear()), 10);
    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('holiday_calendar')
      .select('id, date, name, is_national, created_at')
      .eq('society_id', SOCIETY_ID)
      .gte('date', `${year}-01-01`)
      .lte('date', `${year}-12-31`)
      .order('date', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/admin/holidays — add a single holiday
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as { date?: string; name?: string; is_national?: boolean };
    if (!body.date || !body.name?.trim()) {
      return Response.json({ error: 'VALIDATION', message: 'date and name are required' }, { status: 400 });
    }
    const dateRe = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRe.test(body.date)) {
      return Response.json({ error: 'VALIDATION', message: 'date must be YYYY-MM-DD' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('holiday_calendar')
      .insert({
        society_id:  SOCIETY_ID,
        date:        body.date,
        name:        String(body.name).trim().slice(0, 100),
        is_national: body.is_national ?? false,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return Response.json({ error: 'CONFLICT', message: 'A holiday already exists on this date' }, { status: 409 });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }
    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
