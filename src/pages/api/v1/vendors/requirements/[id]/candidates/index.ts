export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list candidates for a requirement (auth: vendor.view)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.view');

    const reqId = params.id!;
    const sb = getSupabaseServiceClient();

    // Verify requirement belongs to society
    const { data: req } = await sb
      .from('vendor_requirements')
      .select('id')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!req) return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });

    const { data, error } = await sb
      .from('vendor_candidates')
      .select('*')
      .eq('requirement_id', reqId)
      .order('submitted_at', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — add a candidate to a requirement (auth: vendor.create, status must be OPEN_FOR_QUOTES or earlier)
// Body: { vendor_name, contact_person?, contact_email?, contact_phone?, site_visited?, quote_monthly?, quote_setup? }
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'vendor.create');

    const reqId = params.id!;
    const sb = getSupabaseServiceClient();

    const { data: req } = await sb
      .from('vendor_requirements')
      .select('id, status')
      .eq('id', reqId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!req) return Response.json({ error: 'NOT_FOUND', message: 'Vendor requirement not found' }, { status: 404 });

    const allowedStatuses = ['DRAFT', 'OPEN_FOR_QUOTES'];
    if (!allowedStatuses.includes((req as any).status)) {
      return Response.json({
        error: 'CONFLICT',
        message: 'Candidates can only be added in DRAFT or OPEN_FOR_QUOTES status',
      }, { status: 409 });
    }

    const body = await request.json() as {
      vendor_name?: string;
      contact_person?: string;
      contact_email?: string;
      contact_phone?: string;
      site_visited?: boolean;
      quote_monthly?: number;
      quote_setup?: number;
    };

    if (!body.vendor_name?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'vendor_name is required' }, { status: 400 });
    }

    const id = `VC-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

    const { data, error } = await sb.from('vendor_candidates').insert({
      id,
      requirement_id: reqId,
      vendor_name: body.vendor_name.trim(),
      contact_person: body.contact_person?.trim() ?? null,
      contact_email: body.contact_email?.trim() ?? null,
      contact_phone: body.contact_phone?.trim() ?? null,
      site_visited: body.site_visited ?? false,
      quote_monthly: body.quote_monthly ?? null,
      quote_setup: body.quote_setup ?? null,
      submitted_at: new Date().toISOString(),
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'vendor_candidates', resourceId: id,
      ip: extractClientIP(request),
      newValues: { requirement_id: reqId, vendor_name: body.vendor_name.trim() },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
