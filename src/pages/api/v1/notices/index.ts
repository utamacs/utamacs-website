import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizeHTML, sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('notices')
      .select('id, title, body, category, target_audience, is_pinned, requires_acknowledgement, published_at, expires_at, created_at')
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .order('is_pinned', { ascending: false })
      .order('created_at', { ascending: false });

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
      'notices', 'create',
    );

    const body = await request.json() as Record<string, unknown>;
    const { title, body: noticeBody, category, target_audience, is_pinned, requires_acknowledgement } = body;

    if (!title || !category) {
      return new Response(JSON.stringify({ error: 'title and category are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('notices')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(String(title)),
        body: noticeBody ? sanitizeHTML(String(noticeBody)) : null,
        category,
        target_audience: target_audience ?? 'all',
        is_pinned: is_pinned ?? false,
        requires_acknowledgement: requires_acknowledgement ?? false,
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
