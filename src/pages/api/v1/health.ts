export const prerender = false;
import type { APIRoute } from 'astro';

const SOCIETY_ID = '00000000-0000-0000-0000-000000000001';

async function probe(label: string, fn: () => Promise<unknown>): Promise<{ label: string; ok: boolean; detail: string }> {
  try {
    await fn();
    return { label, ok: true, detail: 'ok' };
  } catch (e) {
    return { label, ok: false, detail: e instanceof Error ? e.message : String(e) };
  }
}

export const GET: APIRoute = async ({ request }) => {
  const vars: Record<string, boolean> = {
    PUBLIC_SUPABASE_URL:       !!(process.env.PUBLIC_SUPABASE_URL      ?? import.meta.env.PUBLIC_SUPABASE_URL),
    PUBLIC_SUPABASE_ANON_KEY:  !!(process.env.PUBLIC_SUPABASE_ANON_KEY ?? import.meta.env.PUBLIC_SUPABASE_ANON_KEY),
    SUPABASE_SERVICE_ROLE_KEY: !!(process.env.SUPABASE_SERVICE_ROLE_KEY ?? import.meta.env.SUPABASE_SERVICE_ROLE_KEY),
    PUBLIC_SOCIETY_ID:         !!(process.env.PUBLIC_SOCIETY_ID        ?? import.meta.env.PUBLIC_SOCIETY_ID),
    PROVIDER:                  !!(process.env.PROVIDER                 ?? import.meta.env.PROVIDER),
    ENCRYPTION_KEY:            !!(process.env.ENCRYPTION_KEY),
    IP_HASH_SALT:              !!(process.env.IP_HASH_SALT),
    UPSTASH_REDIS_REST_URL:    !!(process.env.UPSTASH_REDIS_REST_URL),
    UPSTASH_REDIS_REST_TOKEN:  !!(process.env.UPSTASH_REDIS_REST_TOKEN),
  };
  const missing = Object.entries(vars).filter(([, ok]) => !ok).map(([k]) => k);

  // Test auth JWT if caller sends a cookie
  const cookieHeader = request.headers.get('Cookie') ?? '';
  const hasAccessToken = /sb-access-token=/.test(cookieHeader);
  let authProbe = 'no cookie sent';
  if (hasAccessToken) {
    try {
      const { validateJWT } = await import('@lib/middleware/jwtValidator');
      const user = await validateJWT(request);
      authProbe = `ok — user ${user.id}, role ${user.role}, societyId "${user.societyId}"`;
    } catch (e) {
      authProbe = `FAILED: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  let queryProbes: Awaited<ReturnType<typeof probe>>[] = [];
  if (vars.PUBLIC_SUPABASE_URL && vars.SUPABASE_SERVICE_ROLE_KEY) {
    const { getSupabaseServiceClient } = await import('@lib/services/providers/supabase/SupabaseDB');
    const sb = getSupabaseServiceClient();

    queryProbes = await Promise.all([
      // Simple table existence checks
      probe('societies [simple]',      async () => { const { error } = await sb.from('societies').select('id').eq('id', SOCIETY_ID).single(); if (error) throw new Error(error.message); }),

      // EXACT queries used by failing routes (including joins)
      probe('complaints [full query]', async () => {
        const { error } = await sb.from('complaints').select(`
          id, ticket_number, title, category, priority, status, raised_by,
          assigned_to, unit_id, sla_hours, sla_deadline, created_at, updated_at,
          units(unit_number)
        `).eq('society_id', SOCIETY_ID).order('created_at', { ascending: false }).range(0, 19);
        if (error) throw new Error(error.message);
      }),
      probe('notices [full query]', async () => {
        const { error } = await sb.from('notices')
          .select('id, title, body, category, target_audience, is_pinned, requires_acknowledgement, published_at, expires_at, created_at')
          .eq('society_id', SOCIETY_ID).eq('is_published', true)
          .order('is_pinned', { ascending: false }).order('created_at', { ascending: false });
        if (error) throw new Error(error.message);
      }),
      probe('events [full query]', async () => {
        const { error } = await sb.from('events')
          .select('id, title, description, category, starts_at, ends_at, location, capacity, is_paid, ticket_price, is_published, created_at')
          .eq('society_id', SOCIETY_ID).eq('is_published', true).order('starts_at', { ascending: true });
        if (error) throw new Error(error.message);
      }),
      probe('polls [full query — with join]', async () => {
        const { error } = await sb.from('polls')
          .select('id, title, description, poll_type, is_anonymous, one_vote_per_unit, starts_at, ends_at, is_published, result_visibility, created_at, poll_options(id, option_text, order_index)')
          .eq('society_id', SOCIETY_ID).eq('is_published', true).order('created_at', { ascending: false });
        if (error) throw new Error(error.message);
      }),
      probe('vendors [full query]', async () => {
        const { error } = await sb.from('vendors')
          .select('id, name, category, contact_person, email, gstin, pan, contract_start, contract_end, is_active')
          .eq('society_id', SOCIETY_ID).order('name');
        if (error) throw new Error(error.message);
      }),
      probe('community_posts [full query]', async () => {
        const { error } = await sb.from('community_posts')
          .select('id, title, body, category, is_anonymous, is_pinned, created_at, profiles(full_name)')
          .eq('society_id', SOCIETY_ID).order('is_pinned', { ascending: false }).order('created_at', { ascending: false }).range(0, 9);
        if (error) throw new Error(error.message);
      }),
      probe('documents [full query]', async () => {
        const { error } = await sb.from('documents')
          .select('id, title, category, file_size_bytes, file_storage_key, is_public, download_count, created_at')
          .eq('society_id', SOCIETY_ID).order('created_at', { ascending: false });
        if (error) throw new Error(error.message);
      }),
      probe('infrastructure_assets [full query]', async () => {
        const { error } = await sb.from('infrastructure_assets')
          .select('id, name, category, location, status, purchase_date, warranty_expiry, last_serviced_at, next_service_due, created_at')
          .eq('society_id', SOCIETY_ID).order('name');
        if (error) throw new Error(error.message);
      }),
      probe('audit_logs [full query]', async () => {
        const { error } = await sb.from('audit_logs')
          .select('id, user_id, action, resource_type, resource_id, created_at, profiles(full_name)')
          .eq('society_id', SOCIETY_ID).order('created_at', { ascending: false }).range(0, 49);
        if (error) throw new Error(error.message);
      }),
      probe('agm_sessions [full query]', async () => {
        const { error } = await sb.from('agm_sessions')
          .select('id, title, session_date, quorum_required, quorum_met, status, created_at')
          .eq('society_id', SOCIETY_ID).order('session_date', { ascending: false });
        if (error) throw new Error(error.message);
      }),
      probe('facilities+bookings [full query]', async () => {
        const { error } = await sb.from('facility_bookings')
          .select('id, facility_id, booked_by, booking_date, slot_start, slot_end, status, created_at, facilities(name)')
          .eq('society_id', SOCIETY_ID).order('booking_date', { ascending: false }).range(0, 19);
        if (error) throw new Error(error.message);
      }),
    ]);
  }

  const failedProbes = queryProbes.filter(p => !p.ok);
  const healthy = missing.length === 0 && failedProbes.length === 0 && !authProbe.startsWith('FAILED');

  return new Response(
    JSON.stringify({ status: healthy ? 'healthy' : 'degraded', timestamp: new Date().toISOString(), auth: authProbe, missing, queries: queryProbes }),
    { status: healthy ? 200 : 503, headers: { 'Content-Type': 'application/json' } },
  );
};
