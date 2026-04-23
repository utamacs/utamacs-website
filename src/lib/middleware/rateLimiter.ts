interface Window {
  count: number;
  resetAt: number;
}

// In-memory store — swap for Redis/Upstash in production
const store = new Map<string, Window>();

interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
}

const CONFIGS: Record<string, RateLimitConfig> = {
  default: { windowMs: 60_000, maxRequests: 100 },
  auth: { windowMs: 15 * 60_000, maxRequests: 10 },
};

function getConfig(path: string): RateLimitConfig {
  if (path.startsWith('/api/v1/auth')) return CONFIGS['auth']!;
  return CONFIGS['default']!;
}

export function checkRateLimit(ip: string, path: string): void {
  const config = getConfig(path);
  const key = `${ip}:${path.split('/').slice(0, 4).join('/')}`;
  const now = Date.now();
  let window = store.get(key);

  if (!window || now > window.resetAt) {
    window = { count: 0, resetAt: now + config.windowMs };
    store.set(key, window);
  }

  window.count++;

  if (window.count > config.maxRequests) {
    const retryAfter = Math.ceil((window.resetAt - now) / 1000);
    throw Object.assign(new Error('Too many requests'), {
      status: 429,
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter,
    });
  }
}
