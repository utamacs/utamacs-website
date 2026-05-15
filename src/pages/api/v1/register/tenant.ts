export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { commitDocument, docPath } from '@lib/utils/githubDocStore';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request }) => {
  try {
    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const name        = sanitizePlainText(String(formData.get('applicant_name') ?? '')).trim();
    const email       = String(formData.get('applicant_email') ?? '').trim().toLowerCase();
    const phone       = String(formData.get('applicant_phone') ?? '').trim();
    const unit        = sanitizePlainText(String(formData.get('unit_number') ?? '')).trim();
    const block       = sanitizePlainText(String(formData.get('block') ?? '')).trim() || null;
    const ownerEmail  = String(formData.get('owner_email') ?? '').trim().toLowerCase();
    const leaseStart  = String(formData.get('lease_start') ?? '').trim() || null;
    const leaseEnd    = String(formData.get('lease_end') ?? '').trim() || null;

    if (!name || !email || !phone || !unit) {
      return Response.json({ error: 'VALIDATION', message: 'name, email, phone, unit_number are required' }, { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid email address' }, { status: 400 });
    }
    if (!/^[6-9]\d{9}$/.test(phone)) {
      return Response.json({ error: 'VALIDATION', message: 'Phone must be a valid 10-digit Indian mobile number' }, { status: 400 });
    }
    if (leaseStart && leaseEnd && new Date(leaseStart) >= new Date(leaseEnd)) {
      return Response.json({ error: 'VALIDATION', message: 'Lease end must be after lease start' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('onboarding_requests')
      .select('id')
      .eq('society_id', SOCIETY_ID)
      .eq('applicant_email', email)
      .eq('unit_number', unit)
      .in('status', ['pending', 'under_review'])
      .maybeSingle();

    if (existing) {
      return Response.json({ error: 'CONFLICT', message: 'A pending request already exists for this email and unit.' }, { status: 409 });
    }

    // Look up owner by email for consent notification
    let ownerUserId: string | null = null;
    if (ownerEmail) {
      const { data: ownerProfile } = await sb
        .from('profiles')
        .select('id')
        .eq('society_id', SOCIETY_ID)
        .ilike('email', ownerEmail)
        .maybeSingle();
      ownerUserId = ownerProfile?.id ?? null;
    }

    // Handle optional lease document upload
    let docKey: string | null = null;
    const file = formData.get('lease_doc') as File | null;
    if (file && file.size > 0) {
      if (file.type !== 'application/pdf') {
        return Response.json({ error: 'VALIDATION', message: 'Rental agreement must be PDF' }, { status: 400 });
      }
      if (file.size > 5 * 1024 * 1024) {
        return Response.json({ error: 'VALIDATION', message: 'Document exceeds 5 MB limit' }, { status: 400 });
      }
      const buffer = Buffer.from(await file.arrayBuffer());
      const result = await commitDocument(
        docPath.registration(crypto.randomUUID(), 'lease', 'pdf'),
        buffer,
        `docs: tenant registration ${email} lease agreement`,
      );
      docKey = result.githubPath;
    }

    const { data, error } = await sb
      .from('onboarding_requests')
      .insert({
        society_id:      SOCIETY_ID,
        request_type:    'tenant',
        status:          'pending',
        applicant_name:  name,
        applicant_email: email,
        applicant_phone: phone,
        unit_number:     unit,
        block:           block,
        owner_user_id:   ownerUserId,
        lease_start:     leaseStart,
        lease_end:       leaseEnd,
        lease_doc_key:   docKey,
      })
      .select('id')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Notify owner in-portal (fire-and-forget) asking for consent
    if (ownerUserId) {
      sb.from('notifications').insert({
        society_id:      SOCIETY_ID,
        user_id:         ownerUserId,
        title:           `Tenant consent required for Flat ${unit}`,
        body:            `${name} has applied as a tenant for your flat. Please contact the management office to confirm consent.`,
        type:            'onboarding',
        reference_table: 'onboarding_requests',
        reference_id:    data.id,
      }).then(() => {}).catch(() => {});
    }

    return Response.json({ id: data.id, status: 'pending', owner_notified: !!ownerUserId }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
