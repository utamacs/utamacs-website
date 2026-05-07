export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

// GET — list attendance records
// Exec: all records for a given event_id (required)
// Member: their own records only
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();
    const isPrivileged = ['executive', 'admin', 'security_guard'].includes(user.role) || user.isAdmin;

    const eventId = url.searchParams.get('event_id');

    if (isPrivileged) {
      if (!eventId || !UUID_RE.test(eventId)) {
        return Response.json(
          { error: 'MISSING_PARAM', message: 'event_id query parameter is required for exec view.' },
          { status: 400 },
        );
      }

      const { data, error } = await sb
        .from('event_attendance')
        .select(`
          id, event_id, user_id, unit_id, guest_count, checked_in_at, notes, created_at,
          profiles(full_name),
          units(unit_number)
        `)
        .eq('event_id', eventId)
        .order('created_at', { ascending: true });

      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      return Response.json(data ?? []);
    }

    // Member: own records only
    let query = sb
      .from('event_attendance')
      .select(`
        id, event_id, user_id, unit_id, guest_count, checked_in_at, notes, created_at,
        profiles(full_name),
        units(unit_number)
      `)
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (eventId && UUID_RE.test(eventId)) {
      query = (query as any).eq('event_id', eventId);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — RSVP (upsert on event_id + user_id conflict)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);

    const body = await request.json() as {
      event_id?: string;
      guest_count?: number;
      notes?: string;
    };

    if (!body.event_id || !UUID_RE.test(body.event_id)) {
      return Response.json(
        { error: 'INVALID_EVENT_ID', message: 'A valid event_id is required.' },
        { status: 400 },
      );
    }

    const guestCount = Math.min(10, Math.max(0, Math.floor(body.guest_count ?? 0)));

    const sb = getSupabaseServiceClient();

    // Verify event belongs to this society
    const { data: event } = await sb
      .from('events')
      .select('id, title')
      .eq('id', body.event_id)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!event) {
      return Response.json({ error: 'NOT_FOUND', message: 'Event not found.' }, { status: 404 });
    }

    // Fetch user's unit_id from profile
    const { data: profile } = await sb
      .from('profiles')
      .select('unit_id')
      .eq('id', user.id)
      .single();

    const { data, error } = await sb
      .from('event_attendance')
      .upsert(
        {
          event_id: body.event_id,
          user_id: user.id,
          unit_id: (profile as any)?.unit_id ?? null,
          guest_count: guestCount,
          notes: body.notes ? sanitizePlainText(body.notes).slice(0, 300) : null,
        },
        { onConflict: 'event_id,user_id' },
      )
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'event_attendance', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { event_id: body.event_id, guest_count: guestCount },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH (exec/guard) — mark checked_in_at
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin', 'security_guard'].includes(user.role) && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN', message: 'Exec or guard access required.' }, { status: 403 });
    }

    const body = await request.json() as { id?: string; checked_in?: boolean };

    if (!body.id || !UUID_RE.test(body.id)) {
      return Response.json({ error: 'INVALID_ID', message: 'A valid attendance record id is required.' }, { status: 400 });
    }

    if (typeof body.checked_in !== 'boolean') {
      return Response.json({ error: 'INVALID_FIELD', message: 'checked_in must be a boolean.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('event_attendance')
      .select('id, checked_in_at')
      .eq('id', body.id)
      .maybeSingle();

    if (!existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Attendance record not found.' }, { status: 404 });
    }

    const { data, error } = await sb
      .from('event_attendance')
      .update({
        checked_in_at: body.checked_in ? new Date().toISOString() : null,
        marked_by: user.id,
      })
      .eq('id', body.id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'event_attendance', resourceId: body.id,
      ip: extractClientIP(request),
      oldValues: { checked_in_at: existing.checked_in_at },
      newValues: { checked_in_at: data.checked_in_at },
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — member cancels their own RSVP
export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);

    const id = url.searchParams.get('id');
    if (!id || !UUID_RE.test(id)) {
      return Response.json({ error: 'INVALID_ID', message: 'A valid attendance id query param is required.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Verify ownership: member can only delete their own record
    const { data: record } = await sb
      .from('event_attendance')
      .select('id, user_id')
      .eq('id', id)
      .maybeSingle();

    if (!record) {
      return Response.json({ error: 'NOT_FOUND', message: 'Attendance record not found.' }, { status: 404 });
    }

    const isPrivileged = ['executive', 'admin'].includes(user.role) || user.isAdmin;
    if (!isPrivileged && record.user_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN', message: 'You can only cancel your own RSVP.' }, { status: 403 });
    }

    const { error } = await sb.from('event_attendance').delete().eq('id', id);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'DELETE', resourceType: 'event_attendance', resourceId: id,
      ip: extractClientIP(request),
    });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
