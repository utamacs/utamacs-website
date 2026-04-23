const CACHE_VERSION = 'v1';
const STATIC_CACHE = `utamacs-static-${CACHE_VERSION}`;
const NOTICES_CACHE = `utamacs-notices-${CACHE_VERSION}`;

const STATIC_ASSETS = [
  '/portal',
  '/portal/notices',
  '/manifest.json',
];

// Install — cache static shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

// Activate — purge old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== STATIC_CACHE && k !== NOTICES_CACHE)
          .map((k) => caches.delete(k))
      )
    )
  );
  self.clients.claim();
});

// Fetch strategy:
// - Notices API: network-first, cache fallback (enables offline reading)
// - Everything else: network-first, no cache
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Cache notices API responses for offline reading
  if (url.pathname.startsWith('/api/v1/notices') && event.request.method === 'GET') {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(NOTICES_CACHE).then((cache) => cache.put(event.request, clone));
          }
          return response;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // For API mutations and auth — always network only (never cache)
  if (url.pathname.startsWith('/api/')) return;

  // For portal pages — network-first, fallback to cache
  if (url.pathname.startsWith('/portal')) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(event.request))
    );
  }
});

// Push notification handler (for future use with Web Push)
self.addEventListener('push', (event) => {
  if (!event.data) return;
  const data = event.data.json();
  event.waitUntil(
    self.registration.showNotification(data.title ?? 'UTA MACS', {
      body: data.body ?? '',
      icon: '/assets/logo-192.png',
      badge: '/assets/logo-192.png',
      tag: data.tag ?? 'utamacs-notification',
      data: { url: data.url ?? '/portal' },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = event.notification.data?.url ?? '/portal';
  event.waitUntil(clients.openWindow(url));
});
