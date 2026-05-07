import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Gallery API', () => {
  it('GET /gallery/albums without auth → 401', async () => {
    const res = await apiFetch('/gallery/albums', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /gallery/albums with member auth → 200, array', async () => {
    const res = await apiFetch('/gallery/albums', { role: 'member' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  it('POST /gallery/albums with member auth → 403', async () => {
    const res = await apiFetch('/gallery/albums', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        title: 'API Test Album',
        description: 'Test album',
        event_date: '2026-01-01',
      }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /gallery/albums with exec auth + valid body → 201', async () => {
    const res = await apiFetch('/gallery/albums', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        title: 'API Test Album',
        description: 'Test album',
        event_date: '2026-01-01',
      }),
    });
    expect(res.status).toBe(201);
  });
});
