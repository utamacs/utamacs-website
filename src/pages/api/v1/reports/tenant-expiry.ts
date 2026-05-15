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

    const wing      = url.searchParams.get('wing')    ?? '';
    const withinDays = parseInt(url.searchParams.get('within_days') ?? '90', 10);
    const format    = url.searchParams.get('format')  ?? 'json';

    const cutoff = new Date(Date.now() + withinDays * 86400000).toISOString().slice(0, 10);
    const today  = new Date().toISOString().slice(0, 10);

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('tenant_kyc')
      .select(`
        id, tenant_name, agreement_end_date, kyc_status, re_kyc_due_date,
        units(unit_number, block),
        profiles(full_name, email)
      `)
      .eq('society_id', SOCIETY_ID)
      .lte('agreement_end_date', cutoff)
      .order('agreement_end_date', { ascending: true });

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const now = Date.now();
    let rows = (data ?? []).map((r: any) => ({
      ...r,
      days_to_expiry: r.agreement_end_date
        ? Math.ceil((new Date(r.agreement_end_date).getTime() - now) / 86400000)
        : null,
      is_expired: r.agreement_end_date ? r.agreement_end_date < today : false,
    }));

    if (wing) rows = rows.filter((r: any) => r.units?.block === wing);

    if (format === 'csv') {
      const header = csvRow(['Tenant Name','Flat No.','Block','Agreement End Date','Days to Expiry','Status','KYC Status','Re-KYC Due']);
      const lines = rows.map((r: any) => csvRow([
        r.tenant_name ?? '',
        r.units?.unit_number ?? '',
        r.units?.block ?? '',
        r.agreement_end_date ?? '',
        r.days_to_expiry ?? '',
        r.is_expired ? 'Expired' : 'Expiring Soon',
        r.kyc_status ?? '',
        r.re_kyc_due_date ?? '',
      ]));
      const date = new Date().toISOString().slice(0, 10);
      return new Response([header, ...lines].join('\n'), {
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename="tenant-expiry-${date}.csv"`,
        },
      });
    }

    return Response.json({
      rows,
      count: rows.length,
      expired: rows.filter((r: any) => r.is_expired).length,
      expiring_soon: rows.filter((r: any) => !r.is_expired).length,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
