export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/members/me/permissions
// Returns the full resolved permission set for the authenticated user.
// Mobile apps fetch this once after login and cache it locally.
// Supports both Bearer header (mobile) and cookie (web).
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    return Response.json({
      id: user.id,
      role: user.role ?? 'member',
      portalRole: user.portalRole,
      isAdmin: user.isAdmin,
      committeeTitle: user.committeeTitle ?? null,
      unitId: user.unitId ?? null,
      societyId: user.societyId,
      features: Array.from(user.permissions),
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
