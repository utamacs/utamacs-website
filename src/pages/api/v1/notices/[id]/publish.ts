export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: notice } = await sb
      .from('notices')
      .select('id, is_published, created_by')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!notice) {
      return new Response(JSON.stringify({ error: 'Notice not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if ((notice as any).is_published) {
      return new Response(JSON.stringify({ error: 'Notice is already published' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    const now = new Date().toISOString();
    const { data, error } = await sb
      .from('notices')
      .update({ is_published: true, published_at: now })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'notices', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { is_published: true, published_at: now },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// Unpublish (take down a notice without deleting it)
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('notices')
      .update({ is_published: false, published_at: null })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: 'Notice not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'notices', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { is_published: false },
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
