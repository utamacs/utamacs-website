import { authService } from '../services/index';
import type { UserClaims } from '../services/interfaces/IAuthService';

export async function validateJWT(request: Request): Promise<UserClaims> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw Object.assign(new Error('Missing or malformed Authorization header'), { status: 401 });
  }
  const token = authHeader.slice(7);
  return authService.validateToken(token);
}

export function extractBearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  return header.slice(7);
}
