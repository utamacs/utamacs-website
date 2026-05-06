export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const CRON_SECRET = import.meta.env.CRON_SECRET;

// GET — keep Supabase free-tier project alive by querying the DB.
// Supabase pauses free projects after 7 days of inactivity.
// Runs every 6 days to stay well within that window.
export const GET: APIRoute = async ({ request }) => {
  const t0 = Date.now();
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const sb = getSupabaseServiceClient();

    const { error } = await sb
      .from('profiles')
      .select('id', { count: 'exact', head: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await sb.from('cron_heartbeats').insert({
      cron_name: 'supabase-ping',
      status: 'OK',
      items_processed: 1,
      items_failed: 0,
      duration_ms: Date.now() - t0,
      error_message: null,
    });

    return Response.json({ status: 'OK', duration_ms: Date.now() - t0 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
