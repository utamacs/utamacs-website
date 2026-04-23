import { defineMiddleware } from 'astro:middleware';
import { authService } from './lib/services/index';
import { applySecurityHeaders } from './lib/middleware/securityHeaders';
import { checkRateLimit } from './lib/middleware/rateLimiter';
import { extractClientIP } from './lib/middleware/auditLogger';

const PUBLIC_PORTAL_PATHS = ['/portal/login', '/portal/forgot-password'];
const PORTAL_PREFIX = '/portal';
const API_PREFIX = '/api/v1';

export const onRequest = defineMiddleware(async (context, next) => {
  const { request, redirect, locals, cookies } = context;
  const url = new URL(request.url);
  const path = url.pathname;

  // 1. Rate-limit API routes before processing
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

  // 2. Guard /portal/* pages before calling next() so locals.user is set at render time
  if (path.startsWith(PORTAL_PREFIX) && !path.startsWith(API_PREFIX)) {
    if (!PUBLIC_PORTAL_PATHS.includes(path)) {
      // Use Astro's cookies API — reads the incoming Cookie header correctly
      const accessToken = cookies.get('sb-access-token')?.value;
      console.log('[middleware] path:', path, '| has token:', !!accessToken);

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

  // 3. Process the request
  const response = await next();

  // 4. Apply security headers to all responses
  applySecurityHeaders(response.headers);

  return response;
});
