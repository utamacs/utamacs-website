export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as {
      option_id?: string;    // single_choice / yes_no
      option_ids?: string[]; // multiple_choice
      vote_value?: number;   // rating (1–5)
    };

    const sb = getSupabaseServiceClient();

    const { data: poll, error: pollErr } = await sb
      .from('polls')
      .select('id, is_published, ends_at, one_vote_per_unit, is_anonymous, poll_type, max_choices, poll_options(id, option_text, order_index)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pollErr || !poll?.is_published) {
      return new Response(JSON.stringify({ error: 'Poll not found or not active' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (poll.ends_at && new Date(poll.ends_at) < new Date()) {
      return new Response(JSON.stringify({ error: 'Poll has ended' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const pollType: string = (poll as any).poll_type ?? 'single_choice';
    const maxChoices: number = (poll as any).max_choices ?? 1;
    const pollOptions: Array<{ id: string; option_text: string; order_index: number }> =
      (poll as any).poll_options ?? [];

    // Resolve which option_ids to insert
    let optionIds: string[] = [];

    if (pollType === 'rating') {
      const val = typeof body.vote_value === 'number' ? body.vote_value : null;
      if (!val || val < 1 || val > 5 || !Number.isInteger(val)) {
        return new Response(JSON.stringify({ error: 'vote_value must be an integer 1–5 for rating polls' }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      const match = pollOptions.find((o) => o.order_index === val);
      if (!match) {
        return new Response(JSON.stringify({ error: 'Rating option not found' }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      optionIds = [match.id];
    } else if (pollType === 'multiple_choice') {
      const ids = Array.isArray(body.option_ids) ? body.option_ids : (body.option_id ? [body.option_id] : []);
      if (ids.length === 0) {
        return new Response(JSON.stringify({ error: 'option_ids is required for multiple_choice polls' }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      if (ids.length > maxChoices) {
        return new Response(JSON.stringify({ error: `You may select at most ${maxChoices} option(s)` }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      const validIds = new Set(pollOptions.map((o) => o.id));
      const invalid = ids.find((id) => !validIds.has(id));
      if (invalid) {
        return new Response(JSON.stringify({ error: `option_id ${invalid} does not belong to this poll` }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      optionIds = [...new Set(ids)]; // deduplicate
    } else {
      // single_choice / yes_no
      const oid = body.option_id ?? (Array.isArray(body.option_ids) ? body.option_ids[0] : undefined);
      if (!oid) {
        return new Response(JSON.stringify({ error: 'option_id is required' }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      const valid = pollOptions.some((o) => o.id === oid);
      if (!valid) {
        return new Response(JSON.stringify({ error: 'option_id does not belong to this poll' }), {
          status: 400, headers: { 'Content-Type': 'application/json' },
        });
      }
      optionIds = [oid];
    }

    // Check if user has already voted (any option in this poll)
    const { data: existingVotes } = await sb
      .from('poll_votes')
      .select('id, option_id')
      .eq('poll_id', params.id!)
      .eq('user_id', user.id);

    if (pollType === 'single_choice' || pollType === 'yes_no' || pollType === 'rating') {
      if ((existingVotes ?? []).length > 0) {
        return new Response(JSON.stringify({ error: 'You have already voted in this poll' }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
    } else {
      // multiple_choice: check max_choices not exceeded and no duplicate options
      const alreadyVotedCount = (existingVotes ?? []).length;
      if (alreadyVotedCount >= maxChoices) {
        return new Response(JSON.stringify({ error: `You have already used all ${maxChoices} vote(s)` }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
      const existingOptionIds = new Set((existingVotes ?? []).map((v: any) => v.option_id));
      const dupes = optionIds.filter((id) => existingOptionIds.has(id));
      if (dupes.length > 0) {
        return new Response(JSON.stringify({ error: 'You have already voted for one or more of these options' }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
      if (alreadyVotedCount + optionIds.length > maxChoices) {
        return new Response(JSON.stringify({
          error: `You can only select ${maxChoices - alreadyVotedCount} more option(s)`,
        }), { status: 409, headers: { 'Content-Type': 'application/json' } });
      }
    }

    // Enforce one_vote_per_unit
    if (poll.one_vote_per_unit && (existingVotes ?? []).length === 0) {
      const { data: profile } = await sb
        .from('profiles')
        .select('unit_id')
        .eq('id', user.id)
        .single();
      if (profile?.unit_id) {
        const { data: unitMembers } = await sb
          .from('profiles')
          .select('id')
          .eq('unit_id', profile.unit_id);
        const unitMemberIds = (unitMembers ?? []).map((m: any) => m.id);
        if (unitMemberIds.length > 0) {
          const { data: unitVote } = await sb
            .from('poll_votes')
            .select('id')
            .eq('poll_id', params.id!)
            .in('user_id', unitMemberIds)
            .limit(1)
            .maybeSingle();
          if (unitVote) {
            return new Response(JSON.stringify({ error: 'A member of your unit has already voted in this poll' }), {
              status: 409, headers: { 'Content-Type': 'application/json' },
            });
          }
        }
      }
    }

    // Insert all votes
    const voteRows = optionIds.map((oid) => ({
      poll_id: params.id,
      option_id: oid,
      user_id: user.id,
    }));

    const { data: inserted, error: insertErr } = await sb
      .from('poll_votes')
      .insert(voteRows)
      .select('id');

    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    return new Response(JSON.stringify({
      success: true,
      votes_cast: (inserted ?? []).length,
      vote_ids: (inserted ?? []).map((v: any) => v.id),
    }), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
