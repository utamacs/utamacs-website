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

export const GET: APIRoute = async ({ request }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: templates, error: tErr } = await sb
      .from('letterhead_templates')
      .select('id, name, is_default, is_active, subsequent_page_header, closing_line1, closing_line2, created_at, updated_at')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true)
      .order('is_default', { ascending: false })
      .order('name');

    if (tErr) throw Object.assign(new Error(tErr.message), { status: 500 });

    return new Response(JSON.stringify(templates ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
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
      logo_height_px, logo_valign, logo_width_px, logo_halign,
      body_font_size_pt, header_font_size_pt, addr_col_width_px,
    } = body;

    if (!name || typeof name !== 'string') {
      return new Response(JSON.stringify({ error: 'name is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    // If this template is being set as default, unset any existing default
    if (is_default) {
      await sb.from('letterhead_templates')
        .update({ is_default: false })
        .eq('society_id', SOCIETY_ID)
        .eq('is_default', true);
    }

    const { data: tmpl, error: tErr } = await sb
      .from('letterhead_templates')
      .insert({
        society_id: SOCIETY_ID,
        name: sanitizePlainText(String(name)),
        logo_path: logo_path ? sanitizePlainText(String(logo_path)) : 'UTA-MACS-Logo.png',
        society_name: society_name ? sanitizePlainText(String(society_name)) : 'Urban Trilla MACS',
        society_tagline: society_tagline ? sanitizePlainText(String(society_tagline)) : 'COMMUNITY • CARE • MAINTENANCE',
        society_reg_no: society_reg_no ? sanitizePlainText(String(society_reg_no)) : 'TG/RRD/MACS/2026-15/FOW & M',
        society_address_line1: society_address_line1 ? sanitizePlainText(String(society_address_line1)) : 'SY NO4 25/2/1, KONDAKAL(V),',
        society_address_line2: society_address_line2 ? sanitizePlainText(String(society_address_line2)) : 'SHANKARPALLE(M), RANGAREDDY(D),',
        society_address_line3: society_address_line3 ? sanitizePlainText(String(society_address_line3)) : '501203, TELANGANA',
        footer_website: footer_website ? sanitizePlainText(String(footer_website)) : 'www.utamacs.org',
        footer_phone: footer_phone ? sanitizePlainText(String(footer_phone)) : '+91 7032820247',
        footer_email: footer_email ? sanitizePlainText(String(footer_email)) : 'urbantrillaresidents@gmail.com',
        subsequent_page_header: subsequent_page_header ? sanitizePlainText(String(subsequent_page_header)) : 'Urban Trilla MACS — Continued',
        closing_line1: closing_line1 ? sanitizePlainText(String(closing_line1)) : 'Thanking you!',
        closing_line2: closing_line2 ? sanitizePlainText(String(closing_line2)) : 'Yours sincerely',
        is_default: Boolean(is_default),
        ...(logo_height_px !== undefined && { logo_height_px: Math.min(400, Math.max(60, Number(logo_height_px))) }),
        ...(logo_valign !== undefined && ['top','center','bottom'].includes(String(logo_valign)) && { logo_valign: String(logo_valign) }),
        ...(logo_width_px !== undefined && { logo_width_px: Math.min(800, Math.max(0, Number(logo_width_px))) }),
        ...(logo_halign !== undefined && ['left','center','right'].includes(String(logo_halign)) && { logo_halign: String(logo_halign) }),
        ...(body_font_size_pt !== undefined && { body_font_size_pt: Math.min(14, Math.max(8, Number(body_font_size_pt))) }),
        ...(header_font_size_pt !== undefined && { header_font_size_pt: Math.min(12, Math.max(6, Number(header_font_size_pt))) }),
        ...(addr_col_width_px !== undefined && { addr_col_width_px: Math.min(300, Math.max(140, Number(addr_col_width_px))) }),
        created_by: user.id,
      })
      .select()
      .single();

    if (tErr) throw Object.assign(new Error(tErr.message), { status: 500 });

    // Insert committee members if provided
    if (Array.isArray(committee_members) && committee_members.length > 0) {
      const memberRows = (committee_members as Array<Record<string, unknown>>).map((m, i) => ({
        template_id: tmpl.id,
        name: sanitizePlainText(String(m.name ?? '')),
        designation: sanitizePlainText(String(m.designation ?? '')),
        show_in_header: m.show_in_header !== false,
        show_in_signature: m.show_in_signature !== false,
        display_order: typeof m.display_order === 'number' ? m.display_order : i + 1,
      }));
      await sb.from('letterhead_committee_members').insert(memberRows);
    }

    // Insert dynamic fields if provided
    if (Array.isArray(dynamic_fields) && dynamic_fields.length > 0) {
      const VALID_TYPES = ['text', 'textarea', 'date', 'richtext'];
      const fieldRows = (dynamic_fields as Array<Record<string, unknown>>).map((f, i) => ({
        template_id: tmpl.id,
        field_key: sanitizePlainText(String(f.field_key ?? '')),
        display_label: sanitizePlainText(String(f.display_label ?? '')),
        field_type: VALID_TYPES.includes(String(f.field_type)) ? String(f.field_type) : 'text',
        placeholder: f.placeholder ? sanitizePlainText(String(f.placeholder)) : null,
        is_required: f.is_required !== false,
        display_order: typeof f.display_order === 'number' ? f.display_order : i + 1,
      }));
      await sb.from('letterhead_dynamic_fields').insert(fieldRows);
    }

    // Return full template with relations
    const { data: full } = await sb
      .from('letterhead_templates')
      .select('*, letterhead_committee_members(*), letterhead_dynamic_fields(*)')
      .eq('id', tmpl.id)
      .single();

    return new Response(JSON.stringify(full), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
