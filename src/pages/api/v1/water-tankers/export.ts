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

// GET /api/v1/water-tankers/export?from=YYYY-MM-DD&to=YYYY-MM-DD
// Returns CSV of tanker deliveries; exec-gated; audit logged.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const from = url.searchParams.get('from')?.trim() ?? '';
    const to   = url.searchParams.get('to')?.trim() ?? '';

    const sb = getSupabaseServiceClient();

    let q = sb
      .from('water_tankers')
      .select(`
        id, delivery_date, supplier_name, tanker_capacity_kl, tanker_count,
        total_kl, cost_per_kl, total_cost, payment_mode,
        invoice_number, notes, created_at
      `)
      .eq('society_id', SOCIETY_ID)
      .order('delivery_date', { ascending: false });

    if (from && /^\d{4}-\d{2}-\d{2}$/.test(from)) q = (q as any).gte('delivery_date', from);
    if (to   && /^\d{4}-\d{2}-\d{2}$/.test(to))   q = (q as any).lte('delivery_date', to);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (data ?? []) as any[];

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       'EXPORT',
      resourceType: 'water_tankers',
      resourceId:   SOCIETY_ID,
      newValues:    { row_count: rows.length, from, to },
      ip:           extractClientIP(request),
    });

    const header = csvRow([
      'Date', 'Supplier', 'Capacity (KL)', 'Tankers', 'Total KL',
      'Rate (₹/KL)', 'Total Cost (₹)', 'Payment Mode', 'Invoice No.', 'Notes',
    ]);

    const lines = rows.map((r: any) => csvRow([
      fmtDate(r.delivery_date),
      r.supplier_name ?? '',
      r.tanker_capacity_kl ?? '',
      r.tanker_count ?? 1,
      r.total_kl ?? (r.tanker_capacity_kl ?? 0) * (r.tanker_count ?? 1),
      r.cost_per_kl ?? '',
      r.total_cost ?? '',
      r.payment_mode ?? '',
      r.invoice_number ?? '',
      r.notes ?? '',
    ]));

    const date = new Date().toISOString().slice(0, 10);
    return new Response([header, ...lines].join('\n'), {
      headers: {
        'Content-Type':        'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="water-tankers-${date}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
