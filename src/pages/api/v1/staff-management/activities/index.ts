export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_DEPT = ['security','housekeeping','gardening','maintenance','admin','multi'] as const;
const VALID_FREQ = ['daily','weekly','monthly','quarterly','half_yearly','yearly','on_demand'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb   = getSupabaseServiceClient();

    const dept   = url.searchParams.get('department');
    const freq   = url.searchParams.get('frequency');
    const active = url.searchParams.get('active');

    let query = sb
      .from('staff_activity_templates')
      .select('id, department, title, title_hi, title_te, frequency, frequency_days, location_variants, checklist, requires_photo, estimated_mins, is_active, is_approved, default_assigned_to, asset_id, preferred_day_of_week, created_at')
      .eq('society_id', SOCIETY_ID)
      .order('department')
      .order('title');

    if (dept && VALID_DEPT.includes(dept as typeof VALID_DEPT[number])) query = query.eq('department', dept);
    if (freq && VALID_FREQ.includes(freq as typeof VALID_FREQ[number])) query = query.eq('frequency', freq);
    if (active !== null) query = query.eq('is_active', active !== 'false');

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive','admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'FORBIDDEN', message: 'Exec access required.' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
    }

    const body = await request.json() as Record<string, unknown>;
    const { title, department, frequency } = body;

    if (!title || typeof title !== 'string' || !title.trim()) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'title is required.' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }
    if (!department || !VALID_DEPT.includes(department as typeof VALID_DEPT[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Valid department is required.' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }
    if (!frequency || !VALID_FREQ.includes(frequency as typeof VALID_FREQ[number])) {
      return new Response(JSON.stringify({ error: 'VALIDATION', message: 'Valid frequency is required.' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }

    // Validate location_variants UUIDs
    const rawLocs = Array.isArray(body.location_variants) ? (body.location_variants as unknown[]) : [];
    const locationVariants = rawLocs.every(id => typeof id === 'string' && UUID_RE.test(id))
      ? (rawLocs as string[])
      : null;

    // Validate assigned_to UUID
    const assignedTo = typeof body.default_assigned_to === 'string' && UUID_RE.test(body.default_assigned_to)
      ? body.default_assigned_to : null;

    // Validate asset_id UUID
    const assetId = typeof body.asset_id === 'string' && UUID_RE.test(body.asset_id)
      ? body.asset_id : null;

    // Validate and normalise checklist steps
    const rawChecklist = Array.isArray(body.checklist) ? (body.checklist as Record<string, unknown>[]) : [];
    const checklist = rawChecklist
      .filter(step => step && typeof step.text_en === 'string' && step.text_en.trim())
      .map((step, i) => ({
        id:             crypto.randomUUID(),
        order:          i + 1,
        text_en:        String(step.text_en).trim().slice(0, 500),
        text_hi:        typeof step.text_hi === 'string' ? step.text_hi.trim().slice(0, 500) || null : null,
        text_te:        typeof step.text_te === 'string' ? step.text_te.trim().slice(0, 500) || null : null,
        expected_value: typeof step.expected_value === 'string' ? step.expected_value.trim().slice(0, 300) || null : null,
        photo_required: !!step.photo_required,
        severity:       step.severity === 'critical' ? 'critical' : 'warning',
      }));

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('staff_activity_templates')
      .insert({
        society_id:            SOCIETY_ID,
        title:                 String(title).trim().slice(0, 200),
        title_hi:              typeof body.title_hi === 'string' ? body.title_hi.trim().slice(0, 200) || null : null,
        title_te:              typeof body.title_te === 'string' ? body.title_te.trim().slice(0, 200) || null : null,
        department,
        frequency,
        frequency_days:        body.frequency_days ? Math.max(1, parseInt(String(body.frequency_days))) : null,
        location_variants:     locationVariants?.length ? locationVariants : null,
        preferred_day_of_week: body.preferred_day_of_week != null ? Math.min(6, Math.max(0, parseInt(String(body.preferred_day_of_week)))) : null,
        default_assigned_to:   assignedTo,
        asset_id:              assetId,
        requires_photo:        !!body.requires_photo,
        estimated_mins:        body.estimated_mins ? Math.max(1, parseInt(String(body.estimated_mins))) : null,
        description:           typeof body.description === 'string' ? body.description.trim().slice(0, 1000) || null : null,
        checklist,
        created_by:            user.id,
        is_approved:           true,
        is_active:             true,
      })
      .select('id')
      .single();

    if (error) {
      if (error.code === '23505') {
        return new Response(JSON.stringify({ error: 'CONFLICT', message: 'A template with this title already exists in this department.' }), { status: 409, headers: { 'Content-Type': 'application/json' } });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    return new Response(JSON.stringify({ id: data!.id }), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
