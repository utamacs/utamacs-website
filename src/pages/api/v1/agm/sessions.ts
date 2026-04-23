import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_AGM_TYPES = ['annual', 'extraordinary'] as const;
const VALID_STATUSES = ['scheduled', 'held', 'adjourned', 'cancelled'] as const;

// GET — list AGM sessions
export const GET: APIRoute = async ({ request }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('agm_sessions')
      .select('*, agm_documents(id, document_type, status, title)')
      .eq('society_id', SOCIETY_ID)
      .order('agm_year', { ascending: false })
      .order('meeting_date', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create AGM session (exec/admin only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only executives and admins can create AGM sessions' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      agm_year?: number; agm_type?: string; meeting_date?: string;
      meeting_time?: string; venue?: string; notes?: string;
    };

    if (!body.agm_year || !body.meeting_date) {
      return new Response(JSON.stringify({ error: 'agm_year and meeting_date are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (body.agm_type && !VALID_AGM_TYPES.includes(body.agm_type as typeof VALID_AGM_TYPES[number])) {
      return new Response(JSON.stringify({ error: `agm_type must be one of: ${VALID_AGM_TYPES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('agm_sessions')
      .insert({
        society_id: SOCIETY_ID,
        agm_year: body.agm_year,
        agm_type: body.agm_type ?? 'annual',
        meeting_date: body.meeting_date,
        meeting_time: body.meeting_time ?? null,
        venue: body.venue ? sanitizePlainText(body.venue) : null,
        notes: body.notes ? sanitizePlainText(body.notes) : null,
        created_by: user.id,
        status: 'scheduled',
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return new Response(JSON.stringify({ error: `An ${body.agm_type ?? 'annual'} AGM session for ${body.agm_year} already exists` }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'agm_sessions', resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { agm_year: body.agm_year, agm_type: body.agm_type, meeting_date: body.meeting_date },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — update AGM session status (exec/admin only)
export const PATCH: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sessionId = url.searchParams.get('id');
    if (!sessionId) {
      return new Response(JSON.stringify({ error: 'id query parameter required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      status?: string; quorum_met?: boolean; attendees_count?: number;
      chair_user_id?: string; notes?: string; venue?: string;
    };

    if (body.status && !VALID_STATUSES.includes(body.status as typeof VALID_STATUSES[number])) {
      return new Response(JSON.stringify({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const updates: Record<string, unknown> = {};
    if (body.status !== undefined) updates.status = body.status;
    if (body.quorum_met !== undefined) updates.quorum_met = body.quorum_met;
    if (body.attendees_count !== undefined) updates.attendees_count = body.attendees_count;
    if (body.chair_user_id !== undefined) updates.chair_user_id = body.chair_user_id;
    if (body.notes !== undefined) updates.notes = sanitizePlainText(body.notes);
    if (body.venue !== undefined) updates.venue = sanitizePlainText(body.venue);

    const { data, error } = await sb
      .from('agm_sessions')
      .update(updates)
      .eq('id', sessionId)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    if (!data) return new Response(JSON.stringify({ error: 'Session not found' }), { status: 404, headers: { 'Content-Type': 'application/json' } });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'agm_sessions', resourceId: sessionId,
      ip: extractClientIP(request), newValues: updates,
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
