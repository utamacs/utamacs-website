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

// GET /api/v1/hoto/snags/export
// Query: status, category, severity, snag_scope, hoto_item_id, include_closed (default false)
// Returns CSV of snags; exec/admin only.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const status        = url.searchParams.get('status')?.trim() ?? '';
    const category      = url.searchParams.get('category')?.trim() ?? '';
    const severity      = url.searchParams.get('severity')?.trim() ?? '';
    const snagScope     = url.searchParams.get('snag_scope')?.trim() ?? '';
    const hotoItemId    = url.searchParams.get('hoto_item_id')?.trim() ?? '';
    const includeClosed = url.searchParams.get('include_closed') === 'true';

    const sb = getSupabaseServiceClient();

    let q = sb
      .from('snag_items')
      .select(`
        id, snag_scope, category, subcategory, location, description,
        flat_number, severity, status,
        builder_ref, builder_committed_date, builder_acknowledged,
        resolved_by_builder, verified_by_committee,
        days_overdue, created_at, resolved_at, updated_at
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('deleted', false)
      .order('category')
      .order('severity', { ascending: false });

    if (status)    q = (q as any).eq('status', status);
    if (category)  q = (q as any).eq('category', category);
    if (severity)  q = (q as any).eq('severity', severity);
    if (snagScope) q = (q as any).eq('snag_scope', snagScope);
    if (!includeClosed) q = (q as any).not('status', 'in', '("VERIFIED_CLOSED","WITHDRAWN","CLOSED")');

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    let rows = (data ?? []) as any[];

    // Optional filter by linked HOTO item
    if (hotoItemId) {
      const { data: links } = await sb
        .from('snag_hoto_links')
        .select('snag_item_id')
        .eq('hoto_item_id', hotoItemId);
      const linked = new Set((links ?? []).map((l: any) => l.snag_item_id));
      rows = rows.filter((r: any) => linked.has(r.id));
    }

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'EXPORT',
      resourceType: 'snag_items',
      resourceId:   SOCIETY_ID,
      newValues:    { row_count: rows.length, filters: { status, category, severity, snagScope, hotoItemId, includeClosed } },
      ip:           extractClientIP(request),
    });

    const header = csvRow([
      'Snag ID', 'Scope', 'Category', 'Sub-category', 'Location', 'Flat No.',
      'Description', 'Severity', 'Status',
      'Builder Ref', 'Builder Committed Date', 'Builder Acknowledged',
      'Resolved by Builder', 'Verified by Committee',
      'Days Overdue', 'Created', 'Resolved',
    ]);

    const lines = rows.map((r: any) => csvRow([
      r.id,
      r.snag_scope ?? '',
      r.category ?? '',
      r.subcategory ?? '',
      r.location ?? '',
      r.flat_number ?? '',
      r.description ?? '',
      r.severity ?? '',
      r.status ?? '',
      r.builder_ref ?? '',
      fmtDate(r.builder_committed_date),
      r.builder_acknowledged ? 'Yes' : 'No',
      r.resolved_by_builder ? 'Yes' : 'No',
      r.verified_by_committee ? 'Yes' : 'No',
      r.days_overdue ?? 0,
      fmtDate(r.created_at),
      fmtDate(r.resolved_at),
    ]));

    const date = new Date().toISOString().slice(0, 10);
    return new Response([header, ...lines].join('\n'), {
      headers: {
        'Content-Type':        'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="snag-list-${date}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
