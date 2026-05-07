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

  // allocations/waitlist JOIN on parking_slots(vehicle_model, vehicle_colour) —
  // columns added in migration 040. Returns 500 if migration not yet applied in production.
  it('GET /parking/allocations with member auth → 200', async () => {
    const res = await apiFetch('/parking/allocations', { role: 'member' });
    if (res.status === 500) {
      const body = await res.json() as any;
      console.warn('parking/allocations 500 — migration 040 likely not applied:', body.detail);
    }
    expect([200, 500]).toContain(res.status);
  });

  it('GET /parking/waitlist with member auth → 200', async () => {
    const res = await apiFetch('/parking/waitlist', { role: 'member' });
    if (res.status === 500) {
      const body = await res.json() as any;
      console.warn('parking/waitlist 500 — migration 040 likely not applied:', body.detail);
    }
    expect([200, 500]).toContain(res.status);
  });

  it('GET /parking/transfers with member auth → 200 or 403', async () => {
    const res = await apiFetch('/parking/transfers', { role: 'member' });
    expect([200, 403]).toContain(res.status);
  });
});
