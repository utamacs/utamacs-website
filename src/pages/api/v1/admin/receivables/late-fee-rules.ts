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
      .from('late_fee_rules')
      .select(`
        id, grace_period_days, fee_type, fee_amount, fee_frequency,
        max_fee_cap, waiver_type, created_at,
        receivable_subcategories(id, name, receivable_categories(name))
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at');

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json({ rules: data ?? [] });
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
    if (!UUID_RE.test(body.subcategory_id ?? '')) return Response.json({ error: 'VALIDATION', message: 'valid subcategory_id required' }, { status: 400 });
    if (!['fixed','percentage'].includes(body.fee_type)) return Response.json({ error: 'VALIDATION', message: 'fee_type must be fixed or percentage' }, { status: 400 });
    if (!['one_time','monthly'].includes(body.fee_frequency ?? 'one_time')) return Response.json({ error: 'VALIDATION', message: 'invalid fee_frequency' }, { status: 400 });
    if (!['none','full','partial'].includes(body.waiver_type ?? 'none')) return Response.json({ error: 'VALIDATION', message: 'invalid waiver_type' }, { status: 400 });
    const feeAmount = Number(body.fee_amount ?? 0);
    if (isNaN(feeAmount) || feeAmount < 0) return Response.json({ error: 'VALIDATION', message: 'fee_amount must be >= 0' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('late_fee_rules')
      .insert({
        society_id:        SOCIETY_ID,
        subcategory_id:    body.subcategory_id,
        grace_period_days: Math.max(0, Number(body.grace_period_days ?? 0)),
        fee_type:          body.fee_type,
        fee_amount:        feeAmount,
        fee_frequency:     body.fee_frequency ?? 'one_time',
        max_fee_cap:       body.max_fee_cap != null ? Number(body.max_fee_cap) : null,
        waiver_type:       body.waiver_type ?? 'none',
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') return Response.json({ error: 'CONFLICT', message: 'A rule already exists for this sub-category' }, { status: 409 });
      throw Object.assign(new Error(error.message), { status: 500 });
    }
    return Response.json({ rule: data }, { status: 201 });
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
    if (body.grace_period_days !== undefined) update.grace_period_days = Math.max(0, Number(body.grace_period_days));
    if (body.fee_type !== undefined) {
      if (!['fixed','percentage'].includes(body.fee_type)) return Response.json({ error: 'VALIDATION', message: 'invalid fee_type' }, { status: 400 });
      update.fee_type = body.fee_type;
    }
    if (body.fee_amount !== undefined) update.fee_amount = Math.max(0, Number(body.fee_amount));
    if (body.fee_frequency !== undefined) {
      if (!['one_time','monthly'].includes(body.fee_frequency)) return Response.json({ error: 'VALIDATION', message: 'invalid fee_frequency' }, { status: 400 });
      update.fee_frequency = body.fee_frequency;
    }
    if (body.max_fee_cap !== undefined) update.max_fee_cap = body.max_fee_cap != null ? Number(body.max_fee_cap) : null;
    if (body.waiver_type !== undefined) {
      if (!['none','full','partial'].includes(body.waiver_type)) return Response.json({ error: 'VALIDATION', message: 'invalid waiver_type' }, { status: 400 });
      update.waiver_type = body.waiver_type;
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('late_fee_rules')
      .update(update)
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    if (!data) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    return Response.json({ rule: data });
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
      .from('late_fee_rules')
      .delete()
      .eq('id', id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json({ ok: true });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
