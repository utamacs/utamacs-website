export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_OCCUPANCY = ['owner', 'tenant', 'co_owner', 'family'] as const;
const VALID_ID_TYPES   = ['aadhaar', 'voter_id', 'passport', 'dl', 'other'] as const;

// UUID regex
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Public POST — no auth required (open self-registration)
export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json() as Record<string, unknown>;

    // Required fields
    const full_name = sanitizePlainText(String(body.full_name ?? '')).trim();
    if (full_name.length < 2 || full_name.length > 100) {
      return Response.json({ error: 'VALIDATION', message: 'Full name must be 2–100 characters' }, { status: 400 });
    }

    const email = String(body.email ?? '').toLowerCase().trim();
    if (!email || email.length > 254 || !email.includes('@')) {
      return Response.json({ error: 'VALIDATION', message: 'Valid email is required' }, { status: 400 });
    }

    const occupancy_type = String(body.occupancy_type ?? 'owner');
    if (!VALID_OCCUPANCY.includes(occupancy_type as typeof VALID_OCCUPANCY[number])) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid occupancy type' }, { status: 400 });
    }

    const phone = sanitizePlainText(String(body.phone ?? '')).trim().slice(0, 15) || null;

    const unit_id = body.unit_id ? String(body.unit_id) : null;
    if (unit_id && !UUID_RE.test(unit_id)) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid unit_id' }, { status: 400 });
    }

    const id_type = body.id_type ? String(body.id_type) : null;
    if (id_type && !VALID_ID_TYPES.includes(id_type as typeof VALID_ID_TYPES[number])) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid id_type' }, { status: 400 });
    }

    const id_number    = body.id_number    ? sanitizePlainText(String(body.id_number)).trim().slice(0, 30) : null;
    const vehicle_reg_no = body.vehicle_reg_no ? sanitizePlainText(String(body.vehicle_reg_no)).trim().slice(0, 20) : null;
    const vehicle_make   = body.vehicle_make   ? sanitizePlainText(String(body.vehicle_make)).trim().slice(0, 50) : null;
    const move_in_date   = body.move_in_date   ? String(body.move_in_date) : null;

    const sb = getSupabaseServiceClient();

    // Duplicate check: same email + society in pending/approved state
    const { data: existing } = await sb
      .from('registration_requests')
      .select('id, status')
      .eq('society_id', SOCIETY_ID)
      .eq('email', email)
      .in('status', ['pending', 'approved'])
      .limit(1)
      .maybeSingle();

    if (existing) {
      return Response.json(
        { error: 'DUPLICATE', message: 'A registration request for this email is already pending or approved.' },
        { status: 409 }
      );
    }

    const { data, error } = await sb
      .from('registration_requests')
      .insert({
        society_id: SOCIETY_ID,
        full_name, email, phone,
        unit_id, occupancy_type,
        id_type, id_number,
        vehicle_reg_no, vehicle_make,
        move_in_date,
        status: 'pending',
      })
      .select('id, status, created_at')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ id: data.id, status: data.status }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
