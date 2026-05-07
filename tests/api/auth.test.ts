import { describe, it, expect } from 'vitest';
import { PORTAL } from './helpers/auth';

describe('Auth API', () => {
  it('POST /auth/login with bad credentials → 400 or 401', async () => {
    const res = await fetch(`${PORTAL}/api/v1/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'notauser@example.com', password: 'WrongPass123!' }),
    });
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(res.status).toBeLessThan(500);
  });

  it('POST /auth/login with empty body → 400', async () => {
    const res = await fetch(`${PORTAL}/api/v1/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(res.status).toBeLessThan(500);
  });
});
