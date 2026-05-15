export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as Record<string, unknown>;
    const name         = sanitizePlainText(String(body.applicant_name ?? '')).trim();
    const email        = String(body.applicant_email ?? '').trim().toLowerCase();
    const phone        = String(body.applicant_phone ?? '').trim();
    const relationship = String(body.relationship ?? '').trim();
    const unit         = sanitizePlainText(String(body.unit_number ?? '')).trim();

    if (!name || !email || !phone) {
      return Response.json({ error: 'VALIDATION', message: 'name, email, phone are required' }, { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid email address' }, { status: 400 });
    }
    if (!/^[6-9]\d{9}$/.test(phone)) {
      return Response.json({ error: 'VALIDATION', message: 'Phone must be a valid 10-digit Indian mobile number' }, { status: 400 });
    }

    const VALID_RELATIONSHIPS = ['Spouse', 'Parent', 'Child', 'Sibling', 'Other'];
    if (relationship && !VALID_RELATIONSHIPS.includes(relationship)) {
      return Response.json({ error: 'VALIDATION', message: `relationship must be one of: ${VALID_RELATIONSHIPS.join(', ')}` }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Get unit from the requesting member's profile if not supplied
    let resolvedUnit = unit;
    if (!resolvedUnit) {
      const { data: profile } = await sb
        .from('profiles')
        .select('units(unit_number)')
        .eq('id', user.id)
        .single();
      resolvedUnit = (profile as any)?.units?.unit_number ?? '';
    }

    if (!resolvedUnit) {
      return Response.json({ error: 'VALIDATION', message: 'Could not determine unit for this member' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('onboarding_requests')
      .insert({
        society_id:      SOCIETY_ID,
        request_type:    'secondary_user',
        status:          'pending',
        applicant_name:  name,
        applicant_email: email,
        applicant_phone: phone,
        unit_number:     resolvedUnit,
        primary_user_id: user.id,
        relationship:    relationship || null,
        secondary_phone: phone,
      })
      .select('id')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ id: data.id, status: 'pending' }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
