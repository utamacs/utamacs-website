export const prerender = false;
import type { APIRoute } from 'astro';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json() as { email?: string };
    const email = body.email?.trim().toLowerCase() ?? '';

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: 'VALIDATION', message: 'Enter a valid email address.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { error } = await sb.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false },
    });

    if (error) {
      console.error('[send-otp]', error.message);
      return Response.json({ error: 'OTP_SEND_FAILED', message: 'Could not send sign-in code. Make sure your email is registered.' }, { status: 502 });
    }

    return Response.json({ sent: true }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
