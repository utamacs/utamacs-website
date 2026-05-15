export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { commitDocument, docPath } from '@lib/utils/githubDocStore';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ALLOWED_LOGO_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/svg+xml': 'svg',
  'image/webp': 'webp',
};

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin && !['executive', 'secretary', 'president'].includes(user.portalRole ?? '')) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('societies')
      .select('id, name, registration_no, address, city, state, pincode, gstin, pan, total_units, logo_key, tagline, contact_email, contact_phone, website_url, whatsapp_group_url, fiscal_year_start, timezone, currency_symbol, invoice_prefix, receipt_prefix')
      .eq('id', SOCIETY_ID)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const ct = request.headers.get('content-type') ?? '';
    let logoKey: string | undefined;
    let fields: Record<string, unknown>;

    if (ct.includes('multipart/form-data')) {
      const fd = await request.formData();
      const logoFile = fd.get('logo') as File | null;

      if (logoFile && logoFile.size > 0) {
        const sb = getSupabaseServiceClient();
        const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_AVATARS_MB']);
        const maxBytes = ruleInt(rules, 'UPLOAD_LIMIT_AVATARS_MB', 2) * 1024 * 1024;
        if (!(logoFile.type in ALLOWED_LOGO_MIME)) {
          return Response.json({ error: 'VALIDATION', message: 'Logo must be JPEG, PNG, WebP, or SVG' }, { status: 400 });
        }
        if (logoFile.size > maxBytes) {
          return Response.json({ error: 'VALIDATION', message: `Logo exceeds ${ruleInt(rules, 'UPLOAD_LIMIT_AVATARS_MB', 2)} MB` }, { status: 400 });
        }
        const ext = ALLOWED_LOGO_MIME[logoFile.type];
        const buffer = Buffer.from(await logoFile.arrayBuffer());
        const result = await commitDocument(docPath.societyLogo(ext), buffer, `media: society logo updated by ${user.id}`);
        logoKey = result.githubPath;
      }

      fields = Object.fromEntries(
        [...fd.entries()]
          .filter(([k]) => k !== 'logo')
          .map(([k, v]) => [k, String(v).trim()])
      );
    } else {
      fields = await request.json() as Record<string, unknown>;
    }

    const ALLOWED_FIELDS = [
      'name', 'tagline', 'contact_email', 'contact_phone', 'website_url',
      'whatsapp_group_url', 'fiscal_year_start', 'timezone', 'currency_symbol',
      'invoice_prefix', 'receipt_prefix', 'address', 'city', 'state', 'pincode',
      'gstin', 'pan',
    ];
    const VALID_FY = new Set(['january', 'april']);

    const update: Record<string, unknown> = {};
    for (const key of ALLOWED_FIELDS) {
      if (fields[key] !== undefined && fields[key] !== null) {
        update[key] = String(fields[key]).trim() || null;
      }
    }
    if (update.fiscal_year_start && !VALID_FY.has(String(update.fiscal_year_start))) {
      return Response.json({ error: 'VALIDATION', message: 'fiscal_year_start must be january or april' }, { status: 400 });
    }
    if (logoKey) update.logo_key = logoKey;

    if (!Object.keys(update).length) {
      return Response.json({ error: 'VALIDATION', message: 'No valid fields to update' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data: before } = await sb.from('societies').select('*').eq('id', SOCIETY_ID).single();
    const { data, error } = await sb.from('societies').update(update).eq('id', SOCIETY_ID).select().single();
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'societies', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      oldValues: before, newValues: update,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
