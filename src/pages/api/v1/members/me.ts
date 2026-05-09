export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_LANGUAGES = ['en', 'te', 'hi'] as const;

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('profiles')
      .select(`id, full_name, residency_type, move_in_date, is_active,
               avatar_key, bio, preferred_language,
               emergency_name, emergency_phone, emergency_relation,
               vehicle_reg_no, vehicle_make, vehicle_model,
               whatsapp_number, consent_version, consent_at, updated_at,
               units(unit_number, block, floor, area_sqft)`)
      .eq('id', user.id)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    let avatar_url: string | null = null;
    if ((data as any).avatar_key) {
      try {
        avatar_url = await getDocumentDownloadUrl((data as any).avatar_key);
      } catch { /* non-fatal */ }
    }

    return Response.json({ ...data, avatar_url });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as Record<string, unknown>;
    const updates: Record<string, unknown> = {};

    if (typeof body.full_name === 'string') {
      const name = sanitizePlainText(body.full_name).trim();
      if (name.length < 2 || name.length > 100) return Response.json({ error: 'VALIDATION', message: 'Name must be 2–100 characters' }, { status: 400 });
      updates.full_name = name;
    }
    if (typeof body.bio === 'string') {
      const bio = sanitizePlainText(body.bio).trim();
      if (bio.length > 500) return Response.json({ error: 'VALIDATION', message: 'Bio must be ≤500 characters' }, { status: 400 });
      updates.bio = bio || null;
    }
    if (typeof body.preferred_language === 'string') {
      if (!VALID_LANGUAGES.includes(body.preferred_language as typeof VALID_LANGUAGES[number])) {
        return Response.json({ error: 'VALIDATION', message: 'Invalid language' }, { status: 400 });
      }
      updates.preferred_language = body.preferred_language;
    }
    if (typeof body.emergency_name === 'string') {
      updates.emergency_name = sanitizePlainText(body.emergency_name).trim().slice(0, 100) || null;
    }
    if (typeof body.emergency_phone === 'string') {
      updates.emergency_phone = sanitizePlainText(body.emergency_phone).trim().slice(0, 15) || null;
    }
    if (typeof body.emergency_relation === 'string') {
      updates.emergency_relation = sanitizePlainText(body.emergency_relation).trim().slice(0, 50) || null;
    }
    if (typeof body.vehicle_reg_no === 'string') {
      updates.vehicle_reg_no = sanitizePlainText(body.vehicle_reg_no).trim().slice(0, 20) || null;
    }
    if (typeof body.vehicle_make === 'string') {
      updates.vehicle_make = sanitizePlainText(body.vehicle_make).trim().slice(0, 50) || null;
    }
    if (typeof body.vehicle_model === 'string') {
      updates.vehicle_model = sanitizePlainText(body.vehicle_model).trim().slice(0, 50) || null;
    }
    if (typeof body.whatsapp_number === 'string') {
      updates.whatsapp_number = sanitizePlainText(body.whatsapp_number).trim().slice(0, 15) || null;
    }
    if (typeof body.residency_type === 'string') {
      updates.residency_type = body.residency_type;
    }

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION', message: 'No valid fields provided' }, { status: 400 });
    }

    updates.updated_at = new Date().toISOString();

    const sb = getSupabaseServiceClient();

    const { data: before } = await sb.from('profiles').select('full_name, bio, preferred_language').eq('id', user.id).single();

    const { data, error } = await sb
      .from('profiles')
      .update(updates)
      .eq('id', user.id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'UPDATE', resourceType: 'profile', resourceId: user.id,
      ip: extractClientIP(request),
      oldValues: before ?? undefined, newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// Keep backward-compatible PUT as alias for PATCH
export const PUT = PATCH;
