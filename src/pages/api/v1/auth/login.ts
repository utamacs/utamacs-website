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

    // Write Set-Cookie directly onto the raw Response using .append() so both
    // headers are preserved as separate lines. Never use new Headers({...}) or
    // Object.fromEntries() — plain objects collapse duplicate keys and only the
    // last Set-Cookie survives.
    const setCookie = (name: string, value: string, maxAge: number, path: string) =>
      `${name}=${encodeURIComponent(value)}; Path=${path}; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;

    if (isForm) {
      const r = new Response(null, {
        status: 303,
        headers: { Location: next, 'Cache-Control': 'no-store' },
      });
      r.headers.append('Set-Cookie', setCookie('sb-access-token', session.accessToken, 15 * 60, '/'));
      r.headers.append('Set-Cookie', setCookie('sb-refresh-token', session.refreshToken, 7 * 24 * 60 * 60, '/api/v1/auth/refresh'));
      return r;
    }

    const r = new Response(
      JSON.stringify({ user: session.user, expiresAt: session.expiresAt }),
      { status: 200, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } },
    );
    r.headers.append('Set-Cookie', setCookie('sb-access-token', session.accessToken, 15 * 60, '/'));
    r.headers.append('Set-Cookie', setCookie('sb-refresh-token', session.refreshToken, 7 * 24 * 60 * 60, '/api/v1/auth/refresh'));
    return r;
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
