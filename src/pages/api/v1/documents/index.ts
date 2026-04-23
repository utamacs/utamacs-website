export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_CATEGORIES = ['Bylaws', 'Minutes', 'Financial', 'Legal', 'Circulars', 'Forms', 'Other'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const category = url.searchParams.get('category');

    let query = sb
      .from('documents')
      .select('id, title, description, category, file_name, mime_type, file_size_bytes, version, is_public, requires_role, created_at, updated_at, profiles(full_name)')
      .eq('society_id', SOCIETY_ID)
      .order('category')
      .order('title');

    // Role-based visibility
    if (user.role === 'member') {
      query = query.or('is_public.eq.true,requires_role.eq.member');
    } else if (['executive', 'admin'].includes(user.role)) {
      // See all
    } else {
      query = query.eq('is_public', true);
    }

    if (category && VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      query = query.eq('category', category);
    }

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
      return new Response(JSON.stringify({ error: 'Only executive and admin can upload documents' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      title?: string; description?: string; category?: string;
      storage_key?: string; file_name?: string; mime_type?: string;
      file_size_bytes?: number; is_public?: boolean; requires_role?: string;
    };

    if (!body.title?.trim() || !body.storage_key?.trim() || !body.category) {
      return new Response(JSON.stringify({ error: 'title, storage_key, and category are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!VALID_CATEGORIES.includes(body.category as typeof VALID_CATEGORIES[number])) {
      return new Response(JSON.stringify({ error: `category must be one of: ${VALID_CATEGORIES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('documents')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(body.title),
        description: body.description ? sanitizePlainText(body.description) : null,
        category: body.category,
        storage_key: body.storage_key,
        file_name: body.file_name ?? null,
        mime_type: body.mime_type ?? null,
        file_size_bytes: body.file_size_bytes ?? null,
        version: 1,
        is_public: body.is_public ?? false,
        requires_role: body.requires_role ?? 'member',
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'documents', resourceId: data.id,
      ip: extractClientIP(request), newValues: { category: data.category, title: data.title },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
