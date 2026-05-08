export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { commitDocument, docPath } from '@lib/utils/githubDocStore';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const ALLOWED_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};

// PATCH /api/v1/admin/staff-kyc/[id]?type=staff|maid
// Update KYC verification details, issue security pass, upload documents
export const PATCH: APIRoute = async ({ request, params, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = params.id ?? '';
    if (!UUID_RE.test(id)) return Response.json({ error: 'VALIDATION', message: 'Invalid id' }, { status: 400 });

    const type = url.searchParams.get('type') ?? 'staff';
    const table = type === 'maid' ? 'maids' : 'staff_members';

    const sb = getSupabaseServiceClient();
    const { data: record, error: fetchErr } = await sb.from(table).select('*').eq('id', id).eq('society_id', SOCIETY_ID).single();
    if (fetchErr || !record) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const isMultipart = request.headers.get('content-type')?.includes('multipart/form-data');
    const updates: Record<string, unknown> = {};

    if (isMultipart) {
      // Document upload (photo or id_doc)
      const formData = await request.formData();
      const file = formData.get('file') as File | null;
      const docType = String(formData.get('doc_type') ?? 'id_doc'); // 'photo' | 'id_doc'

      if (!file) return Response.json({ error: 'VALIDATION', message: 'file field required' }, { status: 400 });
      if (!ALLOWED_MIME[file.type]) return Response.json({ error: 'VALIDATION', message: 'Only PDF, JPEG, PNG allowed' }, { status: 400 });

      const staffKycRules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_STAFF_KYC_MB']);
      const staffKycMaxBytes = ruleInt(staffKycRules, 'UPLOAD_LIMIT_STAFF_KYC_MB', 5) * 1024 * 1024;

      const bytes = await file.arrayBuffer();
      const buffer = Buffer.from(bytes);
      if (buffer.length > staffKycMaxBytes) return Response.json({ error: 'VALIDATION', message: `File exceeds ${ruleInt(staffKycRules, 'UPLOAD_LIMIT_STAFF_KYC_MB', 5)} MB limit` }, { status: 400 });

      const ext = ALLOWED_MIME[file.type];
      const githubPath = docType === 'photo'
        ? (type === 'maid' ? docPath.maidKycPhoto(id, ext) : docPath.staffKycPhoto(id, ext))
        : (type === 'maid' ? docPath.maidKycIdDoc(id, ext) : docPath.staffKycIdDoc(id, ext));

      await commitDocument(githubPath, buffer, `docs: staff-kyc/${type}/${id} ${docType} uploaded by ${user.id}`);

      if (docType === 'photo') {
        updates.photo_key = githubPath;
      } else {
        updates.id_doc_key = githubPath;
      }

      // Check if both docs now present → advance to documents_submitted
      const hasPhoto = docType === 'photo' ? true : !!record.photo_key;
      const hasIdDoc = docType === 'id_doc' ? true : !!record.id_doc_key;
      if (hasPhoto && hasIdDoc && record.kyc_status === 'pending') {
        updates.kyc_status = 'documents_submitted';
      }

      await writeAuditLog({
        userId: user.id,
        societyId: SOCIETY_ID,
        action: 'UPDATE',
        resourceType: `${type}_kyc_document`,
        resourceId: id,
        oldValues: { [docType === 'photo' ? 'photo_key' : 'id_doc_key']: null },
        newValues: { github_path: githubPath },
      });
    } else {
      // JSON update
      const body = await request.json() as Record<string, unknown>;

      if (body.two_photos_received !== undefined) updates.two_photos_received = body.two_photos_received === true;
      if (body.aadhaar_last4 !== undefined && type === 'staff') {
        const last4 = String(body.aadhaar_last4).replace(/\D/g, '').slice(-4);
        if (last4.length !== 4) return Response.json({ error: 'VALIDATION', message: 'aadhaar_last4 must be 4 digits' }, { status: 400 });
        updates.aadhaar_last4 = last4;
      }

      // Police verification
      if (body.police_verified === true) {
        const station = sanitizePlainText(String(body.police_station ?? '')).trim();
        const ref = sanitizePlainText(String(body.police_verification_ref ?? '')).trim();
        const date = body.police_verification_date ? String(body.police_verification_date) : new Date().toISOString().split('T')[0];
        updates.police_verified = true;
        updates.police_station = station.slice(0, 200) || null;
        updates.police_verification_ref = ref.slice(0, 100) || null;
        if (type === 'staff') {
          updates.police_verification_date = date;
        } else {
          updates.verification_date = date;
          updates.verification_ref = ref.slice(0, 100) || null;
        }
        if (record.kyc_status === 'documents_submitted' || record.kyc_status === 'pending') {
          updates.kyc_status = 'police_verified';
        }
      }

      if (body.background_remarks !== undefined && type === 'staff') {
        updates.background_remarks = sanitizePlainText(String(body.background_remarks)).trim().slice(0, 500) || null;
      }

      // Issue security pass (Byelaw §13.3)
      if (body.issue_pass === true) {
        if (!record.police_verified && !updates.police_verified) {
          return Response.json({ error: 'VALIDATION', message: 'Police verification required before issuing security pass (Byelaw §13.3)' }, { status: 400 });
        }
        if (!record.two_photos_received && !updates.two_photos_received) {
          return Response.json({ error: 'VALIDATION', message: '2 passport photos required before issuing security pass (Byelaw §13.3)' }, { status: 400 });
        }

        const passNo = sanitizePlainText(String(body.security_pass_number ?? '')).trim();
        const passRuleKey = type === 'maid' ? 'MAID_PASS_VALIDITY_DAYS' : 'STAFF_PASS_VALIDITY_DAYS';
        const rulesData = await getRules(sb, SOCIETY_ID, [passRuleKey]);
        const validityDays = ruleInt(rulesData, passRuleKey, 365);
        const expiresAt = body.security_pass_expires_at
          ? String(body.security_pass_expires_at)
          : new Date(Date.now() + validityDays * 24 * 60 * 60 * 1000).toISOString();

        updates.security_pass_issued = true;
        updates.security_pass_issued_at = new Date().toISOString();
        updates.security_pass_number = passNo.slice(0, 50) || `PASS-${type.toUpperCase()}-${Date.now()}`;
        updates.security_pass_expires_at = expiresAt;
        updates.kyc_status = 'pass_issued';
        if (type === 'staff') updates.verified_by = user.id;
      }

      // Renew pass
      if (body.renew_pass === true) {
        const renewRuleKey = type === 'maid' ? 'MAID_PASS_VALIDITY_DAYS' : 'STAFF_PASS_VALIDITY_DAYS';
        const renewRules = await getRules(sb, SOCIETY_ID, [renewRuleKey]);
        const renewDays = ruleInt(renewRules, renewRuleKey, 365);
        const expiresAt = body.security_pass_expires_at
          ? String(body.security_pass_expires_at)
          : new Date(Date.now() + renewDays * 24 * 60 * 60 * 1000).toISOString();
        updates.security_pass_expires_at = expiresAt;
        updates.kyc_status = 'pass_issued';
      }

      // Mark pass expired
      if (body.kyc_status === 'pass_expired') {
        updates.kyc_status = 'pass_expired';
        updates.security_pass_issued = false;
      }
    }

    if (Object.keys(updates).length === 0) {
      return Response.json({ error: 'VALIDATION', message: 'No updatable fields provided' }, { status: 400 });
    }

    const { data, error: updateErr } = await sb
      .from(table)
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (updateErr) throw Object.assign(new Error(updateErr.message), { status: 500 });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
