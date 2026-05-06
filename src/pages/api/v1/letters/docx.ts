export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { generateDocxBuffer } from '@lib/utils/docxGenerator';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request }) => {
  try {
    await validateJWT(request);

    const body = await request.json() as {
      template_id?: string;
      field_values?: Record<string, string>;
      signatures_used?: string[];
    };

    const { template_id, field_values, signatures_used } = body;

    if (!template_id) {
      return new Response(JSON.stringify({ error: 'template_id is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const { data: template, error } = await sb
      .from('letterhead_templates')
      .select('*, letterhead_committee_members(*)')
      .eq('id', template_id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !template) {
      return new Response(JSON.stringify({ error: 'Template not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Fetch logo for embedding in DOCX header
    let logoBase64: string | undefined;
    const logoPath = (template.logo_path as string | undefined) || '/UTA-MACS-Logo.png';
    try {
      const origin = new URL(request.url).origin;
      const logoUrl = logoPath.startsWith('http') ? logoPath : `${origin}${logoPath.startsWith('/') ? '' : '/'}${logoPath}`;
      const logoRes = await fetch(logoUrl);
      if (logoRes.ok) {
        const buf = await logoRes.arrayBuffer();
        logoBase64 = Buffer.from(buf).toString('base64');
      }
    } catch { /* logo not critical — DOCX falls back to text header */ }

    const signatories = (signatures_used ?? []).map(d => ({ designation: d }));
    const buf = await generateDocxBuffer(template, field_values ?? {}, signatories, logoBase64);

    return new Response(new Uint8Array(buf), {
      headers: {
        'Content-Type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
