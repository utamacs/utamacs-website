export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — merged platform audit_logs + hoto_audit_log, sorted by created_at DESC.
// source=platform | hoto | all (default all)
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    if (user.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const action       = url.searchParams.get('action');
    const resourceType = url.searchParams.get('resource_type');
    const userId       = url.searchParams.get('user_id');
    const from         = url.searchParams.get('from');
    const to           = url.searchParams.get('to');
    const source       = url.searchParams.get('source') ?? 'all'; // 'platform' | 'hoto' | 'all'
    const limit        = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 200);
    const offset       = parseInt(url.searchParams.get('offset') ?? '0');

    const results: any[] = [];
    let total = 0;

    // ── Platform audit_logs ────────────────────────────────────────────────
    if (source === 'all' || source === 'platform') {
      let q = sb
        .from('audit_logs')
        .select('id, action, resource_type, resource_id, user_id, new_values, old_values, created_at', { count: 'exact' })
        .eq('society_id', SOCIETY_ID)
        .order('created_at', { ascending: false });

      if (action)       q = q.eq('action', action);
      if (resourceType) q = q.eq('resource_type', resourceType);
      if (userId)       q = q.eq('user_id', userId);
      if (from)         q = q.gte('created_at', from);
      if (to)           q = q.lte('created_at', to);

      if (source === 'platform') {
        q = q.range(offset, offset + limit - 1);
        const { data, error, count } = await q;
        if (error) throw Object.assign(new Error(error.message), { status: 500 });
        return new Response(JSON.stringify({ logs: (data ?? []).map(l => ({ ...l, _source: 'platform' })), total: count ?? 0 }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const { data, count } = await q.limit(limit * 2);
      results.push(...(data ?? []).map((l: any) => ({ ...l, actor_id: l.user_id, _source: 'platform' })));
      total += count ?? 0;
    }

    // ── HOTO governance audit_log ──────────────────────────────────────────
    if (source === 'all' || source === 'hoto') {
      let q = sb
        .from('hoto_audit_log')
        .select('id, action, resource_type, resource_id, actor_id, new_values, old_values, byelaw_reference, created_at', { count: 'exact' })
        .eq('society_id', SOCIETY_ID)
        .order('created_at', { ascending: false });

      if (action)       q = q.eq('action', action);
      if (resourceType) q = q.eq('resource_type', resourceType);
      if (userId)       q = q.eq('actor_id', userId);
      if (from)         q = q.gte('created_at', from);
      if (to)           q = q.lte('created_at', to);

      if (source === 'hoto') {
        q = q.range(offset, offset + limit - 1);
        const { data, error, count } = await q;
        if (error) throw Object.assign(new Error(error.message), { status: 500 });
        return new Response(JSON.stringify({ logs: (data ?? []).map(l => ({ ...l, user_id: l.actor_id, _source: 'hoto' })), total: count ?? 0 }), {
          headers: { 'Content-Type': 'application/json' },
        });
      }

      const { data, count } = await q.limit(limit * 2);
      results.push(...(data ?? []).map((l: any) => ({ ...l, user_id: l.actor_id, _source: 'hoto' })));
      total += count ?? 0;
    }

    // Merge, sort, paginate
    results.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    const page = results.slice(offset, offset + limit);

    return new Response(JSON.stringify({ logs: page, total, sources: source }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
