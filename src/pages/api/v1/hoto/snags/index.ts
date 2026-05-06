export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list snag items (auth: snag.view)
// Query: status, severity, snag_scope, category, q, limit (default 200)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'snag.view');

    const url = new URL(request.url);
    const status    = url.searchParams.get('status')     ?? '';
    const severity  = url.searchParams.get('severity')   ?? '';
    const scope     = url.searchParams.get('snag_scope') ?? '';
    const category  = url.searchParams.get('category')   ?? '';
    const q         = url.searchParams.get('q')          ?? '';
    const limit     = Math.min(Number(url.searchParams.get('limit') ?? '200'), 500);

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('snag_items')
      .select(`
        id, snag_scope, category, subcategory, location, flat_number,
        description, severity, status, builder_ref,
        builder_committed_date, builder_sla_days_overdue,
        notice_sent, reported_date, created_at,
        reported_by, responsible_user_id, verified_by,
        snag_source, audit_ref_no, audit_source, audit_date,
        compliance_requirement, recommendation, equipment_machinery,
        expected_closure_date, responsible_person_name
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('deleted', false)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (status)   query = query.eq('status', status);
    if (severity) query = query.eq('severity', severity);
    if (scope)    query = query.eq('snag_scope', scope);
    if (category) query = query.eq('category', category);
    if (q)        query = query.or(`description.ilike.%${q}%,location.ilike.%${q}%,flat_number.ilike.%${q}%`);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create a snag item (auth: snag.create)
// Body: { snag_scope, category, subcategory?, location, flat_number?, description, severity?, builder_ref?, builder_committed_date? }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'snag.create');

    const body = await request.json() as {
      snag_scope?: string;
      category?: string;
      subcategory?: string;
      location?: string;
      flat_number?: string;
      description?: string;
      severity?: string;
      builder_ref?: string;
      builder_committed_date?: string;
    };

    if (!body.category?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'category is required' }, { status: 400 });
    }
    if (!body.location?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'location is required' }, { status: 400 });
    }
    if (!body.description?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'description is required' }, { status: 400 });
    }

    const VALID_SCOPES = ['COMMON_AREA', 'APARTMENT'];
    const VALID_SEVERITIES = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
    const scope = body.snag_scope ?? 'COMMON_AREA';
    const severity = body.severity ?? 'MEDIUM';

    if (!VALID_SCOPES.includes(scope)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: `snag_scope must be one of: ${VALID_SCOPES.join(', ')}` }, { status: 400 });
    }
    if (!VALID_SEVERITIES.includes(severity)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: `severity must be one of: ${VALID_SEVERITIES.join(', ')}` }, { status: 400 });
    }
    if (scope === 'APARTMENT' && !body.flat_number?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'flat_number is required for APARTMENT scope' }, { status: 400 });
    }

    const id = `SNAG-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb.from('snag_items').insert({
      id,
      society_id: SOCIETY_ID,
      snag_scope: scope,
      category: body.category.trim(),
      subcategory: body.subcategory?.trim() ?? null,
      location: body.location.trim(),
      flat_number: body.flat_number?.trim() ?? null,
      description: body.description.trim(),
      severity,
      status: 'OPEN',
      builder_ref: body.builder_ref?.trim() ?? null,
      builder_committed_date: body.builder_committed_date ?? null,
      reported_by: user.id,
      reported_date: new Date().toISOString().slice(0, 10),
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'CREATE',
        resource_type: 'snag_items',
        resource_id: id,
        new_values: { category: body.category.trim(), location: body.location.trim(), severity },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'CREATE', resourceType: 'snag_items', resourceId: id,
        ip: extractClientIP(request),
        newValues: { category: body.category.trim(), severity },
      }),
    ]);

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
