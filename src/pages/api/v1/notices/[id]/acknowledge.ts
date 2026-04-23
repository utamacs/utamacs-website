import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — check if current user already acknowledged this notice
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data } = await sb
      .from('notice_acknowledgements')
      .select('acknowledged_at')
      .eq('notice_id', params.id!)
      .eq('user_id', user.id)
      .maybeSingle();

    return new Response(JSON.stringify({ acknowledged: !!data, acknowledged_at: data?.acknowledged_at ?? null }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — record acknowledgement (idempotent: upsert)
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    // Verify notice exists and belongs to this society
    const { data: notice } = await sb
      .from('notices')
      .select('id, requires_acknowledgement')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (!notice) {
      return new Response(JSON.stringify({ error: 'Notice not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!notice.requires_acknowledgement) {
      return new Response(JSON.stringify({ error: 'This notice does not require acknowledgement' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { error } = await sb
      .from('notice_acknowledgements')
      .upsert({ notice_id: params.id!, user_id: user.id, acknowledged_at: new Date().toISOString() }, {
        onConflict: 'notice_id,user_id',
      });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
