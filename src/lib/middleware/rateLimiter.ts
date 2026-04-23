import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

// In-memory fallback for local dev (no Upstash credentials)
interface Window { count: number; resetAt: number }
const localStore = new Map<string, Window>();

interface RateLimitConfig { windowMs: number; maxRequests: number }
const LOCAL_CONFIGS: Record<string, RateLimitConfig> = {
  default: { windowMs: 60_000, maxRequests: 100 },
  auth:    { windowMs: 15 * 60_000, maxRequests: 10 },
};

function localCheck(ip: string, path: string): void {
  const config = path.startsWith('/api/v1/auth') ? LOCAL_CONFIGS['auth']! : LOCAL_CONFIGS['default']!;
  const key = `${ip}:${path.split('/').slice(0, 4).join('/')}`;
  const now = Date.now();
  let win = localStore.get(key);
  if (!win || now > win.resetAt) {
    win = { count: 0, resetAt: now + config.windowMs };
    localStore.set(key, win);
  }
  win.count++;
  if (win.count > config.maxRequests) {
    const retryAfter = Math.ceil((win.resetAt - now) / 1000);
    throw Object.assign(new Error('Too many requests'), { status: 429, code: 'RATE_LIMIT_EXCEEDED', retryAfter });
  }
}

// Upstash limiters — initialised once per cold start
let defaultLimiter: Ratelimit | null = null;
let authLimiter: Ratelimit | null = null;

function getUpstashLimiters(): { default: Ratelimit; auth: Ratelimit } | null {
  const url   = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;

  if (!defaultLimiter) {
    const redis = new Redis({ url, token });
    defaultLimiter = new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(100, '60 s'),  prefix: 'rl:default' });
    authLimiter    = new Ratelimit({ redis, limiter: Ratelimit.slidingWindow(10,  '15 m'),  prefix: 'rl:auth'    });
  }
  return { default: defaultLimiter!, auth: authLimiter! };
}

export async function checkRateLimit(ip: string, path: string): Promise<void> {
  const limiters = getUpstashLimiters();

  if (!limiters) {
    // Local dev — use in-memory fallback
    localCheck(ip, path);
    return;
  }

  const limiter = path.startsWith('/api/v1/auth') ? limiters.auth : limiters.default;
  const key = `${ip}:${path.split('/').slice(0, 4).join('/')}`;
  const { success, reset } = await limiter.limit(key);

  if (!success) {
    const retryAfter = Math.ceil((reset - Date.now()) / 1000);
    throw Object.assign(new Error('Too many requests'), { status: 429, code: 'RATE_LIMIT_EXCEEDED', retryAfter });
  }
}
