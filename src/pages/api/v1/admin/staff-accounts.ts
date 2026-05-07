export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const STAFF_ROLES = ['security_guard', 'vendor'] as const;

// GET /api/v1/admin/staff-accounts — list security guard and vendor accounts with lifecycle status
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'users.deactivate');

    const statusFilter = url.searchParams.get('status'); // 'active' | 'inactive' | '' = all

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('user_roles')
      .select(`
        user_id,
        role,
        granted_at,
        expires_at,
        profiles!inner(
          full_name, email, phone, unit_number,
          is_active, deactivated_at, deactivation_reason, created_at
        )
      `)
      .eq('society_id', SOCIETY_ID)
      .in('role', STAFF_ROLES);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    let accounts = (data ?? []).map((row: any) => ({
      user_id: row.user_id,
      role: row.role,
      granted_at: row.granted_at,
      expires_at: row.expires_at,
      full_name: row.profiles?.full_name ?? '—',
      email: row.profiles?.email ?? null,
      phone: row.profiles?.phone ?? null,
      unit_number: row.profiles?.unit_number ?? null,
      is_active: row.profiles?.is_active ?? true,
      deactivated_at: row.profiles?.deactivated_at ?? null,
      deactivation_reason: row.profiles?.deactivation_reason ?? null,
      created_at: row.profiles?.created_at ?? row.granted_at,
    }));

    if (statusFilter === 'active') {
      accounts = accounts.filter((a: any) => a.is_active);
    } else if (statusFilter === 'inactive') {
      accounts = accounts.filter((a: any) => !a.is_active);
    }

    accounts.sort((a: any, b: any) => {
      // Active first, then by name
      if (a.is_active !== b.is_active) return a.is_active ? -1 : 1;
      return (a.full_name ?? '').localeCompare(b.full_name ?? '');
    });

    return Response.json(accounts);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH /api/v1/admin/staff-accounts — activate or deactivate a staff account
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'users.deactivate');

    const body = await request.json() as {
      user_id?: string;
      action?: string;   // 'deactivate' | 'reactivate'
      reason?: string;
    };

    if (!body.user_id || !UUID_RE.test(body.user_id)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid user_id required' }, { status: 400 });
    }
    if (!['deactivate', 'reactivate'].includes(body.action ?? '')) {
      return Response.json({ error: 'VALIDATION', message: 'action must be deactivate or reactivate' }, { status: 400 });
    }
    if (body.action === 'deactivate' && !body.reason?.trim()) {
      return Response.json({ error: 'VALIDATION', message: 'Deactivation reason is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify the target is a staff account in this society
    const { data: roleRow } = await sb
      .from('user_roles')
      .select('role')
      .eq('user_id', body.user_id)
      .eq('society_id', SOCIETY_ID)
      .in('role', STAFF_ROLES)
      .maybeSingle();

    if (!roleRow) {
      return Response.json({ error: 'NOT_FOUND', message: 'Staff account not found in this society' }, { status: 404 });
    }

    const isDeactivate = body.action === 'deactivate';
    const profileUpdate: Record<string, unknown> = {
      is_active: !isDeactivate,
      deactivated_at: isDeactivate ? new Date().toISOString() : null,
      deactivation_reason: isDeactivate ? sanitizePlainText(body.reason!.trim()).slice(0, 500) : null,
    };

    const { error: updateErr } = await sb
      .from('profiles')
      .update(profileUpdate)
      .eq('id', body.user_id);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // Ban/unban the auth user to prevent login
    if (isDeactivate) {
      await sb.auth.admin.updateUserById(body.user_id, {
        ban_duration: '876000h', // effectively permanent ban (~100 years)
      });
    } else {
      await sb.auth.admin.updateUserById(body.user_id, { ban_duration: 'none' });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: isDeactivate ? 'DELETE' : 'UPDATE',
      resourceType: 'user_account', resourceId: body.user_id,
      ip: extractClientIP(request),
      oldValues: { is_active: !isDeactivate },
      newValues: { is_active: isDeactivate ? false : true, reason: body.reason ?? null },
    });

    return Response.json({ success: true, is_active: !isDeactivate });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
