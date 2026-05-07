import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Members API', () => {
  it('GET /members/me without auth → 401', async () => {
    const res = await apiFetch('/members/me', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /members/me with member auth → 200 with id field', async () => {
    const res = await apiFetch('/members/me', { role: 'member' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toHaveProperty('id');
  });

  it('GET /members with member auth → 200', async () => {
    const res = await apiFetch('/members', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('GET /members/export with member auth → 403', async () => {
    const res = await apiFetch('/members/export', { role: 'member' });
    expect(res.status).toBe(403);
  });

  // export requires users.view_directory — exec role does not have this by default
  // (only secretary and president have it); exec gets 403 too
  it('GET /members/export with exec auth → 403 (needs users.view_directory, assigned to secretary+)', async () => {
    const res = await apiFetch('/members/export', { role: 'exec' });
    expect(res.status).toBe(403);
  });

  it('GET /members/export with admin auth → 200', async () => {
    const res = await apiFetch('/members/export', { role: 'admin' });
    expect(res.status).toBe(200);
  });
});
