export const prerender = false;
import type { APIRoute } from 'astro';

export const GET: APIRoute = async () => {
  // Check which env vars are present — never expose values, only presence
  const vars: Record<string, boolean> = {
    PUBLIC_SUPABASE_URL:      !!(process.env.PUBLIC_SUPABASE_URL      ?? import.meta.env.PUBLIC_SUPABASE_URL),
    PUBLIC_SUPABASE_ANON_KEY: !!(process.env.PUBLIC_SUPABASE_ANON_KEY ?? import.meta.env.PUBLIC_SUPABASE_ANON_KEY),
    SUPABASE_SERVICE_ROLE_KEY:!!(process.env.SUPABASE_SERVICE_ROLE_KEY ?? import.meta.env.SUPABASE_SERVICE_ROLE_KEY),
    PUBLIC_SOCIETY_ID:        !!(process.env.PUBLIC_SOCIETY_ID        ?? import.meta.env.PUBLIC_SOCIETY_ID),
    PROVIDER:                 !!(process.env.PROVIDER                 ?? import.meta.env.PROVIDER),
    ENCRYPTION_KEY:           !!(process.env.ENCRYPTION_KEY),
    IP_HASH_SALT:             !!(process.env.IP_HASH_SALT),
  };

  const missing = Object.entries(vars).filter(([, ok]) => !ok).map(([k]) => k);

  // Probe DB only when credentials are present
  let db: string = 'skipped (missing credentials)';
  if (vars.PUBLIC_SUPABASE_URL && vars.SUPABASE_SERVICE_ROLE_KEY) {
    try {
      const { getSupabaseServiceClient } = await import('@lib/services/providers/supabase/SupabaseDB');
      const { error } = await getSupabaseServiceClient()
        .from('societies').select('id').limit(1).single();
      db = error ? `error: ${error.message}` : 'ok';
    } catch (e) {
      db = `exception: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  const healthy = missing.length === 0 && db === 'ok';
  return new Response(
    JSON.stringify({
      status: healthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      version: '2.0.0',
      vars,
      missing,
      db,
    }),
    { status: healthy ? 200 : 503, headers: { 'Content-Type': 'application/json' } },
  );
};
