export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_STATUSES = ['NOT_STARTED','IN_PROGRESS','UNDER_REVIEW','PENDING_PRESIDENT','PENDING_SECRETARY','APPROVED','REJECTED','CLOSED'] as const;
const VALID_PRIORITIES = ['LOW','MEDIUM','HIGH','CRITICAL'] as const;

// GET — list HOTO items with optional filters
// Auth: hoto.view feature required
// Query: status, category, priority, q (title search), limit (default 50, max 200)
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.view');

    const q        = url.searchParams.get('q')?.trim() ?? '';
    const status   = url.searchParams.get('status')?.trim() ?? '';
    const category = url.searchParams.get('category')?.trim() ?? '';
    const priority = url.searchParams.get('priority')?.trim() ?? '';
    const limit    = Math.min(parseInt(url.searchParams.get('limit') ?? '50', 10) || 50, 200);

    const sb = getSupabaseServiceClient();
    let query = sb
      .from('hoto_items')
      .select(`
        id, ascenza_category, title, priority, status, deadline,
        builder_sla_date, days_overdue, responsible_role, responsible_user_id,
        rera_escalation_eligible, notice_sent, president_approved_at, secretary_approved_at,
        created_at, last_updated_at,
        hoto_required_docs(count)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('days_overdue', { ascending: false })
      .order('priority')
      .limit(limit);

    if (q) query = query.ilike('title', `%${q}%`);
    if (status && VALID_STATUSES.includes(status as typeof VALID_STATUSES[number])) {
      query = query.eq('status', status);
    }
    if (category) query = query.eq('ascenza_category', category);
    if (priority && VALID_PRIORITIES.includes(priority as typeof VALID_PRIORITIES[number])) {
      query = query.eq('priority', priority);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create a new HOTO item
// Auth: hoto.create feature required
// Body: { ascenza_category, title, description?, builder_commitment?, builder_contact?,
//         priority?, deadline?, builder_sla_date?, responsible_role?, responsible_user_id?,
//         rera_escalation_eligible? }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.create');

    const body = await request.json() as {
      ascenza_category?: string;
      title?: string;
      description?: string;
      builder_commitment?: string;
      builder_contact?: string;
      priority?: string;
      deadline?: string;
      builder_sla_date?: string;
      responsible_role?: string;
      responsible_user_id?: string;
      rera_escalation_eligible?: boolean;
    };

    if (!body.ascenza_category?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'ascenza_category is required' }, { status: 400 });
    }
    if (!body.title?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'title is required' }, { status: 400 });
    }

    const priority = body.priority ?? 'MEDIUM';
    if (!VALID_PRIORITIES.includes(priority as typeof VALID_PRIORITIES[number])) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: `priority must be one of: ${VALID_PRIORITIES.join(', ')}`,
      }, { status: 400 });
    }

    // Generate a human-readable text ID
    const id = `HOTO-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('hoto_items')
      .insert({
        id,
        society_id: SOCIETY_ID,
        ascenza_category: body.ascenza_category.trim(),
        title: body.title.trim(),
        description: body.description?.trim() ?? null,
        builder_commitment: body.builder_commitment?.trim() ?? null,
        builder_contact: body.builder_contact?.trim() ?? null,
        priority,
        status: 'NOT_STARTED',
        deadline: body.deadline ?? null,
        builder_sla_date: body.builder_sla_date ?? null,
        responsible_role: body.responsible_role ?? null,
        responsible_user_id: body.responsible_user_id ?? null,
        rera_escalation_eligible: body.rera_escalation_eligible ?? false,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'hoto_items', resourceId: id,
      ip: extractClientIP(request),
      newValues: { ascenza_category: body.ascenza_category, title: body.title, priority },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
