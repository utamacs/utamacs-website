export const prerender = false;
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

export const GET = async () => {
  try {
    const sb = getSupabaseServiceClient();
    const { error } = await sb.from('societies').select('id').limit(1);
    const ok = !error;
    return new Response(
      JSON.stringify({ status: ok ? 'ok' : 'degraded', timestamp: new Date().toISOString(), version: '2.0.0' }),
      { status: ok ? 200 : 503, headers: { 'Content-Type': 'application/json' } }
    );
  } catch {
    return new Response(
      JSON.stringify({ status: 'error', timestamp: new Date().toISOString(), version: '2.0.0' }),
      { status: 503, headers: { 'Content-Type': 'application/json' } }
    );
  }
};
