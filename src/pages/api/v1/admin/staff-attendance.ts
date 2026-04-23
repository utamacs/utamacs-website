export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (!['security_guard', 'executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const date = url.searchParams.get('date') ?? new Date().toISOString().split('T')[0];
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);

    const { data, error } = await sb
      .from('staff_attendance')
      .select('id, staff_name, staff_type, check_in, check_out, date, logged_by, profiles(full_name)')
      .eq('society_id', SOCIETY_ID)
      .eq('date', date)
      .order('check_in', { ascending: false })
      .limit(limit);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['security_guard', 'executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      staff_name?: string; staff_type?: string; staff_id?: string; check_out_id?: string;
    };

    const sb = getSupabaseServiceClient();

    // Log exit — update check_out on an existing record
    if (body.check_out_id) {
      const { data, error } = await sb
        .from('staff_attendance')
        .update({ check_out: new Date().toISOString() })
        .eq('id', body.check_out_id)
        .eq('society_id', SOCIETY_ID)
        .is('check_out', null)
        .select()
        .single();

      if (error || !data) {
        return new Response(JSON.stringify({ error: 'Record not found or already checked out' }), {
          status: 404, headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
    }

    // Log entry
    if (!body.staff_name?.trim() || !body.staff_type) {
      return new Response(JSON.stringify({ error: 'staff_name and staff_type are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const now = new Date();
    const { data, error } = await sb
      .from('staff_attendance')
      .insert({
        society_id: SOCIETY_ID,
        staff_id: body.staff_id ?? null,
        staff_name: sanitizePlainText(body.staff_name),
        staff_type: body.staff_type,
        check_in: now.toISOString(),
        date: now.toISOString().split('T')[0],
        logged_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
