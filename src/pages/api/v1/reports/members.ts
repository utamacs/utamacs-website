export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

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

// GET /api/v1/reports/members — exec-only CSV export of member directory
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('profiles')
      .select('full_name, email, residency_type, portal_role, is_active, created_at, units(unit_number, block, floor)')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('full_name', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'EXPORT', resourceType: 'profiles', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { report: 'member-directory-export', count: (data ?? []).length },
    });

    const header = csvRow(['Full Name','Email','Flat No.','Block','Floor','Residency Type','Portal Role','Member Since']);
    const lines = (data ?? []).map((r: any) => csvRow([
      r.full_name ?? '',
      r.email ?? '',
      r.units?.unit_number ?? '',
      r.units?.block ?? '',
      r.units?.floor ?? '',
      r.residency_type ?? '',
      r.portal_role ?? '',
      r.created_at ? new Date(r.created_at).toLocaleDateString('en-IN') : '',
    ]));
    const date = new Date().toISOString().slice(0, 10);
    return new Response([header, ...lines].join('\n'), {
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="member-directory-${date}.csv"`,
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
