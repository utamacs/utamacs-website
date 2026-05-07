import { describe, it, expect } from 'vitest';
import { PORTAL } from './helpers/auth';

describe('Health check', () => {
  it('GET /api/v1/health → 200 or 503', async () => {
    const res = await fetch(`${PORTAL}/api/v1/health`);
    // 200 = healthy, 503 = degraded but reachable (acceptable in production)
    expect([200, 503]).toContain(res.status);
  });

  it('GET /api/v1/health returns JSON', async () => {
    const res = await fetch(`${PORTAL}/api/v1/health`);
    const ct = res.headers.get('content-type') ?? '';
    expect(ct).toContain('application/json');
  });
});
