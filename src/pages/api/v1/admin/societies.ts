export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

// GET  /api/v1/admin/societies       — list all societies (platform admin only)
// POST /api/v1/admin/societies       — provision a new society (platform admin only)

function requirePlatformAdmin(user: { isPlatformAdmin?: boolean }) {
  if (!user.isPlatformAdmin) {
    throw Object.assign(new Error('Platform admin access required'), { status: 403 });
  }
}

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    requirePlatformAdmin(user);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('societies')
      .select('id, name, registration_no, address, city, state, pincode, total_units, total_area_acres, created_at')
      .order('created_at', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    requirePlatformAdmin(user);
    const sb = getSupabaseServiceClient();
    const body = await request.json();

    // Validate required fields
    const name = (body.name ?? '').toString().trim();
    const registrationNo = (body.registration_no ?? '').toString().trim() || null;
    const address = (body.address ?? '').toString().trim() || null;
    const city = (body.city ?? '').toString().trim() || null;
    const state = (body.state ?? 'Telangana').toString().trim();
    const pincode = (body.pincode ?? '').toString().trim() || null;
    const totalUnits = Number.isFinite(Number(body.total_units)) ? Number(body.total_units) : null;

    if (!name || name.length < 3) {
      return Response.json({ error: 'VALIDATION', message: 'Society name is required (min 3 chars)' }, { status: 400 });
    }

    // 1. Create the society
    const { data: society, error: societyErr } = await sb
      .from('societies')
      .insert({ name, registration_no: registrationNo, address, city, state, pincode, total_units: totalUnits })
      .select('id, name')
      .single();

    if (societyErr || !society) {
      throw Object.assign(new Error(societyErr?.message ?? 'Insert failed'), { status: 500 });
    }

    const newSocietyId = society.id;

    // 2. Seed feature flags by copying the standard set from the seed society
    // We insert the same module_keys that exist for the seed society (00000000-...)
    const SEED_SOCIETY_ID = '00000000-0000-0000-0000-000000000001';
    const { data: seedFlags } = await sb
      .from('feature_flags')
      .select('module_key, feature_key, is_enabled, allowed_roles, config_json')
      .eq('society_id', SEED_SOCIETY_ID);

    if (seedFlags && seedFlags.length > 0) {
      const flagRows = seedFlags.map((f) => ({
        society_id: newSocietyId,
        module_key: f.module_key,
        feature_key: f.feature_key,
        is_enabled: f.is_enabled,
        allowed_roles: f.allowed_roles,
        config_json: f.config_json,
      }));
      await sb.from('feature_flags').insert(flagRows);
    }

    // 3. Seed rules by copying the standard set from the seed society
    const { data: seedRules } = await sb
      .from('rules')
      .select('rule_category, rule_code, label, description, value_type, current_value, default_value, byelaw_reference, is_locked')
      .eq('society_id', SEED_SOCIETY_ID);

    if (seedRules && seedRules.length > 0) {
      const ruleRows = seedRules.map((r) => ({
        society_id: newSocietyId,
        rule_category: r.rule_category,
        rule_code: r.rule_code,
        label: r.label,
        description: r.description,
        value_type: r.value_type,
        current_value: r.current_value,
        default_value: r.default_value,
        byelaw_reference: r.byelaw_reference,
        is_locked: r.is_locked,
      }));
      await sb.from('rules').insert(ruleRows);
    }

    await writeAuditLog({
      userId: user.id,
      societyId: newSocietyId,
      action: 'CREATE',
      resourceType: 'society',
      resourceId: newSocietyId,
      newValues: { name, registration_no: registrationNo },
      ipAddress: extractClientIP(request),
    });

    return Response.json({
      id: newSocietyId,
      name: society.name,
      flagsSeeded: seedFlags?.length ?? 0,
      rulesSeeded: seedRules?.length ?? 0,
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH /api/v1/admin/societies/:id  — invite initial admin user for a society
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    requirePlatformAdmin(user);
    const sb = getSupabaseServiceClient();
    const body = await request.json();

    const societyId = (body.society_id ?? '').toString().trim();
    const adminEmail = (body.admin_email ?? '').toString().trim().toLowerCase();

    if (!UUID_RE.test(societyId)) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid society_id' }, { status: 400 });
    }
    if (!adminEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid admin_email is required' }, { status: 400 });
    }

    // Verify society exists
    const { data: society } = await sb.from('societies').select('id, name').eq('id', societyId).single();
    if (!society) {
      return Response.json({ error: 'NOT_FOUND', message: 'Society not found' }, { status: 404 });
    }

    // Invite the user via Supabase Auth (sends magic link / invite email)
    const { data: inviteData, error: inviteErr } = await sb.auth.admin.inviteUserByEmail(adminEmail, {
      data: { society_id: societyId, role: 'admin' },
      redirectTo: `${import.meta.env.PUBLIC_PORTAL_URL ?? 'https://portal.utamacs.org'}/portal/login`,
    });

    if (inviteErr || !inviteData.user) {
      throw Object.assign(new Error(inviteErr?.message ?? 'Invite failed'), { status: 500 });
    }

    await writeAuditLog({
      userId: user.id,
      societyId,
      action: 'INVITE',
      resourceType: 'society_admin',
      resourceId: inviteData.user.id,
      newValues: { email: adminEmail, society_id: societyId },
      ipAddress: extractClientIP(request),
    });

    return Response.json({ message: `Invite sent to ${adminEmail}`, userId: inviteData.user.id });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
