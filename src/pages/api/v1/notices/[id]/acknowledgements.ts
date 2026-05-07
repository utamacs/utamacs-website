export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/** GET /api/v1/notices/:id/acknowledgements — exec-only: who has/hasn't acknowledged. */
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Verify notice exists, belongs to society, and requires acknowledgement
    const { data: notice } = await sb
      .from('notices')
      .select('id, title, requires_acknowledgement')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
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

    const [{ data: profiles }, { data: acks }] = await Promise.all([
      sb
        .from('profiles')
        .select('id, full_name, units(unit_number)')
        .eq('society_id', SOCIETY_ID)
        .eq('is_active', true),
      sb
        .from('notice_acknowledgements')
        .select('user_id, acknowledged_at')
        .eq('notice_id', params.id!),
    ]);

    const ackMap = new Map(
      (acks ?? []).map((a: any) => [a.user_id, a.acknowledged_at]),
    );

    const members = (profiles ?? [])
      .map((p: any) => ({
        id: p.id,
        name: p.full_name,
        unit_number: (p.units as any)?.unit_number ?? null,
        acknowledged_at: ackMap.get(p.id) ?? null,
      }))
      .sort((a, b) => {
        if (a.acknowledged_at && !b.acknowledged_at) return -1;
        if (!a.acknowledged_at && b.acknowledged_at) return 1;
        return a.name.localeCompare(b.name);
      });

    const acknowledged_count = members.filter((m) => m.acknowledged_at).length;

    return new Response(
      JSON.stringify({
        summary: {
          total: members.length,
          acknowledged_count,
          pending_count: members.length - acknowledged_count,
        },
        members,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
