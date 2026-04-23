export const prerender = false;
import type { APIRoute } from 'astro';
import { authService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const { email, password } = body as { email?: string; password?: string };

    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Email and password are required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const session = await authService.signIn(email, password);

    await writeAuditLog({
      userId: session.user.id,
      societyId: session.user.societyId,
      action: 'LOGIN',
      resourceType: 'auth',
      ip: extractClientIP(request),
      userAgent: request.headers.get('user-agent') ?? undefined,
    });

    const cookieOptions = [
      `sb-access-token=${session.accessToken}`,
      'Path=/',
      'HttpOnly',
      'Secure',
      'SameSite=Strict',
      `Max-Age=${15 * 60}`,
    ].join('; ');

    const refreshCookieOptions = [
      `sb-refresh-token=${session.refreshToken}`,
      'Path=/api/v1/auth/refresh',
      'HttpOnly',
      'Secure',
      'SameSite=Strict',
      `Max-Age=${7 * 24 * 60 * 60}`,
    ].join('; ');

    return new Response(
      JSON.stringify({
        user: session.user,
        expiresAt: session.expiresAt,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Set-Cookie': cookieOptions,
          'Set-Cookie2': refreshCookieOptions,
        },
      },
    );
  } catch (err) {
    console.error('[login] error:', err instanceof Error ? err.message : err);
    return normalizeError(err, request.url);
  }
};
