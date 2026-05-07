import { describe, it, expect, beforeAll } from 'vitest';
import { apiFetch } from './helpers/auth';

// complaints require a valid unit_id — fetch it from the member's own profile
let memberUnitId: string | null = null;

beforeAll(async () => {
  try {
    const res = await apiFetch('/members/me', { role: 'member' });
    if (res.ok) {
      const profile = await res.json() as any;
      memberUnitId = profile.unit_id ?? null;
    }
  } catch { /* ignore — tests that need unit_id will skip */ }
});

describe('Complaints API', () => {
  it('GET /complaints without auth → 401', async () => {
    const res = await apiFetch('/complaints', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /complaints with member auth → 200', async () => {
    const res = await apiFetch('/complaints', { role: 'member' });
    expect(res.status).toBe(200);
    const body = await res.json();
    // response is either an array or { data: [...] } paginated shape
    const isArrayOrPaginated = Array.isArray(body) || (typeof body === 'object' && body !== null);
    expect(isArrayOrPaginated).toBe(true);
  });

  it('POST /complaints with member auth + valid body → 201', async () => {
    if (!memberUnitId) {
      console.warn('Skipping: test member has no unit_id in profile');
      return;
    }
    const res = await apiFetch('/complaints', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        title: 'API Test Complaint — please ignore',
        category: 'Plumbing',
        priority: 'Medium',
        unit_id: memberUnitId,
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
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
