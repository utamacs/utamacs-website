import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Parking API', () => {
  it('GET /parking/slots without auth → 401', async () => {
    const res = await apiFetch('/parking/slots', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /parking/slots with member auth → 200', async () => {
    const res = await apiFetch('/parking/slots', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('GET /parking/allocations with member auth → 200', async () => {
    const res = await apiFetch('/parking/allocations', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('GET /parking/waitlist with member auth → 200', async () => {
    const res = await apiFetch('/parking/waitlist', { role: 'member' });
    expect(res.status).toBe(200);
  });
});
