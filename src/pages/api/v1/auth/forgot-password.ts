import type { APIRoute } from 'astro';
import { authService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { checkRateLimit } from '@lib/middleware/rateLimiter';
import { extractClientIP } from '@lib/middleware/auditLogger';

export const POST: APIRoute = async ({ request }) => {
  try {
    checkRateLimit(extractClientIP(request), '/api/v1/auth/forgot-password');

    const body = await request.json() as { email?: string };
    if (!body.email?.trim()) {
      return new Response(JSON.stringify({ error: 'email is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Always returns 200 — never reveal whether the email exists (prevents enumeration)
    await authService.sendPasswordReset(body.email.trim()).catch(() => undefined);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
