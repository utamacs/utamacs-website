export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/maids/attendance/summary?year=2025&month=5[&maid_id=uuid][&unit_id=uuid]
// Returns per-maid day count for the requested month — useful for salary reference.
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;

    const url    = new URL(request.url);
    const year   = parseInt(url.searchParams.get('year')  ?? String(new Date().getFullYear()), 10);
    const month  = parseInt(url.searchParams.get('month') ?? String(new Date().getMonth() + 1), 10);
    const maidId = url.searchParams.get('maid_id') ?? '';
    const unitId = url.searchParams.get('unit_id') ?? '';

    if (!Number.isFinite(year) || year < 2020 || year > 2099) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid year.' }, { status: 400 });
    }
    if (!Number.isFinite(month) || month < 1 || month > 12) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid month (1–12).' }, { status: 400 });
    }
    if (maidId && !UUID_RE.test(maidId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });
    if (unitId && !UUID_RE.test(unitId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    // Month range in ISO
    const from = `${year}-${String(month).padStart(2,'0')}-01`;
    const to   = new Date(year, month, 0).toISOString().split('T')[0]; // last day of month

    const sb = getSupabaseServiceClient();

    // Members can only see their own unit's summary
    let effectiveUnitId = unitId;
    if (!isPrivileged) {
      const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();
      const myUnit = (profile as any)?.unit_id;
      if (!myUnit) return Response.json({ summary: [], year, month });
      effectiveUnitId = myUnit;
    }

    let query = sb
      .from('maid_attendance')
      .select('maid_id, date, maids(full_name, work_type)')
      .eq('society_id', SOCIETY_ID)
      .gte('date', from)
      .lte('date', to);

    if (maidId)           query = (query as any).eq('maid_id', maidId);
    if (effectiveUnitId)  query = (query as any).eq('unit_id', effectiveUnitId);

    const { data: rows, error } = await query;
    if (error) throw error;

    // Aggregate: per maid → { maid_id, full_name, work_type, days_present, dates[] }
    const map = new Map<string, { maid_id: string; full_name: string; work_type: string; days: Set<string> }>();
    for (const row of (rows ?? [])) {
      if (!map.has(row.maid_id)) {
        map.set(row.maid_id, {
          maid_id:    row.maid_id,
          full_name:  (row.maids as any)?.full_name ?? 'Unknown',
          work_type:  (row.maids as any)?.work_type ?? '',
          days:       new Set(),
        });
      }
      map.get(row.maid_id)!.days.add(row.date);
    }

    const summary = Array.from(map.values())
      .map(({ maid_id, full_name, work_type, days }) => ({
        maid_id,
        full_name,
        work_type,
        days_present: days.size,
        dates: Array.from(days).sort(),
      }))
      .sort((a, b) => a.full_name.localeCompare(b.full_name));

    const totalWorkingDays = new Date(year, month, 0).getDate(); // days in month
    return Response.json({ year, month, total_working_days: totalWorkingDays, summary });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
