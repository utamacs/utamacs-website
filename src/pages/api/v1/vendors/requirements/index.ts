export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list vendor requirements (auth: vendor.view)
// Query: status, category, q, limit (default 100)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.view');

    const url = new URL(request.url);
    const status   = url.searchParams.get('status')   ?? '';
    const category = url.searchParams.get('category') ?? '';
    const q        = url.searchParams.get('q')        ?? '';
    const limit    = Math.min(Number(url.searchParams.get('limit') ?? '100'), 200);

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('vendor_requirements')
      .select(`
        id, category, title, description, status,
        voting_opens_at, voting_closes_at, quorum_required,
        selected_vendor_id, voting_policy_committed, created_by, created_at,
        vendor_candidates(count),
        votes(count)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (status)   query = query.eq('status', status);
    if (category) query = query.eq('category', category);
    if (q)        query = query.ilike('title', `%${q}%`);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create a vendor requirement (auth: vendor.create)
// Body: { category, title, description?, quorum_required? }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.create');

    const body = await request.json() as {
      category?: string;
      title?: string;
      description?: string;
      quorum_required?: number;
    };

    if (!body.category?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'category is required' }, { status: 400 });
    }
    if (!body.title?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'title is required' }, { status: 400 });
    }

    const id = `VR-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb.from('vendor_requirements').insert({
      id,
      society_id: SOCIETY_ID,
      category: body.category.trim(),
      title: body.title.trim(),
      description: body.description?.trim() ?? null,
      quorum_required: body.quorum_required ?? 8,
      status: 'DRAFT',
      created_by: user.id,
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'CREATE',
        resource_type: 'vendor_requirements',
        resource_id: id,
        new_values: { category: body.category.trim(), title: body.title.trim() },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'CREATE', resourceType: 'vendor_requirements', resourceId: id,
        ip: extractClientIP(request),
        newValues: { category: body.category.trim(), title: body.title.trim() },
      }),
    ]);

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
