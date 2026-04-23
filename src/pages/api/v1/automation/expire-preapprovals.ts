import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET = import.meta.env.CRON_SECRET;

export const GET: APIRoute = async ({ request }) => {
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const now = new Date().toISOString();

    const { data, error } = await sb
      .from('visitor_pre_approvals')
      .update({ status: 'expired' })
      .eq('society_id', SOCIETY_ID)
      .in('status', ['pending', 'approved'])
      .lt('expires_at', now)
      .select('id');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ expired: (data ?? []).length }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
