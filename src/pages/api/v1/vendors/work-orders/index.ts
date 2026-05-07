export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_STATUSES = ['draft', 'issued', 'in_progress', 'completed', 'disputed', 'closed'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('work_orders')
      .select('id, title, description, status, issued_at, deadline, quoted_amount, final_amount, vendor_id, vendors(name, category), complaint_id')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (user.role === 'vendor') {
      const { data: profile } = await sb.from('vendors').select('id').eq('email', user.id).single();
      if (!profile) {
        return new Response(JSON.stringify([]), { headers: { 'Content-Type': 'application/json' } });
      }
      query = query.eq('vendor_id', profile.id).in('status', ['issued', 'in_progress']);
    } else if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const vendorId = url.searchParams.get('vendor_id');
    if (vendorId && user.role !== 'vendor') query = query.eq('vendor_id', vendorId);

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
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      vendor_id?: string; title?: string; description?: string;
      complaint_id?: string; deadline?: string; quoted_amount?: number;
    };

    if (!body.vendor_id || !body.title?.trim()) {
      return new Response(JSON.stringify({ error: 'vendor_id and title are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('work_orders')
      .insert({
        society_id: SOCIETY_ID,
        vendor_id: body.vendor_id,
        title: sanitizePlainText(body.title),
        description: body.description ? sanitizePlainText(body.description) : null,
        complaint_id: body.complaint_id ?? null,
        status: 'draft',
        issued_at: new Date().toISOString(),
        deadline: body.deadline ?? null,
        quoted_amount: body.quoted_amount ?? null,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'work_orders', resourceId: data.id,
      ip: extractClientIP(request), newValues: { title: data.title, vendor_id: data.vendor_id },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
