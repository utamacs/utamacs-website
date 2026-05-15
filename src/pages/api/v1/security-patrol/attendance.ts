export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/security-patrol/attendance?days=N
// Returns per-guard attendance summary for the last N days (default: PATROL_ATTENDANCE_WINDOW_DAYS).
// Exec-gated.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['PATROL_ATTENDANCE_WINDOW_DAYS']);
    const windowDays = ruleInt(rules, 'PATROL_ATTENDANCE_WINDOW_DAYS', 30);

    const overrideDays = parseInt(url.searchParams.get('days') ?? '0', 10);
    const days = overrideDays > 0 && overrideDays <= 365 ? overrideDays : windowDays;

    const since = new Date(Date.now() - days * 86_400_000).toISOString().slice(0, 10);

    const { data: logs, error } = await sb
      .from('patrol_logs')
      .select('guard_name, patrol_date, shift, is_incident, resolved_at, checkpoints')
      .eq('society_id', SOCIETY_ID)
      .gte('patrol_date', since)
      .order('patrol_date', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Aggregate per guard
    const guardMap: Record<string, {
      total_shifts:    number;
      total_incidents: number;
      open_incidents:  number;
      last_active:     string;
      shift_counts:    Record<string, number>;
      avg_checkpoints: number;
      cp_total:        number;
    }> = {};

    for (const log of logs ?? []) {
      const name = (log.guard_name as string) ?? 'Unknown';
      if (!guardMap[name]) {
        guardMap[name] = {
          total_shifts: 0, total_incidents: 0, open_incidents: 0,
          last_active: '', shift_counts: {}, avg_checkpoints: 0, cp_total: 0,
        };
      }
      const g = guardMap[name];
      g.total_shifts++;
      if (!g.last_active || (log.patrol_date as string) > g.last_active) {
        g.last_active = log.patrol_date as string;
      }
      if (log.is_incident) {
        g.total_incidents++;
        if (!log.resolved_at) g.open_incidents++;
      }
      const shift = (log.shift as string) ?? 'unknown';
      g.shift_counts[shift] = (g.shift_counts[shift] ?? 0) + 1;
      g.cp_total += Array.isArray(log.checkpoints) ? (log.checkpoints as unknown[]).length : 0;
    }

    // Build response array, sorted by total shifts desc
    const attendance = Object.entries(guardMap)
      .map(([name, g]) => ({
        guard_name:      name,
        total_shifts:    g.total_shifts,
        total_incidents: g.total_incidents,
        open_incidents:  g.open_incidents,
        last_active:     g.last_active,
        avg_checkpoints: g.total_shifts > 0 ? Math.round((g.cp_total / g.total_shifts) * 10) / 10 : 0,
        shift_breakdown: g.shift_counts,
        days_since_last: g.last_active
          ? Math.floor((Date.now() - new Date(g.last_active + 'T00:00:00').getTime()) / 86_400_000)
          : null,
      }))
      .sort((a, b) => b.total_shifts - a.total_shifts);

    // Total days in window — for coverage calculation
    const totalShifts   = attendance.reduce((s, g) => s + g.total_shifts, 0);
    const openIncidents = attendance.reduce((s, g) => s + g.open_incidents, 0);

    return Response.json({
      window_days:    days,
      since,
      total_shifts:   totalShifts,
      open_incidents: openIncidents,
      guard_count:    attendance.length,
      attendance,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
