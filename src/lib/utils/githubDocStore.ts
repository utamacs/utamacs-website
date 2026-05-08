/**
 * GitHub Document Store — ALL file uploads go here.
 *
 * Governance docs AND media (images, banners, avatars) are committed to the
 * private GitHub repo. Supabase Storage is no longer used for uploads.
 *
 * Canonical folder structure:
 *
 *   Governance / legal:
 *     members/{unit_id}/{timestamp}-{doctype}.{ext}
 *     staff-kyc/{staff_id}/{doctype}.{ext}          e.g. photo.jpg  id-doc.pdf
 *     maids/{maid_id}/{doctype}.{ext}
 *     tenant-kyc/{tenant_id}/{timestamp}-{doctype}.{ext}
 *     registration/{profile_id}/{timestamp}-{doctype}.{ext}
 *     policies/{policy_id}/v{n}-{slug}.{ext}
 *     notices/{YYYY}/{notice_id}/{timestamp}-attachment.{ext}
 *     parking/{unit_id}/{slot_id}-{doctype}.{ext}
 *     polls/exports/{YYYY}/{poll_id}.pdf
 *     vendors/{vendor_id}/invoices/{work_order_id}.{ext}
 *     finance/invoices/{YYYY}/{invoice_id}.pdf
 *     finance/receipts/{YYYY}/{receipt_id}.pdf
 *
 *   Media / images:
 *     media/avatars/{profile_id}.{ext}
 *     media/gallery/{album_id}/{photo_id}.{ext}
 *     media/events/{event_id}/banner.{ext}
 *     media/community/{post_id}/{timestamp}.{ext}
 *     media/marketplace/{listing_id}/{timestamp}.{ext}
 *     media/facilities/{facility_id}/{timestamp}.{ext}
 *     media/complaints/{complaint_id}/{timestamp}.{ext}
 *     media/society/logo.{ext}
 *
 *   Existing (HOTO platform):
 *     hoto/…  snags/…  audit/…  letters/…
 */

const REPO   = import.meta.env.GITHUB_DOCS_REPO   ?? import.meta.env.GITHUB_LETTERS_REPO   ?? '';
const TOKEN  = import.meta.env.GITHUB_DOCS_TOKEN  ?? import.meta.env.GITHUB_LETTERS_TOKEN  ?? import.meta.env.GITHUB_HOTO_TOKEN ?? '';
const BRANCH = import.meta.env.GITHUB_DOCS_BRANCH ?? import.meta.env.GITHUB_LETTERS_BRANCH ?? 'main';

const ALLOWED_ROOT_DIRS = [
  // Governance
  'members', 'staff-kyc', 'maids', 'tenant-kyc', 'registration',
  'policies', 'notices', 'parking', 'polls', 'vendors', 'finance',
  // Media
  'media',
  // Existing HOTO platform
  'hoto', 'snags', 'audit', 'letters',
] as const;

const PATH_RE = new RegExp(
  `^(${ALLOWED_ROOT_DIRS.join('|')})\\/[a-zA-Z0-9/_.,@+=-]+$`
);

export function validateDocPath(path: string): boolean {
  return PATH_RE.test(path) && !path.includes('..') && !path.includes('//');
}

