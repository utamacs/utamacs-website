import type { APIRoute } from 'astro';
import { authService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';

export const POST: APIRoute = async ({ request }) => {
  try {
    const cookieHeader = request.headers.get('Cookie') ?? '';
    const match = cookieHeader.match(/sb-refresh-token=([^;]+)/);
    const refreshToken = match?.[1];

    if (!refreshToken) {
      return new Response(JSON.stringify({ error: 'No refresh token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const session = await authService.refreshToken(refreshToken);

    const cookieOptions = [
      `sb-access-token=${session.accessToken}`,
      'Path=/',
      'HttpOnly',
      'Secure',
      'SameSite=Strict',
      `Max-Age=${15 * 60}`,
    ].join('; ');

    return new Response(
      JSON.stringify({ user: session.user, expiresAt: session.expiresAt }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Set-Cookie': cookieOptions,
        },
      },
    );
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
