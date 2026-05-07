export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

// GET /api/v1/notifications/preferences
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('notification_preferences')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Auto-create if missing (trigger should handle it, but safeguard here)
    if (!data) {
      const { data: created, error: insertErr } = await sb
        .from('notification_preferences')
        .insert({ user_id: user.id })
        .select()
        .single();
      if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });
      return Response.json(created);
    }

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH /api/v1/notifications/preferences
// Accepts any boolean fields from the notification_preferences table
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json() as Record<string, unknown>;

    const PATCHABLE_BOOLEANS = [
      'complaints', 'notices', 'events', 'polls', 'payments',
      'visitor_alerts', 'community', 'marketplace', 'maids',
      'gallery', 'feedback', 'snags',
      'email_enabled', 'email_digest_enabled', 'sms_enabled', 'push_enabled', 'whatsapp_enabled',
    ];
    const updates: Record<string, unknown> = {};
    for (const key of PATCHABLE_BOOLEANS) {
      if (typeof body[key] === 'boolean') updates[key] = body[key];
    }
    // Quiet hours (time strings HH:MM)
    if (typeof body.quiet_hours_start === 'string') updates.quiet_hours_start = body.quiet_hours_start || null;
    if (typeof body.quiet_hours_end   === 'string') updates.quiet_hours_end   = body.quiet_hours_end || null;

    updates.updated_at = new Date().toISOString();

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('notification_preferences')
      .upsert({ user_id: user.id, ...updates }, { onConflict: 'user_id' })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