/** Canonical path builders — every upload route uses one of these. */
export const docPath = {
  // ── Governance ───────────────────────────────────────────────────────────────
  memberDoc: (unitId: string, docType: string, ext: string) =>
    `members/${unitId}/${Date.now()}-${docType}.${ext}`,

  staffKycPhoto: (staffId: string, ext: string) =>
    `staff-kyc/${staffId}/photo.${ext}`,

  staffKycIdDoc: (staffId: string, ext: string) =>
    `staff-kyc/${staffId}/id-doc.${ext}`,

  maidKycPhoto: (maidId: string, ext: string) =>
    `maids/${maidId}/photo.${ext}`,

  maidKycIdDoc: (maidId: string, ext: string) =>
    `maids/${maidId}/id-doc.${ext}`,

  tenantKyc: (tenantId: string, docType: string, ext: string) =>
    `tenant-kyc/${tenantId}/${Date.now()}-${docType}.${ext}`,

  registration: (profileId: string, docType: string, ext: string) =>
    `registration/${profileId}/${Date.now()}-${docType}.${ext}`,

  policy: (policyId: string, version: number, slug: string, ext: string) =>
    `policies/${policyId}/v${version}-${slug.replace(/[^a-zA-Z0-9-]/g, '_').slice(0, 40)}.${ext}`,

  notice: (noticeId: string, filename: string, ext: string) =>
    `notices/${new Date().getFullYear()}/${noticeId}/${Date.now()}-${filename.replace(/[^a-zA-Z0-9-]/g, '_').slice(0, 40)}.${ext}`,

  parking: (unitId: string, slotId: string, docType: string, ext: string) =>
    `parking/${unitId}/${slotId}-${docType}.${ext}`,

  pollExport: (pollId: string) =>
    `polls/exports/${new Date().getFullYear()}/${pollId}.pdf`,

  vendorInvoice: (vendorId: string, workOrderId: string, ext: string) =>
    `vendors/${vendorId}/invoices/${workOrderId}.${ext}`,

  financeInvoice: (invoiceId: string, ext: string) =>
    `finance/invoices/${new Date().getFullYear()}/${invoiceId}.${ext}`,

  financeReceipt: (receiptId: string, ext: string) =>
    `finance/receipts/${new Date().getFullYear()}/${receiptId}.${ext}`,

  // ── Media ────────────────────────────────────────────────────────────────────
  avatar: (profileId: string, ext: string) =>
    `media/avatars/${profileId}.${ext}`,

  galleryPhoto: (albumId: string, photoId: string, ext: string) =>
    `media/gallery/${albumId}/${photoId}.${ext}`,

  eventBanner: (eventId: string, ext: string) =>
    `media/events/${eventId}/banner.${ext}`,

  communityImage: (postId: string, ext: string) =>
    `media/community/${postId}/${Date.now()}.${ext}`,

  marketplaceImage: (listingId: string, ext: string) =>
    `media/marketplace/${listingId}/${Date.now()}.${ext}`,

  facilityImage: (facilityId: string, ext: string) =>
    `media/facilities/${facilityId}/${Date.now()}.${ext}`,

  complaintAttachment: (complaintId: string, ext: string) =>
    `media/complaints/${complaintId}/${Date.now()}.${ext}`,

  societyLogo: (ext: string) =>
    `media/society/logo.${ext}`,
};

export interface CommitResult {
  githubPath: string;
  githubSha: string;
}

/**
 * Commit a document/image buffer to the private GitHub repo.
 * Returns path + SHA on success. Throws on failure.
 */
export async function commitDocument(
  path: string,
  buffer: Buffer,
  commitMessage: string,
): Promise<CommitResult> {
  if (!REPO || !TOKEN) {
    throw Object.assign(
      new Error('GitHub document store not configured — set GITHUB_DOCS_REPO and GITHUB_DOCS_TOKEN'),
      { status: 503 }
    );
  }
  if (!validateDocPath(path)) {
    throw Object.assign(new Error(`Invalid document path: ${path}`), { status: 400 });
  }

  const url = `https://api.github.com/repos/${REPO}/contents/${path}`;
  const headers = {
    Authorization: `Bearer ${TOKEN}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  // Fetch existing SHA to enable overwrite (idempotent PUT)
  let existingSha: string | undefined;
  const checkRes = await fetch(url, { headers });
  if (checkRes.ok) {
    const existing = await checkRes.json() as { sha?: string };
    existingSha = existing.sha;
  }

  const body: Record<string, unknown> = {
    message: commitMessage,
    content: buffer.toString('base64'),
    branch: BRANCH,
  };
  if (existingSha) body.sha = existingSha;

  const res = await fetch(url, {
    method: 'PUT',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw Object.assign(
      new Error(`GitHub commit failed (${res.status}): ${text.slice(0, 200)}`),
      { status: 502 }
    );
  }

  const json = await res.json() as { content: { sha: string } };
  return { githubPath: path, githubSha: json.content.sha };
}

/**
 * Get a temporary download URL for a file in the private repo.
 * GitHub's API returns an AWS pre-signed URL valid for ~1 hour — equivalent
 * to a Supabase signed URL. All callers should treat this as short-lived.
 */
export async function getDocumentDownloadUrl(path: string): Promise<string> {
  if (!REPO || !TOKEN) {
    throw Object.assign(new Error('GitHub document store not configured'), { status: 503 });
  }

  const url = `https://api.github.com/repos/${REPO}/contents/${encodeURIComponent(path)}?ref=${BRANCH}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  });

  if (!res.ok) {
    throw Object.assign(new Error(`Document not found: ${path}`), { status: 404 });
  }

  const meta = await res.json() as { download_url?: string };
  if (meta.download_url) return meta.download_url;

  throw Object.assign(new Error(`Cannot generate download URL for: ${path}`), { status: 502 });
}

export function isGitHubConfigured(): boolean {
  return Boolean(REPO && TOKEN);
}
