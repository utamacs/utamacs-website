import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('vendors')
      .select('id, name, category, contact_person, email, gstin, pan, contract_start, contract_end, is_active')
      .eq('society_id', SOCIETY_ID)
      .order('name');

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
      name?: string; category?: string; contact_person?: string;
      phone?: string; email?: string; gstin?: string; pan?: string;
      contract_start?: string; contract_end?: string;
    };

    if (!body.name?.trim() || !body.category) {
      return new Response(JSON.stringify({ error: 'name and category are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('vendors')
      .insert({
        society_id: SOCIETY_ID,
        name: sanitizePlainText(body.name),
        category: body.category,
        contact_person: body.contact_person ? sanitizePlainText(body.contact_person) : null,
        phone: body.phone ?? null,
        email: body.email ?? null,
        gstin: body.gstin ?? null,
        pan: body.pan ?? null,
        contract_start: body.contract_start ?? null,
        contract_end: body.contract_end ?? null,
        is_active: true,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'vendors', resourceId: data.id,
      ip: extractClientIP(request), newValues: { name: data.name, category: data.category },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
