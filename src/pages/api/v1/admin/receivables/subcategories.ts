export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: any) {
  return user.isAdmin ||
    ['executive','secretary','president'].includes(user.portalRole ?? '') ||
    ['executive','admin'].includes(user.role ?? '');
}

const VALID_CALC  = new Set(['fixed','per_sqft','per_unit','variable']);
const VALID_FREQ  = new Set(['monthly','quarterly','half_yearly','annually','one_time']);
const VALID_GST   = new Set([0, 5, 12, 18]);

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const categoryId = url.searchParams.get('category_id') ?? '';

    const sb = getSupabaseServiceClient();
    let q = sb
      .from('receivable_subcategories')
      .select('id, category_id, name, calculation_type, amount, frequency, apply_to_wings, gst_rate, is_active, display_order, created_at, receivable_categories(name)')
      .eq('society_id', SOCIETY_ID)
      .order('display_order')
      .order('name');

    if (categoryId && UUID_RE.test(categoryId)) q = (q as any).eq('category_id', categoryId);

    const { data, error } = await q;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json({ subcategories: data ?? [] });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json();
    const name = String(body.name ?? '').trim();
    if (!name || name.length > 100) return Response.json({ error: 'VALIDATION', message: 'invalid name' }, { status: 400 });
    if (!UUID_RE.test(body.category_id ?? '')) return Response.json({ error: 'VALIDATION', message: 'valid category_id required' }, { status: 400 });
    if (!VALID_CALC.has(body.calculation_type)) return Response.json({ error: 'VALIDATION', message: 'invalid calculation_type' }, { status: 400 });
    if (!VALID_FREQ.has(body.frequency)) return Response.json({ error: 'VALIDATION', message: 'invalid frequency' }, { status: 400 });
    if (!VALID_GST.has(Number(body.gst_rate ?? 0))) return Response.json({ error: 'VALIDATION', message: 'gst_rate must be 0, 5, 12, or 18' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('receivable_subcategories')
      .insert({
        society_id:       SOCIETY_ID,
        category_id:      body.category_id,
        name,
        calculation_type: body.calculation_type ?? 'fixed',
        amount:           body.amount != null ? Number(body.amount) : null,
        frequency:        body.frequency ?? 'monthly',
        apply_to_wings:   Array.isArray(body.apply_to_wings) && body.apply_to_wings.length ? body.apply_to_wings : null,
        gst_rate:         Number(body.gst_rate ?? 0),
        is_active:        body.is_active !== false,
        display_order:    Number(body.display_order ?? 0),
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json({ subcategory: data }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json();
    if (!UUID_RE.test(body.id ?? '')) return Response.json({ error: 'VALIDATION', message: 'valid id required' }, { status: 400 });

    const update: Record<string, unknown> = {};
    if (body.name !== undefined) {
      const name = String(body.name).trim();
      if (!name || name.length > 100) return Response.json({ error: 'VALIDATION', message: 'invalid name' }, { status: 400 });
      update.name = name;
    }
    if (body.category_id !== undefined) {
      if (!UUID_RE.test(body.category_id)) return Response.json({ error: 'VALIDATION', message: 'invalid category_id' }, { status: 400 });
      update.category_id = body.category_id;
    }
    if (body.calculation_type !== undefined) {
      if (!VALID_CALC.has(body.calculation_type)) return Response.json({ error: 'VALIDATION', message: 'invalid calculation_type' }, { status: 400 });
      update.calculation_type = body.calculation_type;
    }
    if (body.amount !== undefined) update.amount = body.amount != null ? Number(body.amount) : null;
    if (body.frequency !== undefined) {
      if (!VALID_FREQ.has(body.frequency)) return Response.json({ error: 'VALIDATION', message: 'invalid frequency' }, { status: 400 });
      update.frequency = body.frequency;
    }
    if (body.apply_to_wings !== undefined) update.apply_to_wings = Array.isArray(body.apply_to_wings) && body.apply_to_wings.length ? body.apply_to_wings : null;
    if (body.gst_rate !== undefined) {
      if (!VALID_GST.has(Number(body.gst_rate))) return Response.json({ error: 'VALIDATION', message: 'invalid gst_rate' }, { status: 400 });
      update.gst_rate = Number(body.gst_rate);
    }
    if (body.is_active !== undefined) update.is_active = Boolean(body.is_active);
    if (body.display_order !== undefined) update.display_order = Number(body.display_order);

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('receivable_subcategories')
      .update(update)
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    if (!data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    return Response.json({ subcategory: data });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'valid id required' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('receivable_subcategories')
      .delete()
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) {
      if (error.code === '23503') return Response.json({ error: 'CONFLICT', message: 'Sub-category has a late fee rule — delete the rule first' }, { status: 409 });
      throw Object.assign(new Error(error.message), { status: 500 });
    }
    return Response.json({ ok: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
