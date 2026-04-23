export const prerender = false;
import type { APIRoute } from 'astro';
import { authService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

function safeRedirect(next: string | null): string {
  if (!next) return '/portal';
  try {
    const url = new URL(next, 'https://example.com');
    return url.pathname + url.search;
  } catch {
    return '/portal';
  }
}

export const POST: APIRoute = async (context) => {
  const { request, cookies } = context;
  const contentType = request.headers.get('content-type') ?? '';
  const isForm = contentType.includes('application/x-www-form-urlencoded');

  try {
    let email: string | undefined;
    let password: string | undefined;
    let next = '/portal';

    if (isForm) {
      const data = await request.formData();
      email = data.get('email')?.toString();
      password = data.get('password')?.toString();
      next = safeRedirect(data.get('next')?.toString() ?? null);
    } else {
      const body = await request.json() as { email?: string; password?: string };
      email = body.email;
      password = body.password;
    }

    if (!email || !password) {
      if (isForm) {
        return new Response(null, { status: 302, headers: { Location: '/portal/login?error=required' } });
      }
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

    // Use Astro's native cookies API — the Vercel adapter serialises these
    // directly into the outgoing HTTP response, bypassing any edge-level
    // header reconstruction that strips Set-Cookie.
    cookies.set('sb-access-token', session.accessToken, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: 15 * 60,
    });

    cookies.set('sb-refresh-token', session.refreshToken, {
      path: '/api/v1/auth/refresh',
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: 7 * 24 * 60 * 60,
    });

    if (isForm) {
      return new Response(null, {
        status: 302,
        headers: { Location: next, 'Cache-Control': 'no-store' },
      });
    }

    return new Response(
      JSON.stringify({ user: session.user, expiresAt: session.expiresAt }),
      { status: 200, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } },
    );
  } catch (err) {
    console.error('[login] error:', err instanceof Error ? err.message : err);
    if (isForm) {
      return new Response(null, {
        status: 302,
        headers: { Location: '/portal/login?error=invalid_credentials' },
      });
    }
    return normalizeError(err, request.url);
  }
};
