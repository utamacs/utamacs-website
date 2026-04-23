import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('complaints')
      .select(`
        id, ticket_number, title, description, category, priority, status,
        raised_by, assigned_to, unit_id, sla_hours, sla_deadline,
        resolved_at, closed_at, reopen_count, created_at, updated_at,
        units(unit_number, block)
      `)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: 'Complaint not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Members can only view their own complaints
    if (user.role === 'member' && data.raised_by !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
