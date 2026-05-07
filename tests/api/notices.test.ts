import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Notices API', () => {
  it('GET /notices without auth → 401', async () => {
    const res = await apiFetch('/notices', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /notices with member auth → 200', async () => {
    const res = await apiFetch('/notices', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('POST /notices with member auth → 403 (member lacks notice.send)', async () => {
    const res = await apiFetch('/notices', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        title: 'API Test Notice',
        body: 'Test content that is long enough to pass validation',
        notice_type: 'general',
        priority: 'normal',
      }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /notices with exec auth + body → 201', async () => {
    const res = await apiFetch('/notices', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        title: 'API Test Notice',
        body: 'Test content that is long enough to pass validation',
        notice_type: 'general',
        priority: 'normal',
      }),
    });
    expect(res.status).toBe(201);
  });
});
