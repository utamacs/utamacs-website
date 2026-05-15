export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { fanoutNotification } from '@lib/notifications';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('polls')
      .select('id, title, description, poll_type, max_choices, is_anonymous, one_vote_per_unit, starts_at, ends_at, is_published, result_visibility, created_at, poll_options(id, option_text, order_index)')
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
    const { title, description, poll_type, options, is_anonymous, one_vote_per_unit, starts_at, ends_at,
            result_visibility, max_choices } = body;

    const VALID_POLL_TYPES = ['single_choice', 'multiple_choice', 'yes_no', 'rating'];
    const VALID_VISIBILITIES = ['after_vote', 'after_close', 'executive_only'];
    const isRating = poll_type === 'rating';

    if (!title || !poll_type) {
      return new Response(JSON.stringify({ error: 'title and poll_type are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (!isRating && (!Array.isArray(options) || (options as string[]).length < 2)) {
      return new Response(JSON.stringify({ error: 'At least 2 options are required for non-rating polls' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (!VALID_POLL_TYPES.includes(String(poll_type))) {
      return new Response(JSON.stringify({ error: `poll_type must be one of: ${VALID_POLL_TYPES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const resolvedVisibility = result_visibility && VALID_VISIBILITIES.includes(String(result_visibility))
      ? String(result_visibility)
      : 'after_close';

    const resolvedMaxChoices = poll_type === 'multiple_choice' && typeof max_choices === 'number' && max_choices >= 2
      ? Math.min(max_choices, 20)
      : 1;

    const sb = getSupabaseServiceClient();
    const { data: poll, error } = await sb
      .from('polls')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(String(title)),
        description: description ? sanitizePlainText(String(description)) : null,
        poll_type,
        max_choices: resolvedMaxChoices,
        is_anonymous: is_anonymous ?? false,
        one_vote_per_unit: one_vote_per_unit ?? false,
        starts_at: starts_at ?? new Date().toISOString(),
        ends_at: ends_at ?? null,
        is_published: true,
        result_visibility: resolvedVisibility,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // For rating polls, auto-generate 5 options labelled "1"–"5"
    const optionTexts: string[] = isRating
      ? ['1', '2', '3', '4', '5']
      : (options as string[]);

    const optionRows = optionTexts.map((text: string, i: number) => ({
      poll_id: poll.id,
      option_text: isRating ? text : sanitizePlainText(text),
      order_index: i + 1,
    }));
    await sb.from('poll_options').insert(optionRows);

    fanoutNotification({
      societyId: SOCIETY_ID,
      excludeUserId: user.id,
      preferenceKey: 'polls',
      title: `New poll: ${sanitizePlainText(String(title))}`,
      body: isRating
        ? `Rate on a scale of 1–5`
        : `Cast your vote — ${(options as string[]).slice(0, 3).map((o) => sanitizePlainText(String(o))).join(', ')}${(options as string[]).length > 3 ? '…' : ''}`,
      type: 'poll',
      referenceTable: 'polls',
      referenceId: poll.id,
    });

    return new Response(JSON.stringify(poll), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
