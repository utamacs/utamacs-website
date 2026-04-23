import { defineMiddleware } from 'astro:middleware';
import { authService } from './lib/services/index';
import { applySecurityHeaders } from './lib/middleware/securityHeaders';
import { checkRateLimit } from './lib/middleware/rateLimiter';
import { extractClientIP } from './lib/middleware/auditLogger';

const PUBLIC_PORTAL_PATHS = ['/portal/login', '/portal/forgot-password'];
const PORTAL_PREFIX = '/portal';
const API_PREFIX = '/api/v1';

export const onRequest = defineMiddleware(async (context, next) => {
  const { request, redirect, locals } = context;
  const url = new URL(request.url);
  const path = url.pathname;

  // Apply security headers to all responses
  const response = await next();
  applySecurityHeaders(response.headers);

  // Rate-limit all API routes
  if (path.startsWith(API_PREFIX)) {
    const ip = extractClientIP(request);
    try {
      checkRateLimit(ip, path);
    } catch (err: unknown) {
      const e = err as { status?: number; retryAfter?: number; message?: string };
      return new Response(JSON.stringify({ error: e.message }), {
        status: e.status ?? 429,
        headers: {
          'Content-Type': 'application/json',
          'Retry-After': String(e.retryAfter ?? 60),
        },
      });
    }
  }

  // Guard /portal/* pages (not API routes — those handle auth themselves)
  if (path.startsWith(PORTAL_PREFIX) && !path.startsWith(API_PREFIX)) {
    if (PUBLIC_PORTAL_PATHS.includes(path)) return response;

    const cookieHeader = request.headers.get('Cookie') ?? '';
    const tokenMatch = cookieHeader.match(/sb-access-token=([^;]+)/);
    const accessToken = tokenMatch?.[1];

    if (!accessToken) {
      return redirect(`/portal/login?next=${encodeURIComponent(path)}`);
    }

    try {
      const user = await authService.validateToken(accessToken);
      (locals as Record<string, unknown>)['user'] = user;
    } catch {
      return redirect(`/portal/login?next=${encodeURIComponent(path)}&expired=1`);
    }
  }

  return response;
});
