export const prerender = false;
import type { APIRoute } from 'astro';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json() as { phone?: string };
    const phone = body.phone?.trim() ?? '';

    if (!/^[6-9][0-9]{9}$/.test(phone)) {
      return Response.json({ error: 'VALIDATION', message: 'Enter a valid 10-digit Indian mobile number.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { error } = await sb.auth.signInWithOtp({
      phone: `+91${phone}`,
      options: { channel: 'sms' },
    });

    if (error) {
      console.error('[send-otp]', error.message);
      return Response.json({ error: 'OTP_SEND_FAILED', message: 'Could not send OTP. Please try again.' }, { status: 502 });
    }

    return Response.json({ sent: true }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
