import { authService } from '../services/index';
import type { UserClaims } from '../services/interfaces/IAuthService';

export async function validateJWT(request: Request): Promise<UserClaims> {
  // Prefer Authorization: Bearer header (API clients)
  const authHeader = request.headers.get('Authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    return authService.validateToken(token);
  }

  // Fall back to HttpOnly cookie (browser-side React island fetch calls)
  const cookieHeader = request.headers.get('Cookie') ?? '';
  const match = cookieHeader.match(/sb-access-token=([^;]+)/);
  if (match?.[1]) {
    return authService.validateToken(match[1]);
  }

  throw Object.assign(new Error('Missing or malformed Authorization header'), { status: 401 });
}

export function extractBearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  return header.slice(7);
}
