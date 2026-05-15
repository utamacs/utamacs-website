export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/security-patrol/summary — exec stats panel
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['PATROL_SUMMARY_WINDOW_DAYS', 'PATROL_INCIDENT_SLA_DAYS']);
    const windowDays = ruleInt(rules, 'PATROL_SUMMARY_WINDOW_DAYS', 30);
    const slaDays    = ruleInt(rules, 'PATROL_INCIDENT_SLA_DAYS', 3);

    const since = new Date(Date.now() - windowDays * 86_400_000).toISOString().slice(0, 10);

    const { data: logs, error } = await sb
      .from('patrol_logs')
      .select('id, patrol_date, shift, checkpoints, is_incident, resolved_at, guard_name')
      .eq('society_id', SOCIETY_ID)
      .gte('patrol_date', since)
      .order('patrol_date', { ascending: false });

    if (error) throw error;

    const total_shifts = logs?.length ?? 0;
    const total_incidents = logs?.filter(l => l.is_incident).length ?? 0;
    const open_incidents  = logs?.filter(l => l.is_incident && !l.resolved_at).length ?? 0;
    const overdue_incidents = logs?.filter(l => {
      if (!l.is_incident || l.resolved_at) return false;
      const daysSince = Math.floor((Date.now() - new Date(l.patrol_date).getTime()) / 86_400_000);
      return daysSince > slaDays;
    }).length ?? 0;

    // Checkpoint coverage: average checkpoints completed per shift
    const cpCounts = logs?.map(l => Array.isArray(l.checkpoints) ? l.checkpoints.length : 0) ?? [];
    const avg_checkpoints = cpCounts.length
      ? Math.round((cpCounts.reduce((a, b) => a + b, 0) / cpCounts.length) * 10) / 10
      : 0;

    // Most active guard
    const guardCount: Record<string, number> = {};
    for (const l of logs ?? []) {
      guardCount[l.guard_name] = (guardCount[l.guard_name] ?? 0) + 1;
    }
    const top_guard = Object.entries(guardCount).sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;

    // Shifts this calendar week (Mon–Sun)
    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - ((now.getDay() + 6) % 7)); // Monday
    weekStart.setHours(0, 0, 0, 0);
    const shifts_this_week = logs?.filter(l => new Date(l.patrol_date + 'T00:00:00') >= weekStart).length ?? 0;

    return Response.json({
      window_days:         windowDays,
      since,
      total_shifts,
      shifts_this_week,
      total_incidents,
      open_incidents,
      overdue_incidents,
      avg_checkpoints,
      top_guard,
      sla_days:            slaDays,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
