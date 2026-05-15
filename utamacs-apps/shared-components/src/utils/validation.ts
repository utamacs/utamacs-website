// Shared validation utilities — mirrors src/lib/constants.ts UUID_RE from the portal

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const INDIAN_PHONE_RE = /^[6-9]\d{9}$/;

export const isValidUUID = (v: string): boolean => UUID_RE.test(v);
export const isValidEmail = (v: string): boolean => EMAIL_RE.test(v.trim().toLowerCase());

export const ALLOWED_DOC_MIME = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'] as const;
export const ALLOWED_IMAGE_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'] as const;

export type AllowedDocMime = typeof ALLOWED_DOC_MIME[number];
export type AllowedImageMime = typeof ALLOWED_IMAGE_MIME[number];

export const isAllowedDocMime = (mime: string): mime is AllowedDocMime =>
  (ALLOWED_DOC_MIME as readonly string[]).includes(mime);

export const isAllowedImageMime = (mime: string): mime is AllowedImageMime =>
  (ALLOWED_IMAGE_MIME as readonly string[]).includes(mime);
