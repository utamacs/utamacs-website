export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: { isAdmin: boolean; portalRole?: string | null }) {
  return user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
}

function csvRow(fields: (string | number | null | undefined | boolean)[]) {
  return fields.map(f => {
    const s = String(f ?? '');
    return s.includes(',') || s.includes('"') || s.includes('\n')
      ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
}

function fmtDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '';
}

// GET /api/v1/security-patrol/export?from=YYYY-MM-DD&to=YYYY-MM-DD&incidents_only=true
// Returns CSV of patrol logs; exec-gated; audit logged.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const from          = url.searchParams.get('from')?.trim() ?? '';
    const to            = url.searchParams.get('to')?.trim() ?? '';
    const incidentsOnly = url.searchParams.get('incidents_only') === 'true';

    const sb = getSupabaseServiceClient();

    let q = sb
      .from('patrol_logs')
      .select(`
        id, patrol_date, shift, guard_name, start_time, end_time,
        checkpoints, incidents, remarks, is_incident,
        resolved_at, resolution_note, created_at
      `)
      .eq('society_id', SOCIETY_ID)
      .order('patrol_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (from && /^\d{4}-\d{2}-\d{2}$/.test(from)) q = (q as any).gte('patrol_date', from);
    if (to   && /^\d{4}-\d{2}-\d{2}$/.test(to))   q = (q as any).lte('patrol_date', to);
    if (incidentsOnly) q = (q as any).eq('is_incident', true);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (data ?? []) as any[];

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'EXPORT',
      resourceType: 'patrol_logs',
      resourceId:   SOCIETY_ID,
      newValues:    { row_count: rows.length, from, to, incidentsOnly },
      ip:           extractClientIP(request),
    });

    const header = csvRow([
      'Date', 'Shift', 'Guard Name', 'Start Time', 'End Time',
      'Checkpoints', 'Incident?', 'Incident Details', 'Remarks',
      'Resolved?', 'Resolution Note',
    ]);

    const lines = rows.map((r: any) => {
      const checkpoints = Array.isArray(r.checkpoints) ? r.checkpoints.join('; ') : '';
      return csvRow([
        fmtDate(r.patrol_date),
        r.shift ?? '',
        r.guard_name ?? '',
        r.start_time ?? '',
        r.end_time ?? '',
        checkpoints,
        r.is_incident ? 'Yes' : 'No',
        r.incidents ?? '',
        r.remarks ?? '',
        r.resolved_at ? 'Yes' : (r.is_incident ? 'No' : ''),
        r.resolution_note ?? '',
      ]);
    });

    const date = new Date().toISOString().slice(0, 10);
    const suffix = incidentsOnly ? '-incidents' : '';
    return new Response([header, ...lines].join('\n'), {
      headers: {
        'Content-Type':        'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="patrol-log${suffix}-${date}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
