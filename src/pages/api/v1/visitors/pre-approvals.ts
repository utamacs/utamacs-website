import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { hashPII } from '@lib/utils/encryption';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { SignJWT } from 'jose';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const QR_SECRET = new TextEncoder().encode(import.meta.env.ENCRYPTION_KEY ?? 'dev-secret');

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('visitor_pre_approvals')
      .select('id, visitor_name, purpose, expected_date, expected_time_from, expected_time_to, status, qr_token, created_at, units(unit_number)')
      .eq('society_id', SOCIETY_ID)
      .order('expected_date', { ascending: false });

    if (!['executive','admin','security_guard'].includes(user.role)) {
      query = query.eq('host_user_id', user.id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['member','executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
    }

    const body = await request.json() as {
      visitor_name?: string; visitor_phone?: string; purpose?: string;
      unit_id?: string; expected_date?: string; expected_time_from?: string; expected_time_to?: string;
    };

    if (!body.visitor_name || !body.expected_date || !body.unit_id) {
      return new Response(JSON.stringify({ error: 'visitor_name, expected_date and unit_id are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    // QR token valid for the booking window + 1 hour buffer
    const expiresAt = new Date(`${body.expected_date}T23:59:59+05:30`);
    const qrToken = await new SignJWT({ unit_id: body.unit_id, host: user.id })
      .setProtectedHeader({ alg: 'HS256' })
      .setExpirationTime(expiresAt)
      .setIssuedAt()
      .sign(QR_SECRET);

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('visitor_pre_approvals')
      .insert({
        society_id: SOCIETY_ID,
        host_unit_id: body.unit_id,
        host_user_id: user.id,
        visitor_name: sanitizePlainText(body.visitor_name),
        visitor_phone_hash: body.visitor_phone ? hashPII(body.visitor_phone) : null,
        purpose: body.purpose ? sanitizePlainText(body.purpose) : null,
        expected_date: body.expected_date,
        expected_time_from: body.expected_time_from ?? null,
        expected_time_to: body.expected_time_to ?? null,
        qr_token: qrToken,
        status: 'approved',
        expires_at: expiresAt.toISOString(),
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
