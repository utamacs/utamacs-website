import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const query = sb
      .from('complaint_comments')
      .select('id, complaint_id, user_id, comment, is_internal, created_at')
      .eq('complaint_id', params.id!)
      .order('created_at', { ascending: true });

    const filtered = user.role === 'member'
      ? query.eq('is_internal', false)
      : query;

    const { data, error } = await filtered;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as { comment?: string; is_internal?: boolean };

    if (!body.comment?.trim()) {
      return new Response(JSON.stringify({ error: 'comment is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const isInternal = body.is_internal === true && ['executive', 'admin'].includes(user.role);

    const sb = getSupabaseServiceClient();

    // Verify complaint belongs to this society
    const { error: chkErr } = await sb
      .from('complaints').select('id').eq('id', params.id!).eq('society_id', SOCIETY_ID).single();
    if (chkErr) {
      return new Response(JSON.stringify({ error: 'Complaint not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });
    }

    const { data, error } = await sb
      .from('complaint_comments')
      .insert({
        complaint_id: params.id,
        user_id: user.id,
        comment: sanitizePlainText(body.comment),
        is_internal: isInternal,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
