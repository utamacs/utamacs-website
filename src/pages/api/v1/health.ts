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

  const cookieHeader = request.headers.get('Cookie') ?? '';
  const hasAccessToken = /sb-access-token=/.test(cookieHeader);

  let authProbe = 'no cookie sent — cannot test';
  if (hasAccessToken) {
    try {
      const { validateJWT } = await import('@lib/middleware/jwtValidator');
      const user = await validateJWT(request);
      authProbe = `ok — user ${user.id}, role ${user.role}, societyId "${user.societyId}"`;
    } catch (e) {
      authProbe = `failed: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  let tableProbes: Awaited<ReturnType<typeof probe>>[] = [];
  if (vars.PUBLIC_SUPABASE_URL && vars.SUPABASE_SERVICE_ROLE_KEY) {
    const { getSupabaseServiceClient } = await import('@lib/services/providers/supabase/SupabaseDB');
    const sb = getSupabaseServiceClient();

    tableProbes = await Promise.all([
      probe('societies',             async () => { const { error } = await sb.from('societies').select('id').eq('id', SOCIETY_ID).single(); if (error) throw new Error(error.message); }),
      probe('complaints',            async () => { const { error } = await sb.from('complaints').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('notices',               async () => { const { error } = await sb.from('notices').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('events',                async () => { const { error } = await sb.from('events').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('polls',                 async () => { const { error } = await sb.from('polls').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('facilities',            async () => { const { error } = await sb.from('facilities').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('vendors',               async () => { const { error } = await sb.from('vendors').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('community_posts',       async () => { const { error } = await sb.from('community_posts').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('documents',             async () => { const { error } = await sb.from('documents').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('audit_logs',            async () => { const { error } = await sb.from('audit_logs').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('agm_sessions',          async () => { const { error } = await sb.from('agm_sessions').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('infrastructure_assets', async () => { const { error } = await sb.from('infrastructure_assets').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('profiles',              async () => { const { error } = await sb.from('profiles').select('id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
      probe('user_roles',            async () => { const { error } = await sb.from('user_roles').select('user_id').eq('society_id', SOCIETY_ID).limit(1); if (error) throw new Error(error.message); }),
    ]);
  }

  const failedTables = tableProbes.filter(p => !p.ok);
  const healthy = missing.length === 0 && failedTables.length === 0 && !authProbe.startsWith('failed');

  return new Response(
    JSON.stringify({ status: healthy ? 'healthy' : 'degraded', timestamp: new Date().toISOString(), version: '2.0.0', vars, missing, auth: authProbe, tables: tableProbes }),
    { status: healthy ? 200 : 503, headers: { 'Content-Type': 'application/json' } },
  );
};
