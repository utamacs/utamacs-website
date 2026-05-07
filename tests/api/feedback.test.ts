import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Feedback API', () => {
  it('GET /feedback without auth → 401', async () => {
    const res = await apiFetch('/feedback', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /feedback with member auth → 200', async () => {
    const res = await apiFetch('/feedback', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('POST /feedback with member auth + valid body → 201', async () => {
    const res = await apiFetch('/feedback', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        category: 'general',
        subject: 'API Test Feedback',
        body: 'This is test feedback content that is long enough to pass validation',
        is_anonymous: false,
      }),
    });
    expect(res.status).toBe(201);
  });

  it('POST /feedback with empty body → 400', async () => {
    const res = await apiFetch('/feedback', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });
});
