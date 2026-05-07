/**
 * Shared runtime constants for the UTAMACS portal.
 *
 * RULES ENGINE vs CONSTANTS:
 * - Use getRules() for values that society admins may change (fees, days, thresholds).
 * - Use constants here for values that are compliance-mandated or architectural
 *   (e.g. DPDPA signed URL expiry cap, file MIME type lists).
 *
 * Every constant here MUST have a comment explaining why it is a constant
 * rather than a configurable rule.
 */

// ── Storage / Document access ─────────────────────────────────────────────────

/**
 * Maximum signed URL expiry in seconds.
 * DPDPA 2023 compliance: identity documents must expire in ≤3600 seconds (1 hour).
 * CLAUDE.md §8.7: "identity document signed URLs must expire in ≤3600 seconds".
 * This is the MAXIMUM allowed; individual APIs may use shorter values for sensitivity.
 */
export const SIGNED_URL_EXPIRY_SECS = 3600;

/**
 * Shorter expiry for highly sensitive documents (Aadhaar, ID docs).
 * 15 minutes — balances usability with reduced exposure window.
 */
export const SENSITIVE_DOC_URL_EXPIRY_SECS = 900;

// ── File Upload Limits ────────────────────────────────────────────────────────
// Per-bucket limits as defined in CLAUDE.md §4C. Not configurable via rules
// because changing them requires Supabase bucket policy changes too.

export const UPLOAD_LIMITS_BYTES: Record<string, number> = {
  'notice-attachments':  10 * 1024 * 1024,
  'policy-documents':    20 * 1024 * 1024,
  'complaint-attachments': 50 * 1024 * 1024,
  'facility-photos':      5 * 1024 * 1024,
  'gallery-photos':      10 * 1024 * 1024,
  'community-images':     5 * 1024 * 1024,
  'marketplace-images':   5 * 1024 * 1024,
  'maid-documents':       5 * 1024 * 1024,
  'member-documents':    10 * 1024 * 1024,
  'event-banners':        5 * 1024 * 1024,
  'onboarding-docs':     10 * 1024 * 1024,
  'invoice-pdfs':         1 * 1024 * 1024,
  'receipt-pdfs':         1 * 1024 * 1024,
  'society-assets':       2 * 1024 * 1024,
  'avatars':              2 * 1024 * 1024,
  'poll-exports':         1 * 1024 * 1024,
  'parking-docs':         5 * 1024 * 1024,
  DEFAULT:                5 * 1024 * 1024,
};

export function getUploadLimitBytes(bucket: string): number {
  return UPLOAD_LIMITS_BYTES[bucket] ?? UPLOAD_LIMITS_BYTES.DEFAULT;
}

// ── Allowed MIME types ────────────────────────────────────────────────────────

export const DOCUMENT_MIME_TYPES: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};

export const IMAGE_MIME_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

// ── UUID validation regex ─────────────────────────────────────────────────────
// Defined here so APIs don't repeat it; not a configurable rule.
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
