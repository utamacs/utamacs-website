import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Maids API', () => {
  it('GET /maids without auth → 401', async () => {
    const res = await apiFetch('/maids', { role: 'none' });
    expect(res.status).toBe(401);
  });

  // member has maids.approve but NOT maids.view — list requires maids.view
  it('GET /maids with member auth → 403 (needs maids.view, member only has maids.approve)', async () => {
    const res = await apiFetch('/maids', { role: 'member' });
    expect(res.status).toBe(403);
  });

  it('GET /maids with exec auth → 200', async () => {
    const res = await apiFetch('/maids', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  it('POST /maids with member auth → 403 (needs maids.manage)', async () => {
    const res = await apiFetch('/maids', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({ full_name: 'API Test Helper', work_type: 'cleaning', is_active: true }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /maids with exec auth + valid body → 201', async () => {
    const res = await apiFetch('/maids', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ full_name: 'API Test Helper', work_type: 'cleaning', is_active: true }),
    });
    expect(res.status).toBe(201);
  });

  // approvals list also requires maids.view (not just maids.approve)
  it('GET /maids/approvals with member auth → 403 (needs maids.view)', async () => {
    const res = await apiFetch('/maids/approvals', { role: 'member' });
    expect(res.status).toBe(403);
  });

  it('GET /maids/approvals with exec auth → 200', async () => {
    const res = await apiFetch('/maids/approvals', { role: 'exec' });
    expect(res.status).toBe(200);
  });
});
