export function applySecurityHeaders(headers: Headers): void {
  headers.set(
    'Content-Security-Policy',
    // cdn.jsdelivr.net added for jsqr (QR scanner decoder used by security guards)
    "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com; font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com; script-src 'self' 'unsafe-inline' https://kit.fontawesome.com https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; connect-src 'self' https://*.supabase.co https://ka-f.fontawesome.com https://api.github.com https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; media-src 'self' blob:",
  );
  headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('X-Frame-Options', 'DENY');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  // camera=(self) allows guards to use device camera for QR scanning on same-origin pages
  headers.set('Permissions-Policy', 'camera=(self), microphone=(), geolocation=()');
}
