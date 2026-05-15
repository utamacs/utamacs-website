export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: any) {
  return user.isAdmin || ['executive','secretary','president'].includes(user.portalRole ?? '') || ['executive','admin'].includes(user.role ?? '');
}

function csvRow(fields: (string | number | null | undefined)[]) {
  return fields.map(f => {
    const s = String(f ?? '');
    return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const from     = url.searchParams.get('from')      ?? '';
    const to       = url.searchParams.get('to')        ?? '';
    const category = url.searchParams.get('category')  ?? '';
    const priority = url.searchParams.get('priority')  ?? '';
    const format   = url.searchParams.get('format')    ?? 'json';

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('complaints')
      .select('id, title, status, priority, category, sla_breached, created_at, resolved_at, satisfaction_rating, raised_by, profiles(full_name)')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (from)     q = (q as any).gte('created_at', from);
    if (to)       q = (q as any).lte('created_at', to + 'T23:59:59Z');
    if (category) q = (q as any).eq('category', category);
    if (priority) q = (q as any).eq('priority', priority);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (data ?? []).map((r: any) => ({
      ...r,
      resolution_hours: r.resolved_at
        ? Math.round((new Date(r.resolved_at).getTime() - new Date(r.created_at).getTime()) / 3600000)
        : null,
    }));

    if (format === 'csv') {
      const header = csvRow(['ID','Title','Category','Priority','Status','SLA Breached','Raised By','Created','Resolved','Hours to Resolve','Rating']);
      const lines = rows.map((r: any) => csvRow([
        r.id.slice(-8).toUpperCase(),
        r.title,
        r.category,
        r.priority,
        r.status,
        r.sla_breached ? 'Yes' : 'No',
        r.profiles?.full_name ?? '',
        r.created_at ? new Date(r.created_at).toLocaleDateString('en-IN') : '',
        r.resolved_at ? new Date(r.resolved_at).toLocaleDateString('en-IN') : '',
        r.resolution_hours ?? '',
        r.satisfaction_rating ?? '',
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="complaints-report-${date}.csv"`,
        },
      });
    }

    const resolved = rows.filter((r: any) => ['Resolved','Closed'].includes(r.status));
    const avgHours = resolved.length
      ? Math.round(resolved.reduce((s: number, r: any) => s + (r.resolution_hours ?? 0), 0) / resolved.length)
      : 0;
    const avgRating = rows.filter((r: any) => r.satisfaction_rating).length
      ? (rows.reduce((s: number, r: any) => s + (r.satisfaction_rating ?? 0), 0) / rows.filter((r: any) => r.satisfaction_rating).length).toFixed(1)
      : null;

    return Response.json({
      rows,
      summary: {
        total: rows.length,
        resolved: resolved.length,
        sla_breached: rows.filter((r: any) => r.sla_breached).length,
        avg_resolution_hours: avgHours,
        avg_rating: avgRating,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
