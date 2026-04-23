import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('events')
      .select('id, title, description, category, starts_at, ends_at, location, capacity, is_paid, ticket_price, is_published, created_at')
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .order('starts_at', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'events', 'create',
    );

    const body = await request.json() as Record<string, unknown>;
    const { title, description, category, starts_at, ends_at, location, capacity } = body;

    if (!title || !starts_at || !ends_at) {
      return new Response(JSON.stringify({ error: 'title, starts_at and ends_at are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('events')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(String(title)),
        description: description ? sanitizePlainText(String(description)) : null,
        category: category ?? 'General',
        starts_at,
        ends_at,
        location: location ?? null,
        capacity: capacity ?? null,
        is_published: false,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
