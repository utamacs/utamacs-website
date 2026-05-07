export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Telangana CSACT quorum rule: lesser of 75 members or 25% of total membership
function computeQuorumThreshold(totalMembers: number): number {
  return Math.min(75, Math.ceil(totalMembers * 0.25));
}

// GET /api/v1/agm/sessions/:id/quorum
// Returns live quorum status for an AGM session
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid session id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const [sessionRes, membersRes] = await Promise.all([
      sb.from('agm_sessions')
        .select('id, agm_year, meeting_date, status, attendees_count, quorum_met')
        .eq('id', id)
        .eq('society_id', SOCIETY_ID)
        .single(),
      sb.from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('is_active', true),
    ]);

    if (sessionRes.error || !sessionRes.data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const session = sessionRes.data;
    const totalMembers = membersRes.count ?? 0;
    const threshold = computeQuorumThreshold(totalMembers);
    const attendees = session.attendees_count ?? 0;
    const quorumMet = attendees >= threshold;
    const progressPct = threshold > 0 ? Math.min(100, Math.round((attendees / threshold) * 100)) : 0;
    const remaining = Math.max(0, threshold - attendees);

    return Response.json({
      session_id: id,
      agm_year: session.agm_year,
      meeting_date: session.meeting_date,
      status: session.status,
      total_members: totalMembers,
      quorum_threshold: threshold,
      attendees_count: attendees,
      quorum_met: quorumMet,
      progress_pct: progressPct,
      remaining_needed: remaining,
      threshold_rule: `min(75, ⌈${totalMembers} × 25%⌉) = ${threshold}`,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH /api/v1/agm/sessions/:id/quorum — update attendees count (exec only)
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid session id' }, { status: 400 });

    const body = await request.json() as { attendees_count?: number };
    if (typeof body.attendees_count !== 'number' || body.attendees_count < 0) {
      return Response.json({ error: 'VALIDATION', message: 'attendees_count must be a non-negative number' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { count: totalMembers } = await sb
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true);

    const threshold = computeQuorumThreshold(totalMembers ?? 0);
    const quorumMet = body.attendees_count >= threshold;

    const { error } = await sb
      .from('agm_sessions')
      .update({ attendees_count: body.attendees_count, quorum_met: quorumMet })
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({
      attendees_count: body.attendees_count,
      quorum_met: quorumMet,
      quorum_threshold: threshold,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
