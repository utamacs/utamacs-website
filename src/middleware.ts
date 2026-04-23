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

  // 1. Rate-limit API routes before processing (saves compute on rejected requests)
  if (path.startsWith(API_PREFIX)) {
    const ip = extractClientIP(request);
    try {
      await checkRateLimit(ip, path);
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

  // 2. Guard /portal/* pages before calling next() so locals.user is set when the page renders
  if (path.startsWith(PORTAL_PREFIX) && !path.startsWith(API_PREFIX)) {
    if (!PUBLIC_PORTAL_PATHS.includes(path)) {
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
  }

  // 3. Process the request (locals.user is now available to portal pages)
  const response = await next();

  // 4. Apply security headers to all responses
  applySecurityHeaders(response.headers);

  return response;
});
