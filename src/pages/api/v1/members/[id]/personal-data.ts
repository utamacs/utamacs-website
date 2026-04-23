import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// DPDPA 2023 — Right to Erasure
// Anonymizes PII columns in profiles. Preserves non-personal records (complaints, payments)
// with a pseudonymous user_id so society financials and complaint history remain intact.
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);

    const targetId = params.id!;

    // Allow: admin deleting any user, or a user erasing their own data
    if (user.role !== 'admin' && user.id !== targetId) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify the profile exists and belongs to this society
    const { data: profile } = await sb
      .from('profiles')
      .select('id, full_name')
      .eq('id', targetId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Guard against erasing another admin (admin-on-admin protection)
    if (user.role === 'admin' && user.id !== targetId) {
      const { data: targetRole } = await sb
        .from('user_roles')
        .select('role')
        .eq('user_id', targetId)
        .eq('society_id', SOCIETY_ID)
        .single();
      if (targetRole?.role === 'admin') {
        return new Response(JSON.stringify({ error: 'Cannot erase another admin account' }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    // Step 1 — Anonymize profile PII
    const { error: profileErr } = await sb
      .from('profiles')
      .update({
        full_name: '[Deleted User]',
        phone_encrypted: null,
        family_members: null,
        avatar_storage_key: null,
        unit_id: null,
        move_out_date: new Date().toISOString().split('T')[0],
        is_active: false,
        consent_version: null,
        consent_at: null,
      })
      .eq('id', targetId)
      .eq('society_id', SOCIETY_ID);

    if (profileErr) throw Object.assign(new Error(profileErr.message), { status: 500 });

    // Step 2 — Remove from user_roles (revoke access)
    await sb.from('user_roles').delete().eq('user_id', targetId).eq('society_id', SOCIETY_ID);

    // Step 3 — Disable Supabase Auth account (prevent further logins)
    // Uses admin API to disable the auth user; non-destructive (auth record preserved for audit)
    try {
      const supabaseUrl = import.meta.env.SUPABASE_URL ?? '';
      const serviceKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
      await fetch(`${supabaseUrl}/auth/v1/admin/users/${targetId}`, {
        method: 'PUT',
        headers: { Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json', apikey: serviceKey },
        body: JSON.stringify({ ban_duration: '876000h' }), // ~100 years = permanent ban
      });
    } catch {
      // Non-fatal: profile is already anonymized; auth ban is belt-and-suspenders
    }

    // Step 4 — Audit log (DPDPA requires record of erasure event)
    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DATA_ERASURE', resourceType: 'profiles', resourceId: targetId,
      ip: extractClientIP(request),
      newValues: { reason: 'DPDPA right-to-erasure request', requested_by: user.id },
    });

    return new Response(JSON.stringify({
      ok: true,
      message: 'Personal data has been anonymized. Non-personal records (complaints, payments) are retained for society compliance.',
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
