export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/** GET /api/v1/polls/:id/results — returns per-option vote counts after voting or poll close. */
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);

    const pollId = params.id ?? '';
    if (!UUID_RE.test(pollId)) {
      return new Response(JSON.stringify({ error: 'Invalid poll id' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: poll, error: pollErr } = await sb
      .from('polls')
      .select('id, ends_at, result_visibility, poll_options(id, option_text, order_index)')
      .eq('id', pollId)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (pollErr || !poll) {
      return new Response(JSON.stringify({ error: 'Poll not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data: userVote } = await sb
      .from('poll_votes')
      .select('option_id')
      .eq('poll_id', pollId)
      .eq('user_id', user.id)
      .maybeSingle();

    const isClosed = poll.ends_at && new Date(poll.ends_at) < new Date();
    const visibility = (poll as any).result_visibility ?? 'after_vote';

    // Enforce result_visibility:
    //   always      → always show results
    //   after_vote  → show only after user has voted
    //   after_close → show only after poll is closed
    const canSeeResults =
      visibility === 'always' ||
      (visibility === 'after_vote' && !!userVote) ||
      (visibility === 'after_close' && isClosed);

    if (!canSeeResults) {
      const reason =
        visibility === 'after_close'
          ? 'Results will be visible after the poll closes.'
          : 'Cast your vote to see the results.';
      return new Response(JSON.stringify({ has_voted: !!userVote, results_available: false, voted_option_id: null, reason }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data: votes } = await sb
      .from('poll_votes')
      .select('option_id')
      .eq('poll_id', pollId);

    const totals: Record<string, number> = {};
    for (const v of votes ?? []) {
      totals[v.option_id] = (totals[v.option_id] ?? 0) + 1;
    }
    const totalVotes = (votes ?? []).length;

    const options = (poll.poll_options as any[])
      .sort((a, b) => a.order_index - b.order_index)
      .map((opt: any) => ({
        id: opt.id,
        option_text: opt.option_text,
        vote_count: totals[opt.id] ?? 0,
        percentage: totalVotes > 0 ? Math.round(((totals[opt.id] ?? 0) / totalVotes) * 100) : 0,
      }));

    return new Response(JSON.stringify({
      has_voted: !!userVote,
      voted_option_id: userVote?.option_id ?? null,
      results_available: true,
      total_votes: totalVotes,
      options,
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
