export const prerender = false;
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
      .from('marketplace_listings')
      .update({ status: 'expired' })
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'active')
      .lt('expires_at', now)
      .select('id, seller_id, title');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const expired = data ?? [];

    // Notify sellers their listing expired
    if (expired.length > 0) {
      const notifications = expired.map((l: any) => ({
        society_id: SOCIETY_ID,
        user_id: l.seller_id,
        title: 'Listing Expired',
        body: `Your listing "${l.title}" has expired after 30 days. You can repost it from the Marketplace.`,
        type: 'system',
        reference_table: 'marketplace_listings',
        reference_id: l.id,
        channel: 'in_app',
        status: 'sent',
      }));
      await sb.from('notifications').insert(notifications);
    }

    return new Response(JSON.stringify({ expired: expired.length }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
