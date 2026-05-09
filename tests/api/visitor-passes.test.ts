import { describe, it, expect, beforeAll } from 'vitest';
import { apiFetch } from './helpers/auth';

let memberUnitId: string | null = null;

beforeAll(async () => {
  try {
    const res = await apiFetch('/members/me', { role: 'member' });
    if (res.ok) {
      const profile = await res.json() as any;
      memberUnitId = profile.unit_id ?? null;
    }
  } catch { /* ignore */ }
});

describe('Visitor Passes — /visitors/passes', () => {
  // ── Auth enforcement on list ──────────────────────────────────────────────
  it('GET /visitors/passes without auth → 401', async () => {
    const res = await apiFetch('/visitors/passes', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /visitors/passes with member auth → 200 (own passes only)', async () => {
    const res = await apiFetch('/visitors/passes', { role: 'member' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body) || typeof body === 'object').toBe(true);
  });

  it('GET /visitors/passes with guard auth → 200', async () => {
    const res = await apiFetch('/visitors/passes', { role: 'guard' });
    expect(res.status).toBe(200);
  });

  it('GET /visitors/passes with exec auth → 200', async () => {
    const res = await apiFetch('/visitors/passes', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  // ── POST validation ───────────────────────────────────────────────────────
  it('POST /visitors/passes without auth → 401', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'none',
      body: JSON.stringify({ visitor_name: 'Test' }),
    });
    expect(res.status).toBe(401);
  });

  it('POST /visitors/passes missing visitor_name → 400', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        unit_id: '00000000-0000-0000-0000-000000000001',
        valid_from: new Date().toISOString(),
        valid_until: new Date(Date.now() + 3_600_000).toISOString(),
      }),
    });
    expect(res.status).toBe(400);
    const body = await res.json() as any;
    expect(body.error).toBe('VALIDATION_ERROR');
  });

  it('POST /visitors/passes missing unit_id → 400', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'Test',
        valid_from: new Date().toISOString(),
        valid_until: new Date(Date.now() + 3_600_000).toISOString(),
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /visitors/passes with invalid unit_id UUID → 400', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'Test',
        unit_id: 'not-a-uuid',
        valid_from: new Date().toISOString(),
        valid_until: new Date(Date.now() + 3_600_000).toISOString(),
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /visitors/passes missing valid_from or valid_until → 400', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'Test',
        unit_id: '00000000-0000-0000-0000-000000000001',
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /visitors/passes with valid_until before valid_from → 400', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'Test',
        unit_id: '00000000-0000-0000-0000-000000000001',
        valid_from: new Date(Date.now() + 3_600_000).toISOString(),
        valid_until: new Date().toISOString(), // before valid_from
      }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /visitors/passes with nonexistent unit → 404', async () => {
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'Test Visitor',
        unit_id: '00000000-0000-0000-0000-000000000999',
        valid_from: new Date().toISOString(),
        valid_until: new Date(Date.now() + 3_600_000).toISOString(),
      }),
    });
    expect(res.status).toBe(404);
  });

  // ── Happy path: CREATE with real unit ────────────────────────────────────
  it('POST /visitors/passes with valid body → 201', async () => {
    if (!memberUnitId) {
      console.warn('Skipping: test member has no unit_id in profile');
      return;
    }
    const now = new Date();
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'API Test Visitor Pass',
        purpose: 'Integration test',
        unit_id: memberUnitId,
        valid_from: now.toISOString(),
        valid_until: new Date(now.getTime() + 2 * 3_600_000).toISOString(), // 2 hours
        max_uses: 1,
        vehicle_number: 'TS01AA9999',
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    expect(body).toHaveProperty('id');
    expect(body).toHaveProperty('pass_token');
    expect(body).toHaveProperty('otp_code');
    expect(typeof body.otp_code).toBe('string');
    expect(body.otp_code).toHaveLength(6);
  });

  // ── Duration limit (rule VISITOR_PASS_MAX_HOURS) ──────────────────────────
  it('POST /visitors/passes exceeding max hours → 400 or 422', async () => {
    if (!memberUnitId) return;
    const now = new Date();
    const res = await apiFetch('/visitors/passes', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        visitor_name: 'Long Pass Attempt',
        unit_id: memberUnitId,
        valid_from: now.toISOString(),
        valid_until: new Date(now.getTime() + 200 * 3_600_000).toISOString(), // 200 hours
      }),
    });
    // Rule engine controls max hours; expect rejection
    expect([400, 422]).toContain(res.status);
  });
});
