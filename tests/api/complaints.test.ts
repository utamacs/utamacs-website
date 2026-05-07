import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Complaints API', () => {
  it('GET /complaints without auth → 401', async () => {
    const res = await apiFetch('/complaints', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /complaints with member auth → 200, body is array', async () => {
    const res = await apiFetch('/complaints', { role: 'member' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  it('POST /complaints with member auth + valid body → 201 with id field', async () => {
    const res = await apiFetch('/complaints', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        category: 'maintenance',
        subject: 'API Test Complaint',
        description: 'This is a test complaint submitted by the Vitest API test suite.',
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body).toHaveProperty('id');
  });

  it('POST /complaints with member auth + empty body → 400', async () => {
    const res = await apiFetch('/complaints', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it('GET /complaints/{bad-uuid} → 400 or 404', async () => {
    const res = await apiFetch('/complaints/not-a-valid-uuid', { role: 'member' });
    expect([400, 404]).toContain(res.status);
  });
});
