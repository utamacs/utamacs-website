export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as { option_id?: string };

    if (!body.option_id) {
      return new Response(JSON.stringify({ error: 'option_id is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify poll is active and published
    const { data: poll, error: pollErr } = await sb
      .from('polls')
      .select('id, is_published, ends_at, one_vote_per_unit, is_anonymous')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pollErr || !poll?.is_published) {
      return new Response(JSON.stringify({ error: 'Poll not found or not active' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }

    if (poll.ends_at && new Date(poll.ends_at) < new Date()) {
      return new Response(JSON.stringify({ error: 'Poll has ended' }), { status: 409, headers: { 'Content-Type': 'application/json' } });
    }

    // Check if already voted (user_id is always stored, anonymity is at API response layer)
    const { data: existing } = await sb
      .from('poll_votes')
      .select('id')
      .eq('poll_id', params.id!)
      .eq('user_id', user.id)
      .single();

    if (existing) {
      return new Response(JSON.stringify({ error: 'You have already voted in this poll' }), { status: 409, headers: { 'Content-Type': 'application/json' } });
    }

    const { data, error } = await sb
      .from('poll_votes')
      .insert({ poll_id: params.id, option_id: body.option_id, user_id: user.id })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ success: true, vote_id: data.id }), {
      status: 201, headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
