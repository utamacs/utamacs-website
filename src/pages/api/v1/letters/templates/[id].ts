export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExecOrAdmin(role: string) {
  if (!['executive', 'admin'].includes(role)) {
    throw Object.assign(new Error('Only executive and admin can manage letterhead templates'), { status: 403 });
  }
}

export const GET: APIRoute = async ({ request, params }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('letterhead_templates')
      .select(`
        *,
        letterhead_committee_members (id, name, designation, show_in_header, show_in_signature, display_order),
        letterhead_dynamic_fields (id, field_key, display_label, field_type, placeholder, is_required, display_order)
      `)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: error.code === 'PGRST116' ? 404 : 500 });

    // Sort relations by display_order
    if (data.letterhead_committee_members) {
      data.letterhead_committee_members.sort((a: any, b: any) => a.display_order - b.display_order);
    }
    if (data.letterhead_dynamic_fields) {
      data.letterhead_dynamic_fields.sort((a: any, b: any) => a.display_order - b.display_order);
    }

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    requireExecOrAdmin(user.role);

    const body = await request.json() as Record<string, unknown>;
    const {
      name, logo_path, society_name, society_tagline, society_reg_no,
      society_address_line1, society_address_line2, society_address_line3,
      footer_website, footer_phone, footer_email,
      subsequent_page_header, closing_line1, closing_line2,
      is_default, committee_members, dynamic_fields,
      logo_height_px, logo_valign, body_font_size_pt, header_font_size_pt, addr_col_width_px,
    } = body;

    const sb = getSupabaseServiceClient();

    // Verify template belongs to this society
    const { data: existing, error: checkErr } = await sb
      .from('letterhead_templates')
      .select('id, is_default')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (checkErr || !existing) {
      return new Response(JSON.stringify({ error: 'Template not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // If setting this as default, unset any other default
    if (is_default && !existing.is_default) {
      await sb.from('letterhead_templates')
        .update({ is_default: false })
        .eq('society_id', SOCIETY_ID)
        .eq('is_default', true);
    }

    const updatePayload: Record<string, unknown> = {};
    if (name !== undefined) updatePayload.name = sanitizePlainText(String(name));
    if (logo_path !== undefined) updatePayload.logo_path = sanitizePlainText(String(logo_path));
    if (society_name !== undefined) updatePayload.society_name = sanitizePlainText(String(society_name));
    if (society_tagline !== undefined) updatePayload.society_tagline = sanitizePlainText(String(society_tagline));
    if (society_reg_no !== undefined) updatePayload.society_reg_no = sanitizePlainText(String(society_reg_no));
    if (society_address_line1 !== undefined) updatePayload.society_address_line1 = sanitizePlainText(String(society_address_line1));
    if (society_address_line2 !== undefined) updatePayload.society_address_line2 = sanitizePlainText(String(society_address_line2));
    if (society_address_line3 !== undefined) updatePayload.society_address_line3 = sanitizePlainText(String(society_address_line3));
    if (footer_website !== undefined) updatePayload.footer_website = sanitizePlainText(String(footer_website));
    if (footer_phone !== undefined) updatePayload.footer_phone = sanitizePlainText(String(footer_phone));
    if (footer_email !== undefined) updatePayload.footer_email = sanitizePlainText(String(footer_email));
    if (subsequent_page_header !== undefined) updatePayload.subsequent_page_header = sanitizePlainText(String(subsequent_page_header));
    if (closing_line1 !== undefined) updatePayload.closing_line1 = sanitizePlainText(String(closing_line1));
    if (closing_line2 !== undefined) updatePayload.closing_line2 = sanitizePlainText(String(closing_line2));
    if (is_default !== undefined) updatePayload.is_default = Boolean(is_default);
    if (logo_height_px !== undefined) updatePayload.logo_height_px = Math.min(400, Math.max(60, Number(logo_height_px)));
    if (logo_valign !== undefined && ['top','center','bottom'].includes(String(logo_valign))) updatePayload.logo_valign = String(logo_valign);
    if (body_font_size_pt !== undefined) updatePayload.body_font_size_pt = Math.min(14, Math.max(8, Number(body_font_size_pt)));
    if (header_font_size_pt !== undefined) updatePayload.header_font_size_pt = Math.min(12, Math.max(6, Number(header_font_size_pt)));
    if (addr_col_width_px !== undefined) updatePayload.addr_col_width_px = Math.min(300, Math.max(140, Number(addr_col_width_px)));

    const { error: updateErr } = await sb
      .from('letterhead_templates')
      .update(updatePayload)
      .eq('id', params.id!);

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    // Replace committee members if provided
    if (Array.isArray(committee_members)) {
      await sb.from('letterhead_committee_members').delete().eq('template_id', params.id!);
      if (committee_members.length > 0) {
        const rows = (committee_members as Array<Record<string, unknown>>).map((m, i) => ({
          template_id: params.id!,
          name: sanitizePlainText(String(m.name ?? '')),
          designation: sanitizePlainText(String(m.designation ?? '')),
          show_in_header: m.show_in_header !== false,
          show_in_signature: m.show_in_signature !== false,
          display_order: typeof m.display_order === 'number' ? m.display_order : i + 1,
        }));
        await sb.from('letterhead_committee_members').insert(rows);
      }
    }

    // Replace dynamic fields if provided
    if (Array.isArray(dynamic_fields)) {
      await sb.from('letterhead_dynamic_fields').delete().eq('template_id', params.id!);
      if (dynamic_fields.length > 0) {
        const VALID_TYPES = ['text', 'textarea', 'date', 'richtext'];
        const rows = (dynamic_fields as Array<Record<string, unknown>>).map((f, i) => ({
          template_id: params.id!,
          field_key: sanitizePlainText(String(f.field_key ?? '')),
          display_label: sanitizePlainText(String(f.display_label ?? '')),
          field_type: VALID_TYPES.includes(String(f.field_type)) ? String(f.field_type) : 'text',
          placeholder: f.placeholder ? sanitizePlainText(String(f.placeholder)) : null,
          is_required: f.is_required !== false,
          display_order: typeof f.display_order === 'number' ? f.display_order : i + 1,
        }));
        await sb.from('letterhead_dynamic_fields').insert(rows);
      }
    }

    // Return updated template with all relations
    const { data: updated } = await sb
      .from('letterhead_templates')
      .select(`
        *,
        letterhead_committee_members (id, name, designation, show_in_header, show_in_signature, display_order),
        letterhead_dynamic_fields (id, field_key, display_label, field_type, placeholder, is_required, display_order)
      `)
      .eq('id', params.id!)
      .single();

    return new Response(JSON.stringify(updated), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    requireExecOrAdmin(user.role);

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('letterhead_templates')
      .select('id, is_default')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) {
      return new Response(JSON.stringify({ error: 'Template not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (existing.is_default) {
      return new Response(JSON.stringify({ error: 'Cannot delete the default template. Set another template as default first.' }), {
        status: 409, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Soft-delete: mark inactive (preserves letter history)
    const { error } = await sb
      .from('letterhead_templates')
      .update({ is_active: false })
      .eq('id', params.id!);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
