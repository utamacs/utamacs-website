export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

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

// GET /api/v1/admin/assets/export?category=&status=&expiry=amc|service
// Returns CSV of asset register; exec-gated; audit logged.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const category = url.searchParams.get('category')?.trim() ?? '';
    const status   = url.searchParams.get('status')?.trim() ?? '';
    const expiry   = url.searchParams.get('expiry')?.trim() ?? '';

    const sb    = getSupabaseServiceClient();
    const today = new Date().toISOString().slice(0, 10);
    const cut90 = (() => { const d = new Date(); d.setDate(d.getDate() + 90); return d.toISOString().slice(0, 10); })();

    let q = sb
      .from('infrastructure_assets')
      .select(`
        id, name, asset_code, category, make, model, serial_number,
        capacity, quantity, supplier,
        installation_date, warranty_expiry,
        next_service_date, last_service_date,
        amc_vendor, amc_start, amc_end, amc_amount,
        location_notes, status, notes, created_at,
        locations ( name )
      `)
      .eq('society_id', SOCIETY_ID)
      .order('category').order('name');

    if (category) q = (q as any).eq('category', category);
    if (status)   q = (q as any).eq('status', status);
    if (expiry === 'amc')     q = (q as any).lte('amc_end', cut90).not('amc_end', 'is', null);
    if (expiry === 'service') q = (q as any).lt('next_service_date', today).not('next_service_date', 'is', null);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const rows = (data ?? []) as any[];

    await writeAuditLog(sb, {
      societyId:    SOCIETY_ID,
      actorId:      user.id,
      action:       'EXPORT',
      resourceType: 'infrastructure_assets',
      resourceId:   SOCIETY_ID,
      newValues:    { row_count: rows.length, category, status, expiry },
      ipAddress:    extractClientIP(request),
    });

    const header = csvRow([
      'Asset Name', 'Asset Code', 'Category', 'Status', 'Make', 'Model',
      'Serial No.', 'Capacity', 'Quantity', 'Location', 'Location Notes',
      'Installed', 'Warranty Until', 'Last Service', 'Next Service',
      'Supplier', 'AMC Vendor', 'AMC Start', 'AMC Expiry', 'AMC Amount (₹)', 'Notes',
    ]);

    const lines = rows.map((r: any) => csvRow([
      r.name ?? '',
      r.asset_code ?? '',
      r.category ?? '',
      r.status ?? '',
      r.make ?? '',
      r.model ?? '',
      r.serial_number ?? '',
      r.capacity ?? '',
      r.quantity ?? 1,
      r.locations?.name ?? '',
      r.location_notes ?? '',
      fmtDate(r.installation_date),
      fmtDate(r.warranty_expiry),
      fmtDate(r.last_service_date),
      fmtDate(r.next_service_date),
      r.supplier ?? '',
      r.amc_vendor ?? '',
      fmtDate(r.amc_start),
      fmtDate(r.amc_end),
      r.amc_amount ?? '',
      r.notes ?? '',
    ]));

    const date   = new Date().toISOString().slice(0, 10);
    const suffix = category ? `-${category}` : status ? `-${status}` : expiry ? `-${expiry}-alert` : '';
    return new Response([header, ...lines].join('\n'), {
      headers: {
        'Content-Type':        'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="asset-register${suffix}-${date}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
