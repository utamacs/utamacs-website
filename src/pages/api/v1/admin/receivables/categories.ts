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

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('receivable_categories')
      .select('id, name, description, hsn_sac_code, is_active, display_order, created_at')
      .eq('society_id', SOCIETY_ID)
      .order('display_order')
      .order('name');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json({ categories: data ?? [] });
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
    if (!name) return Response.json({ error: 'VALIDATION', message: 'name is required' }, { status: 400 });
    if (name.length > 100) return Response.json({ error: 'VALIDATION', message: 'name too long' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('receivable_categories')
      .insert({
        society_id:    SOCIETY_ID,
        name,
        description:   String(body.description ?? '').trim() || null,
        hsn_sac_code:  String(body.hsn_sac_code ?? '').trim() || null,
        is_active:     body.is_active !== false,
        display_order: Number(body.display_order ?? 0),
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') return Response.json({ error: 'CONFLICT', message: 'Category name already exists' }, { status: 409 });
      throw Object.assign(new Error(error.message), { status: 500 });
    }
    return Response.json({ category: data }, { status: 201 });
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
    if (!body.id || !UUID_RE.test(body.id)) return Response.json({ error: 'VALIDATION', message: 'valid id required' }, { status: 400 });

    const update: Record<string, unknown> = {};
    if (body.name !== undefined) {
      const name = String(body.name).trim();
      if (!name || name.length > 100) return Response.json({ error: 'VALIDATION', message: 'invalid name' }, { status: 400 });
      update.name = name;
    }
    if (body.description !== undefined) update.description = String(body.description).trim() || null;
    if (body.hsn_sac_code !== undefined) update.hsn_sac_code = String(body.hsn_sac_code).trim() || null;
    if (body.is_active !== undefined) update.is_active = Boolean(body.is_active);
    if (body.display_order !== undefined) update.display_order = Number(body.display_order);

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('receivable_categories')
      .update(update)
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    if (!data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    return Response.json({ category: data });
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
      .from('receivable_categories')
      .delete()
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) {
      if (error.code === '23503') return Response.json({ error: 'CONFLICT', message: 'Category has sub-categories — deactivate instead' }, { status: 409 });
      throw Object.assign(new Error(error.message), { status: 500 });
    }
    return Response.json({ ok: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
