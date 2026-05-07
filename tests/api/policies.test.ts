import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Policies API', () => {
  it('GET /policies without auth → 401', async () => {
    const res = await apiFetch('/policies', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /policies with member auth → 200', async () => {
    const res = await apiFetch('/policies', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('POST /policies with member auth → 403', async () => {
    const res = await apiFetch('/policies', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        title: 'API Test Policy',
        body: 'Policy content for testing that is long enough',
        category: 'general',
        effective_date: '2026-01-01',
      }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /policies with exec auth + valid body → 201', async () => {
    const res = await apiFetch('/policies', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        title: 'API Test Policy',
        body: 'Policy content for testing that is long enough',
        category: 'general',
        effective_date: '2026-01-01',
      }),
    });
    expect(res.status).toBe(201);
  });
});
