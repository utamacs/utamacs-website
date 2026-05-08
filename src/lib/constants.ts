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
// Per-module limits live in the rules engine (UPLOAD_LIMIT_*_MB rules),
// configurable via /portal/admin/rules without code deployment.
// Only the absolute fallback lives here for use before rules are loaded.

/** Fallback upload limit when rules engine is unavailable. Not used in normal flow. */
export const DEFAULT_UPLOAD_LIMIT_MB = 5;

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
