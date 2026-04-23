export const prerender = false;
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
      .from('polls')
      .select('id, title, description, poll_type, is_anonymous, one_vote_per_unit, starts_at, ends_at, is_published, result_visibility, created_at, poll_options(id, option_text, order_index)')
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
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
      'polls', 'create',
    );

    const body = await request.json() as Record<string, unknown>;
    const { title, description, poll_type, options, is_anonymous, one_vote_per_unit, starts_at, ends_at } = body;

    if (!title || !poll_type || !Array.isArray(options) || options.length < 2) {
      return new Response(JSON.stringify({ error: 'title, poll_type and at least 2 options are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data: poll, error } = await sb
      .from('polls')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(String(title)),
        description: description ? sanitizePlainText(String(description)) : null,
        poll_type,
        is_anonymous: is_anonymous ?? false,
        one_vote_per_unit: one_vote_per_unit ?? false,
        starts_at: starts_at ?? new Date().toISOString(),
        ends_at: ends_at ?? null,
        is_published: false,
        result_visibility: 'after_close',
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const optionRows = (options as string[]).map((text: string, i: number) => ({
      poll_id: poll.id,
      option_text: sanitizePlainText(text),
      order_index: i + 1,
    }));
    await sb.from('poll_options').insert(optionRows);

    return new Response(JSON.stringify(poll), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
