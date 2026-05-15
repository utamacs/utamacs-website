export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function fmt(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

// GET /api/v1/maids/:id/pass
// Returns a self-contained HTML page suitable for printing as a KYC pass.
// Accessible by any authenticated member (so guard can view pass for a registered maid).
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const maidId = params.id ?? '';
    if (!UUID_RE.test(maidId)) return Response.json({ error: 'INVALID_ID' }, { status: 400 });

    const sb = getSupabaseServiceClient();
    const { data: maid } = await sb
      .from('maids')
      .select(`
        id, full_name, phone, work_type, agency_name,
        police_verified, verification_date, kyc_expires_at,
        is_active, photo_key,
        maid_unit_approvals (
          is_active,
          units ( unit_number, block )
        )
      `)
      .eq('id', maidId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!maid) return Response.json({ error: 'NOT_FOUND', message: 'Helper not found.' }, { status: 404 });

    let photoDataUrl = '';
    if (maid.photo_key) {
      try {
        const signed = await getDocumentDownloadUrl(maid.photo_key);
        // For the pass HTML we embed as an img src — signed URL is sufficient (~1 hour)
        photoDataUrl = signed;
      } catch { /* no photo */ }
    }

    const activeApprovals = (maid.maid_unit_approvals as any[])
      .filter((a: any) => a.is_active)
      .map((a: any) => {
        const u = a.units;
        return u ? `${u.block ? `${u.block}-` : ''}${u.unit_number}` : '—';
      });

    const isExpired = maid.kyc_expires_at ? new Date(maid.kyc_expires_at) < new Date() : false;
    const expiryLabel = maid.kyc_expires_at ? fmt(maid.kyc_expires_at) : 'No expiry set';

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>KYC Pass — ${maid.full_name}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #f3f4f6; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }
    .pass { background: #fff; width: 340px; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.12); }
    .header { background: #1E3A8A; color: #fff; padding: 16px 20px; display: flex; align-items: center; gap: 12px; }
    .header-icon { width: 36px; height: 36px; background: rgba(255,255,255,0.15); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 18px; }
    .header-title { font-size: 14px; font-weight: 700; line-height: 1.2; }
    .header-sub { font-size: 11px; opacity: 0.7; margin-top: 2px; }
    .body { padding: 20px; }
    .photo-row { display: flex; gap: 16px; align-items: flex-start; margin-bottom: 16px; }
    .photo { width: 80px; height: 80px; border-radius: 10px; object-fit: cover; border: 2px solid #E5E7EB; background: #f9fafb; flex-shrink: 0; }
    .photo-placeholder { width: 80px; height: 80px; border-radius: 10px; background: #E5E7EB; display: flex; align-items: center; justify-content: center; font-size: 32px; color: #9CA3AF; flex-shrink: 0; }
    .name { font-size: 17px; font-weight: 700; color: #111827; margin-bottom: 4px; }
    .work-type { font-size: 12px; color: #6B7280; text-transform: capitalize; margin-bottom: 4px; }
    .agency { font-size: 11px; color: #9CA3AF; }
    .section { margin-bottom: 14px; }
    .section-title { font-size: 10px; font-weight: 600; color: #6B7280; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 6px; }
    .detail-row { display: flex; justify-content: space-between; font-size: 12px; padding: 4px 0; border-bottom: 1px solid #F3F4F6; }
    .detail-label { color: #6B7280; }
    .detail-value { font-weight: 500; color: #111827; text-align: right; }
    .units { display: flex; flex-wrap: wrap; gap: 4px; }
    .unit-badge { background: #EFF6FF; color: #1E3A8A; font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 20px; }
    .status-row { margin-top: 14px; padding: 10px 12px; border-radius: 10px; display: flex; align-items: center; gap: 8px; }
    .status-valid { background: #F0FDF4; border: 1px solid #BBF7D0; }
    .status-expired { background: #FEF2F2; border: 1px solid #FECACA; }
    .status-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
    .dot-valid { background: #10B981; }
    .dot-expired { background: #EF4444; }
    .status-text { font-size: 12px; font-weight: 600; }
    .status-valid .status-text { color: #065F46; }
    .status-expired .status-text { color: #991B1B; }
    .status-sub { font-size: 11px; color: #6B7280; }
    .footer { background: #F9FAFB; border-top: 1px solid #E5E7EB; padding: 10px 20px; font-size: 10px; color: #9CA3AF; text-align: center; }
    @media print {
      body { background: white; padding: 0; }
      .pass { box-shadow: none; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="pass">
    <div class="header">
      <div class="header-icon">&#128736;</div>
      <div>
        <div class="header-title">UTA MACS — Domestic Help Registry</div>
        <div class="header-sub">Urban Trilla Apartments, Kondakal</div>
      </div>
    </div>
    <div class="body">
      <div class="photo-row">
        ${photoDataUrl
          ? `<img src="${photoDataUrl}" alt="${maid.full_name}" class="photo" />`
          : `<div class="photo-placeholder">&#128100;</div>`}
        <div>
          <div class="name">${maid.full_name}</div>
          <div class="work-type">${(maid.work_type as string).replace('_',' ')}</div>
          ${maid.agency_name ? `<div class="agency">${maid.agency_name}</div>` : ''}
        </div>
      </div>

      <div class="section">
        <div class="section-title">Verification</div>
        <div class="detail-row">
          <span class="detail-label">Police Verified</span>
          <span class="detail-value">${maid.police_verified ? '✓ Yes' : '✗ No'}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Verified On</span>
          <span class="detail-value">${fmt(maid.verification_date)}</span>
        </div>
      </div>

      ${activeApprovals.length > 0 ? `
      <div class="section">
        <div class="section-title">Approved Flats</div>
        <div class="units" style="margin-top:6px">
          ${activeApprovals.map(u => `<span class="unit-badge">${u}</span>`).join('')}
        </div>
      </div>` : ''}

      <div class="status-row ${isExpired ? 'status-expired' : 'status-valid'}">
        <div class="status-dot ${isExpired ? 'dot-expired' : 'dot-valid'}"></div>
        <div>
          <div class="status-text">${isExpired ? 'KYC Expired' : maid.police_verified ? 'Verified & Active' : 'Pending Verification'}</div>
          <div class="status-sub">KYC valid until: ${expiryLabel}</div>
        </div>
      </div>
    </div>
    <div class="footer">
      Pass ID: ${maid.id.slice(0,8).toUpperCase()} &nbsp;·&nbsp; Generated ${fmt(new Date().toISOString())} &nbsp;·&nbsp;
      <span class="no-print"><button onclick="window.print()" style="background:none;border:none;color:#1E3A8A;cursor:pointer;font-size:10px;text-decoration:underline;">Print Pass</button></span>
    </div>
  </div>
</body>
</html>`;

    return new Response(html, {
      status: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
