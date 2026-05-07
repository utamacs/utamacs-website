export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Byelaw §7.5f: quorum = min(AGM_QUORUM_ABSOLUTE_MIN, ⌈total × AGM_QUORUM_PERCENTAGE/100⌉)
// For 136 flats: min(68, ⌈136 × 50%⌉) = min(68, 68) = 68
function computeQuorumThreshold(
  totalMembers: number,
  absoluteMin: number,
  pct: number,
): { threshold: number; ruleDescription: string } {
  const byPct = Math.ceil(totalMembers * pct / 100);
  const threshold = Math.min(absoluteMin, byPct);
  return {
    threshold,
    ruleDescription: `min(${absoluteMin}, ⌈${totalMembers} × ${pct}%⌉) = min(${absoluteMin}, ${byPct}) = ${threshold} — Byelaw §7.5f`,
  };
}

// GET /api/v1/agm/sessions/:id/quorum
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid session id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const [sessionRes, membersRes, rules] = await Promise.all([
      sb.from('agm_sessions')
        .select('id, agm_year, meeting_date, status, attendees_count, quorum_met')
        .eq('id', id)
        .eq('society_id', SOCIETY_ID)
        .single(),
      sb.from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('is_active', true),
      getRules(sb, SOCIETY_ID, ['AGM_QUORUM_ABSOLUTE_MIN', 'AGM_QUORUM_PERCENTAGE']),
    ]);

    if (sessionRes.error || !sessionRes.data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const session = sessionRes.data;
    const totalMembers = membersRes.count ?? 0;
    const absoluteMin = ruleInt(rules, 'AGM_QUORUM_ABSOLUTE_MIN', 68);
    const pct = ruleInt(rules, 'AGM_QUORUM_PERCENTAGE', 50);

    const { threshold, ruleDescription } = computeQuorumThreshold(totalMembers, absoluteMin, pct);
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
      threshold_rule: ruleDescription,
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

    const [membersRes, rules] = await Promise.all([
      sb.from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('society_id', SOCIETY_ID)
        .eq('is_active', true),
      getRules(sb, SOCIETY_ID, ['AGM_QUORUM_ABSOLUTE_MIN', 'AGM_QUORUM_PERCENTAGE']),
    ]);

    const totalMembers = membersRes.count ?? 0;
    const absoluteMin = ruleInt(rules, 'AGM_QUORUM_ABSOLUTE_MIN', 68);
    const pct = ruleInt(rules, 'AGM_QUORUM_PERCENTAGE', 50);
    const { threshold } = computeQuorumThreshold(totalMembers, absoluteMin, pct);
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
