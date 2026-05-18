export const prerender = false;
import type { APIRoute } from 'astro';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function setCookieHeader(name: string, value: string, maxAge: number, path: string): string {
  return `${name}=${encodeURIComponent(value)}; Path=${path}; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json() as { email?: string; token?: string };
    const email = body.email?.trim().toLowerCase() ?? '';
    const token = body.token?.trim() ?? '';

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: 'VALIDATION', message: 'Enter a valid email address.' }, { status: 400 });
    }
    if (!/^[0-9]{8}$/.test(token)) {
      return Response.json({ error: 'VALIDATION', message: 'Sign-in code must be 8 digits.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb.auth.verifyOtp({
      email,
      token,
      type: 'email',
    });

    if (error || !data.session) {
      return Response.json({ error: 'INVALID_OTP', message: 'Invalid or expired OTP. Please try again.' }, { status: 401 });
    }

    const { session } = data;

    await writeAuditLog({
      userId: session.user.id,
      societyId: SOCIETY_ID,
      action: 'LOGIN',
      resourceType: 'auth',
      ip: extractClientIP(request),
      userAgent: request.headers.get('user-agent') ?? undefined,
    });

    const r = Response.json({ next: '/portal' }, { status: 200, headers: { 'Cache-Control': 'no-store' } });
    r.headers.append('Set-Cookie', setCookieHeader('sb-access-token',  session.access_token,  15 * 60,             '/'));
    r.headers.append('Set-Cookie', setCookieHeader('sb-refresh-token', session.refresh_token, 7 * 24 * 60 * 60,    '/api/v1/auth/refresh'));
    return r;
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
