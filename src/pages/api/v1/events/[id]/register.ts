export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — check current user's registration status for this event
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data } = await sb
      .from('event_registrations')
      .select('id, status, attendees_count, registered_at')
      .eq('event_id', params.id!)
      .eq('user_id', user.id)
      .maybeSingle();

    // Also return event capacity info
    const { data: event } = await sb
      .from('events')
      .select('id, capacity, title')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!event) {
      return new Response(JSON.stringify({ error: 'Event not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    let registeredCount = 0;
    if (event.capacity) {
      const { count } = await sb
        .from('event_registrations')
        .select('id', { count: 'exact', head: true })
        .eq('event_id', params.id!)
        .in('status', ['registered', 'waitlisted']);
      registeredCount = count ?? 0;
    }

    return new Response(JSON.stringify({
      registration: data,
      capacity: event.capacity,
      registered_count: registeredCount,
      spots_left: event.capacity ? Math.max(0, event.capacity - registeredCount) : null,
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — RSVP / register for event
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: event } = await sb
      .from('events')
      .select('id, title, capacity, starts_at, registration_deadline, is_published, society_id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .single();

    if (!event) {
      return new Response(JSON.stringify({ error: 'Event not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Check registration deadline
    if (event.registration_deadline && new Date(event.registration_deadline) < new Date()) {
      return new Response(JSON.stringify({ error: 'Registration deadline has passed' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Check if event already started
    if (new Date(event.starts_at) < new Date()) {
      return new Response(JSON.stringify({ error: 'Event has already started' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Check for existing registration
    const { data: existing } = await sb
      .from('event_registrations')
      .select('id, status')
      .eq('event_id', params.id!)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      if (existing.status === 'cancelled') {
        // Allow re-registration after cancellation
      } else {
        return new Response(JSON.stringify({ error: 'You are already registered for this event', registration: existing }), {
          status: 409, headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    // Get user's unit_id from profile
    const { data: profile } = await sb
      .from('profiles')
      .select('unit_id')
      .eq('id', user.id)
      .single();

    // Check capacity and determine status
    let status: 'registered' | 'waitlisted' = 'registered';
    if (event.capacity) {
      const { count } = await sb
        .from('event_registrations')
        .select('id', { count: 'exact', head: true })
        .eq('event_id', params.id!)
        .in('status', ['registered']);
      const registeredCount = count ?? 0;
      if (registeredCount >= event.capacity) {
        status = 'waitlisted';
      }
    }

    const body = await request.json().catch(() => ({})) as { attendees_count?: number };
    const attendeesCount = Math.max(1, Math.min(10, body.attendees_count ?? 1));

    let registration;
    if (existing) {
      // Re-register after cancellation
      const { data, error } = await sb
        .from('event_registrations')
        .update({ status, attendees_count: attendeesCount, registered_at: new Date().toISOString() })
        .eq('id', existing.id)
        .select()
        .single();
      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      registration = data;
    } else {
      const { data, error } = await sb
        .from('event_registrations')
        .insert({
          event_id: params.id!,
          user_id: user.id,
          unit_id: profile?.unit_id ?? null,
          attendees_count: attendeesCount,
          status,
          registered_at: new Date().toISOString(),
        })
        .select()
        .single();
      if (error) throw Object.assign(new Error(error.message), { status: 500 });
      registration = data;
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'event_registrations', resourceId: registration.id,
      ip: extractClientIP(request),
      newValues: { event_id: params.id!, status },
    });

    return new Response(JSON.stringify({ registration, status }), {
      status: 201, headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// DELETE — cancel RSVP
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: reg } = await sb
      .from('event_registrations')
      .select('id, status, event_id')
      .eq('event_id', params.id!)
      .eq('user_id', user.id)
      .single();

    if (!reg) {
      return new Response(JSON.stringify({ error: 'Registration not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    await sb
      .from('event_registrations')
      .update({ status: 'cancelled' })
      .eq('id', reg.id);

    // Promote first waitlisted registration if any
    if (reg.status === 'registered') {
      const { data: next } = await sb
        .from('event_registrations')
        .select('id')
        .eq('event_id', params.id!)
        .eq('status', 'waitlisted')
        .order('registered_at', { ascending: true })
        .limit(1)
        .maybeSingle();

      if (next) {
        await sb.from('event_registrations').update({ status: 'registered' }).eq('id', next.id);
      }
    }

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
