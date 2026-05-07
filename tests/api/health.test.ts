import { describe, it, expect } from 'vitest';
import { PORTAL } from './helpers/auth';

describe('Health check', () => {
  it('GET /api/v1/health → 200', async () => {
    const res = await fetch(`${PORTAL}/api/v1/health`);
    expect(res.status).toBe(200);
  });
});
