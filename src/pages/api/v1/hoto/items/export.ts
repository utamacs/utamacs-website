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

function csvRow(fields: (string | number | null | undefined)[]) {
  return fields.map(f => {
    const s = String(f ?? '');
    return s.includes(',') || s.includes('"') || s.includes('\n')
      ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
}

function fmtDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '';
}

// GET /api/v1/hoto/items/export
// Query: status, category, include_closed (default false)
// Returns CSV of HOTO items; exec/admin only.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const status        = url.searchParams.get('status')?.trim() ?? '';
    const category      = url.searchParams.get('category')?.trim() ?? '';
    const includeClosed = url.searchParams.get('include_closed') === 'true';

    const sb = getSupabaseServiceClient();

    let q = sb
      .from('hoto_items')
      .select(`
        id, hoto_category, title, priority, status, deadline,
        builder_sla_date, days_overdue, responsible_role,
        president_approved_at, secretary_approved_at,
        rera_escalation_eligible, notice_sent,
        created_at, status_changed_at
      `)
      .eq('society_id', SOCIETY_ID)
      .order('hoto_category')
      .order('priority', { ascending: false });

    if (status)   q = (q as any).eq('status', status);
    if (category) q = (q as any).eq('hoto_category', category);
    if (!includeClosed) q = (q as any).neq('status', 'CLOSED');

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (data ?? []) as any[];

    await writeAuditLog(sb, {
      societyId:    SOCIETY_ID,
      actorId:      user.id,
      action:       'EXPORT',
      resourceType: 'hoto_items',
      resourceId:   SOCIETY_ID,
      newValues:    { row_count: rows.length, filters: { status, category, includeClosed } },
      ipAddress:    extractClientIP(request),
    });

    const header = csvRow([
      'Item ID', 'Category', 'Title', 'Priority', 'Status',
      'Deadline', 'Builder SLA Date', 'Days Overdue', 'Responsible Role',
      'Secretary Approved', 'President Approved',
      'RERA Eligible', 'Notice Sent', 'Created', 'Last Status Change',
    ]);

    const lines = rows.map((r: any) => csvRow([
      r.id,
      r.hoto_category ?? '',
      r.title ?? '',
      r.priority ?? '',
      r.status ?? '',
      fmtDate(r.deadline),
      fmtDate(r.builder_sla_date),
      r.days_overdue ?? 0,
      r.responsible_role ?? '',
      fmtDate(r.secretary_approved_at),
      fmtDate(r.president_approved_at),
      r.rera_escalation_eligible ? 'Yes' : 'No',
      r.notice_sent ? 'Yes' : 'No',
      fmtDate(r.created_at),
      fmtDate(r.status_changed_at),
    ]));

    const date = new Date().toISOString().slice(0, 10);
    return new Response([header, ...lines].join('\n'), {
      headers: {
        'Content-Type':        'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="hoto-items-${date}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
