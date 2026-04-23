export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    if (user.role === 'member') {
      // Member KPIs via DB function
      const { data, error } = await sb.rpc('get_member_dashboard_kpis', {
        p_user_id: user.id,
        p_society_id: SOCIETY_ID,
      });
      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
    } else {
      // Executive/Admin KPIs via DB function
      const { data, error } = await sb.rpc('get_executive_dashboard_kpis', {
        p_society_id: SOCIETY_ID,
      });
      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
    }
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
