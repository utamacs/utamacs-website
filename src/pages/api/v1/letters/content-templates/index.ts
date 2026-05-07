export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_CATEGORIES = ['noc', 'membership', 'financial', 'notice', 'general', 'legal'] as const;

// GET /api/v1/letters/content-templates — list all available content templates
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const category = url.searchParams.get('category');

    let query = sb
      .from('letter_content_templates')
      .select('id, name, category, subject, body_md, variables, is_built_in, created_at')
      .or(`is_built_in.eq.true,society_id.eq.${SOCIETY_ID}`)
      .eq('is_active', true)
      .order('is_built_in', { ascending: false })
      .order('category')
      .order('name');

    if (category && VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      query = query.eq('category', category);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/letters/content-templates — create custom template (exec only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as Record<string, unknown>;
    const name    = sanitizePlainText(String(body.name ?? '')).trim();
    const category = String(body.category ?? '');
    const subject = sanitizePlainText(String(body.subject ?? '')).trim();
    const body_md = String(body.body_md ?? '').trim();

    if (!name) return Response.json({ error: 'VALIDATION', message: 'name required' }, { status: 400 });
    if (!VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      return Response.json({ error: 'VALIDATION', message: `category must be one of: ${VALID_CATEGORIES.join(', ')}` }, { status: 400 });
    }
    if (!subject) return Response.json({ error: 'VALIDATION', message: 'subject required' }, { status: 400 });
    if (!body_md) return Response.json({ error: 'VALIDATION', message: 'body_md required' }, { status: 400 });

    // Extract {{variables}} from body_md
    const variables = [...new Set([...(body_md.matchAll(/\{\{([^}]+)\}\}/g))].map(m => m[1].trim()))];

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('letter_content_templates')
      .insert({
        society_id: SOCIETY_ID,
        name: name.slice(0, 150),
        category,
        subject: subject.slice(0, 300),
        body_md,
        variables,
        is_built_in: false,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
