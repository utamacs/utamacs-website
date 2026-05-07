export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ALLOWED_RELATIONSHIPS = ['Spouse','Parent','Child','Sibling','Friend','Other'] as const;

// PATCH — update own profile fields (emergency contact, num_occupants, nri_flag)
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as Record<string, unknown>;
    const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };

    // Emergency contact — all three fields optional; null clears them
    if ('emergency_contact_name' in body) {
      const v = body.emergency_contact_name;
      if (v !== null && (typeof v !== 'string' || v.length > 100))
        return Response.json({ error: 'VALIDATION_ERROR', message: 'emergency_contact_name must be ≤ 100 chars' }, { status: 400 });
      updates.emergency_contact_name = v ? String(v).trim() : null;
    }
    if ('emergency_contact_phone' in body) {
      const v = body.emergency_contact_phone;
      if (v !== null && (typeof v !== 'string' || v.length > 20))
        return Response.json({ error: 'VALIDATION_ERROR', message: 'emergency_contact_phone must be ≤ 20 chars' }, { status: 400 });
      updates.emergency_contact_phone = v ? String(v).trim() : null;
    }
    if ('emergency_contact_rel' in body) {
      const v = body.emergency_contact_rel;
      if (v !== null && !ALLOWED_RELATIONSHIPS.includes(v as never))
        return Response.json({ error: 'VALIDATION_ERROR', message: `emergency_contact_rel must be one of: ${ALLOWED_RELATIONSHIPS.join(', ')}` }, { status: 400 });
      updates.emergency_contact_rel = v ?? null;
    }

    if ('num_occupants' in body) {
      const v = Number(body.num_occupants);
      if (!Number.isInteger(v) || v < 0 || v > 50)
        return Response.json({ error: 'VALIDATION_ERROR', message: 'num_occupants must be 0–50' }, { status: 400 });
      updates.num_occupants = v;
    }

    if (Object.keys(updates).length === 1) // only updated_at
      return Response.json({ error: 'VALIDATION_ERROR', message: 'No valid fields to update' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('profiles')
      .update(updates)
      .eq('id', user.id)
      .eq('society_id', SOCIETY_ID)
      .select('emergency_contact_name, emergency_contact_phone, emergency_contact_rel, num_occupants')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'profiles', resourceId: user.id,
      ip: extractClientIP(request),
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
