export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { commitDocument, docPath } from '@lib/utils/githubDocStore';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const ALLOWED_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};

export const POST: APIRoute = async ({ request }) => {
  try {
    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const name   = sanitizePlainText(String(formData.get('applicant_name') ?? '')).trim();
    const email  = String(formData.get('applicant_email') ?? '').trim().toLowerCase();
    const phone  = String(formData.get('applicant_phone') ?? '').trim();
    const unit   = sanitizePlainText(String(formData.get('unit_number') ?? '')).trim();
    const block  = sanitizePlainText(String(formData.get('block') ?? '')).trim() || null;

    if (!name || !email || !phone || !unit) {
      return Response.json({ error: 'VALIDATION', message: 'name, email, phone, unit_number are required' }, { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid email address' }, { status: 400 });
    }
    if (!/^[6-9]\d{9}$/.test(phone)) {
      return Response.json({ error: 'VALIDATION', message: 'Phone must be a valid 10-digit Indian mobile number' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Prevent duplicate pending requests for the same email + unit
    const { data: existing } = await sb
      .from('onboarding_requests')
      .select('id, status')
      .eq('society_id', SOCIETY_ID)
      .eq('applicant_email', email)
      .eq('unit_number', unit)
      .in('status', ['pending', 'under_review'])
      .maybeSingle();

    if (existing) {
      return Response.json({ error: 'CONFLICT', message: 'A pending request already exists for this email and unit.' }, { status: 409 });
    }

    // Handle optional document upload
    let docKey: string | null = null;
    const file = formData.get('ownership_doc') as File | null;
    if (file && file.size > 0) {
      const ext = ALLOWED_MIME[file.type];
      if (!ext) {
        return Response.json({ error: 'VALIDATION', message: 'Document must be PDF, JPEG, or PNG' }, { status: 400 });
      }
      const MAX_BYTES = 5 * 1024 * 1024;
      if (file.size > MAX_BYTES) {
        return Response.json({ error: 'VALIDATION', message: 'Document exceeds 5 MB limit' }, { status: 400 });
      }
      const buffer = Buffer.from(await file.arrayBuffer());
      const result = await commitDocument(
        docPath.registration(crypto.randomUUID(), 'sale-deed', ext),
        buffer,
        `docs: owner registration ${email} ownership doc`,
      );
      docKey = result.githubPath;
    }

    const { data, error } = await sb
      .from('onboarding_requests')
      .insert({
        society_id:       SOCIETY_ID,
        request_type:     'owner',
        status:           'pending',
        applicant_name:   name,
        applicant_email:  email,
        applicant_phone:  phone,
        unit_number:      unit,
        block:            block,
        ownership_doc_key: docKey,
      })
      .select('id')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json({ id: data.id, status: 'pending' }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
