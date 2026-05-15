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
      .select('id, ends_at, result_visibility, poll_type, poll_options(id, option_text, order_index)')
      .eq('id', pollId)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (pollErr || !poll) {
      return new Response(JSON.stringify({ error: 'Poll not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data: userVoteRows } = await sb
      .from('poll_votes')
      .select('option_id')
      .eq('poll_id', pollId)
      .eq('user_id', user.id);
    const userVotedOptionIds = (userVoteRows ?? []).map((v: any) => v.option_id);
    const userVote = userVoteRows && userVoteRows.length > 0 ? userVoteRows[0] : null;

    const isClosed = poll.ends_at && new Date(poll.ends_at) < new Date();
    const visibility = (poll as any).result_visibility ?? 'after_vote';
    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;

    // Enforce result_visibility:
    //   always      → always show results
    //   after_vote  → show only after user has voted
    //   after_close → show only after poll is closed
    // Exec/admin bypass: always see live results regardless of setting
    const canSeeResults =
      isPrivileged ||
      visibility === 'always' ||
      (visibility === 'after_vote' && !!userVote) ||
      (visibility === 'after_close' && isClosed);

    if (!canSeeResults) {
      const reason =
        visibility === 'after_close'
          ? 'Results will be visible after the poll closes.'
          : 'Cast your vote to see the results.';
      return new Response(JSON.stringify({
        has_voted: !!userVote,
        results_available: false,
        voted_option_id: userVote?.option_id ?? null,
        voted_option_ids: userVotedOptionIds,
        reason,
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    const { data: votes } = await sb
      .from('poll_votes')
      .select('option_id, user_id')
      .eq('poll_id', pollId);

    const totals: Record<string, number> = {};
    const uniqueVoters = new Set<string>();
    for (const v of votes ?? []) {
      totals[(v as any).option_id] = (totals[(v as any).option_id] ?? 0) + 1;
      uniqueVoters.add((v as any).user_id);
    }

    // total_votes = unique voters (not total ballot rows) for multi-choice fairness
    const totalUniqueVoters = uniqueVoters.size;
    const totalVoteRows = (votes ?? []).length;

    const pollType: string = (poll as any).poll_type ?? 'single_choice';
    const isRating = pollType === 'rating';

    const options = (poll.poll_options as any[])
      .sort((a, b) => a.order_index - b.order_index)
      .map((opt: any) => ({
        id: opt.id,
        option_text: opt.option_text,
        vote_count: totals[opt.id] ?? 0,
        // For rating, percentage out of total vote rows; for others, out of unique voters
        percentage: (isRating ? totalVoteRows : totalUniqueVoters) > 0
          ? Math.round(((totals[opt.id] ?? 0) / (isRating ? totalVoteRows : totalUniqueVoters)) * 100)
          : 0,
      }));

    // For rating polls, compute the average score (order_index = star value 1-5)
    let avgRating: number | null = null;
    if (isRating && totalVoteRows > 0) {
      const optionIndexMap: Record<string, number> = {};
      for (const opt of poll.poll_options as any[]) {
        optionIndexMap[opt.id] = opt.order_index; // order_index == star value
      }
      let weightedSum = 0;
      for (const v of votes ?? []) {
        weightedSum += optionIndexMap[(v as any).option_id] ?? 0;
      }
      avgRating = Math.round((weightedSum / totalVoteRows) * 10) / 10;
    }

    return new Response(JSON.stringify({
      has_voted: !!userVote,
      voted_option_id: userVote?.option_id ?? null,
      voted_option_ids: userVotedOptionIds,
      results_available: true,
      total_votes: totalUniqueVoters,
      total_vote_rows: totalVoteRows,
      avg_rating: avgRating,
      options,
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
