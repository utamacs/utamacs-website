export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// POST /api/v1/letters/content-templates/render
// Renders a template with member data auto-filled.
// Body: { template_id, member_id? (profile uuid), extra_vars?: Record<string,string> }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as {
      template_id?: string;
      member_id?: string;
      extra_vars?: Record<string, string>;
    };

    if (!body.template_id || !UUID_RE.test(body.template_id)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid template_id required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Fetch template
    const { data: template, error: tErr } = await sb
      .from('letter_content_templates')
      .select('id, name, subject, body_md, variables')
      .or(`is_built_in.eq.true,society_id.eq.${SOCIETY_ID}`)
      .eq('id', body.template_id)
      .single();

    if (tErr || !template) return Response.json({ error: 'NOT_FOUND', message: 'Template not found' }, { status: 404 });

    // Build variable map from member data if member_id provided
    const vars: Record<string, string> = {};

    if (body.member_id && UUID_RE.test(body.member_id)) {
      const { data: profile } = await sb
        .from('profiles')
        .select(`
          id, full_name, email,
          units!profiles_unit_id_fkey(unit_number, block, sq_ft),
          created_at
        `)
        .eq('id', body.member_id)
        .eq('society_id', SOCIETY_ID)
        .single();

      if (profile) {
        const p = profile as any;
        vars['member_name']   = p.full_name ?? '';
        vars['member_email']  = p.email ?? '';
        vars['unit_number']   = p.units?.unit_number ?? '';
        vars['block']         = p.units?.block ?? '';
        vars['sq_ft']         = p.units?.sq_ft ? String(p.units.sq_ft) : '';
        vars['member_since']  = p.created_at
          ? new Date(p.created_at).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })
          : '';
      }
    }

    // Fetch society info for placeholders
    const { data: society } = await sb
      .from('societies')
      .select('name')
      .eq('id', SOCIETY_ID)
      .single();

    vars['society_name'] = (society as any)?.name ?? 'UTA MACS';
    vars['today_date']   = new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' });

    // Merge extra_vars (caller-provided overrides and additional fields)
    if (body.extra_vars) {
      Object.assign(vars, body.extra_vars);
    }

    // Substitute {{variable}} placeholders
    let rendered_body = (template as any).body_md as string;
    let rendered_subject = (template as any).subject as string;
    for (const [key, value] of Object.entries(vars)) {
      const re = new RegExp(`\\{\\{${key}\\}\\}`, 'g');
      rendered_body    = rendered_body.replace(re, value);
      rendered_subject = rendered_subject.replace(re, value);
    }

    // Identify any unfilled placeholders
    const unfilled = [...rendered_body.matchAll(/\{\{([^}]+)\}\}/g)].map(m => m[1]);

    return Response.json({
      template_id: body.template_id,
      rendered_subject,
      rendered_body,
      unfilled_variables: [...new Set(unfilled)],
      variables_used: vars,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
