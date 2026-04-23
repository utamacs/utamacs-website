export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { permissionService } from '@lib/services/index';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'complaints', 'read',
    );

    const sb = getSupabaseServiceClient();
    let query = sb.from('complaints').select(`
      id, ticket_number, title, category, priority, status, raised_by,
      assigned_to, unit_id, sla_hours, sla_deadline, created_at, updated_at,
      units(unit_number)
    `).eq('society_id', SOCIETY_ID).order('created_at', { ascending: false });

    // Members only see their own complaints
    if (user.role === 'member') {
      query = query.eq('raised_by', user.id);
    }

    const statusFilter = url.searchParams.get('status');
    if (statusFilter) query = query.eq('status', statusFilter);

    const categoryFilter = url.searchParams.get('category');
    if (categoryFilter) query = query.eq('category', categoryFilter);

    const page = parseInt(url.searchParams.get('page') ?? '1');
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '20'), 50);
    const from = (page - 1) * limit;
    query = query.range(from, from + limit - 1);

    const { data, error, count } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ data, total: count, page, limit }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    permissionService.authorize(
      { userId: user.id, role: user.role, societyId: user.societyId },
      'complaints', 'create',
    );

    const body = await request.json();
    const { title, description, category, priority, unit_id } = body as Record<string, string>;

    if (!title || !category || !unit_id) {
      return new Response(JSON.stringify({ error: 'title, category and unit_id are required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // Fetch SLA config for this category and priority
    const { data: slaConfig } = await sb
      .from('complaint_sla_config')
      .select('sla_hours')
      .eq('society_id', SOCIETY_ID)
      .eq('category', category)
      .eq('priority', priority ?? 'Medium')
      .single();
    const slaHours: number = slaConfig?.sla_hours ?? 48;

    const { data, error } = await sb
      .from('complaints')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(title),
        description: description ? sanitizePlainText(description) : null,
        category,
        priority: priority ?? 'Medium',
        status: 'Open',
        raised_by: user.id,
        unit_id,
        sla_hours: slaHours,
        sla_deadline: new Date(Date.now() + slaHours * 3_600_000).toISOString(),
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      userId: user.id,
      societyId: user.societyId,
      action: 'CREATE',
      resourceType: 'complaints',
      resourceId: data.id,
      newValues: data,
      ip: extractClientIP(request),
    });

    return new Response(JSON.stringify(data), {
      status: 201,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
