export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const BUCKET = 'work-order-invoices';
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

/** GET — returns 1-hour signed URL for the invoice attached to this work order */
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    // Both exec and the owning vendor can retrieve the invoice
    const { data: wo } = await sb
      .from('work_orders')
      .select('id, vendor_id, invoice_storage_key, vendors(email)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!wo) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    if (user.role === 'vendor') {
      const { data: vendorProfile } = await sb.from('vendors').select('id').eq('email', user.id).single();
      if (!vendorProfile || wo.vendor_id !== vendorProfile.id) {
        return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
      }
    } else if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    if (!(wo as any).invoice_storage_key) {
      return Response.json({ error: 'No invoice uploaded yet' }, { status: 404 });
    }

    const { data: signed } = await sb.storage
      .from(BUCKET)
      .createSignedUrl((wo as any).invoice_storage_key, 3600);

    if (!signed?.signedUrl) {
      return Response.json({ error: 'Could not generate download URL' }, { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'EXPORT', resourceType: 'work_orders', resourceId: params.id!,
      ip: extractClientIP(request),
    });

    return Response.json({ url: signed.signedUrl });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

/** POST — vendor (or exec) uploads invoice PDF for this work order */
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    // Fetch work order
    const { data: wo } = await sb
      .from('work_orders')
      .select('id, vendor_id, status')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!wo) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Vendors can upload only to their own work orders (in in_progress or completed state)
    if (user.role === 'vendor') {
      const { data: vendorProfile } = await sb.from('vendors').select('id').eq('email', user.id).single();
      if (!vendorProfile || wo.vendor_id !== vendorProfile.id) {
        return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
      }
      if (!['in_progress', 'completed'].includes(wo.status)) {
        return Response.json({ error: 'VALIDATION_ERROR', message: 'Invoice can only be uploaded for in-progress or completed work orders' }, { status: 422 });
      }
    } else if (!['executive', 'admin'].includes(user.role)) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    let formData: FormData;
    try { formData = await request.formData(); }
    catch { return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 }); }

    const file = formData.get('file') as File | null;
    if (!file || !(file instanceof File)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'file is required' }, { status: 400 });
    }

    if (file.type !== 'application/pdf') {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Only PDF invoices are accepted' }, { status: 400 });
    }

    const bytes = await file.arrayBuffer();
    if (bytes.byteLength > MAX_BYTES) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'File must be under 10 MB' }, { status: 400 });
    }

    const storageKey = `${SOCIETY_ID}/${params.id!}/invoice.pdf`;
    await sb.storage.from(BUCKET).upload(storageKey, Buffer.from(bytes), {
      contentType: 'application/pdf',
      upsert: true,
    });

    const { data: signed } = await sb.storage.from(BUCKET).createSignedUrl(storageKey, 3600);

    const { error: updErr } = await sb
      .from('work_orders')
      .update({ invoice_storage_key: storageKey })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID);

    if (updErr) throw Object.assign(new Error(updErr.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'work_orders', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: { invoice_storage_key: storageKey },
    });

    return Response.json({ storage_key: storageKey, url: signed?.signedUrl }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
