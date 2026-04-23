import type { APIRoute } from 'astro';
import { authService } from '@lib/services/index';
import { extractClientIP, writeAuditLog } from '@lib/middleware/auditLogger';
import { extractBearerToken } from '@lib/middleware/jwtValidator';

export const POST: APIRoute = async ({ request, redirect }) => {
  const token = extractBearerToken(request);
  if (token) {
    try {
      const user = await authService.validateToken(token);
      await writeAuditLog({
        userId: user.id,
        societyId: user.societyId,
        action: 'LOGOUT',
        resourceType: 'auth',
        ip: extractClientIP(request),
      });
      await authService.signOut(token);
    } catch {
      // still clear cookies on any error
    }
  }

  const clearCookie = 'sb-access-token=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0';
  const clearRefresh = 'sb-refresh-token=; Path=/api/v1/auth/refresh; HttpOnly; Secure; SameSite=Strict; Max-Age=0';

  return new Response(null, {
    status: 302,
    headers: {
      Location: '/portal/login',
      'Set-Cookie': clearCookie,
      'Set-Cookie2': clearRefresh,
    },
  });
};
