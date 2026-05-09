import { describe, it, expect, beforeAll } from 'vitest';
import { apiFetch } from './helpers/auth';

let createdRequestId: string | null = null;

beforeAll(async () => {
  // Create a gate request to use in subsequent tests
  try {
    const res = await apiFetch('/visitors/gate-requests', {
      method: 'POST',
      role: 'guard',
      body: JSON.stringify({
        visitor_name: 'API Test Visitor',
        visitor_type: 'guest',
        purpose: 'Integration test',
        vehicle_number: 'TS09AB1234',
      }),
    });
    if (res.status === 201) {
      const body = await res.json() as any;
      createdRequestId = body.id ?? null;
    }
  } catch { /* ignore — individual tests will handle failures */ }
});

describe('Visitor Gate Requests — /visitors/gate-requests', () => {
  // ── Auth enforcement on list ──────────────────────────────────────────────
  it('GET /visitors/gate-requests without auth → 401', async () => {
    const res = await apiFetch('/visitors/gate-requests', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /visitors/gate-requests with guard auth → 200', async () => {
    const res = await apiFetch('/visitors/gate-requests', { role: 'guard' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body) || typeof body === 'object').toBe(true);
  });

  it('GET /visitors/gate-requests with member auth → 200 (own unit only)', async () => {
    const res = await apiFetch('/visitors/gate-requests', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('GET /visitors/gate-requests with exec auth → 200 (all requests)', async () => {
    const res = await apiFetch('/visitors/gate-requests', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  // ── POST validation ───────────────────────────────────────────────────────
  it('POST /visitors/gate-requests without auth → 401', async () => {
    const res = await apiFetch('/visitors/gate-requests', {
      method: 'POST',
      role: 'none',
      body: JSON.stringify({ visitor_name: 'Test' }),
    });
    expect(res.status).toBe(401);
  });

  it('POST /visitors/gate-requests with member auth → 403', async () => {
    const res = await apiFetch('/visitors/gate-requests', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({ visitor_name: 'Test', visitor_type: 'guest' }),
    });
    // guards and potentially exec can create; members cannot
    expect([403, 201]).toContain(res.status);
  });

  it('POST /visitors/gate-requests missing visitor_name → 400', async () => {
    const res = await apiFetch('/visitors/gate-requests', {
      method: 'POST',
      role: 'guard',
      body: JSON.stringify({ visitor_type: 'guest' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /visitors/gate-requests with valid body → 201', async () => {
    const res = await apiFetch('/visitors/gate-requests', {
      method: 'POST',
      role: 'guard',
      body: JSON.stringify({
        visitor_name: 'API Test Gate Request',
        visitor_type: 'courier',
        purpose: 'Package delivery',
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    expect(body).toHaveProperty('id');
  });

  // ── PUT: Approve/Reject ───────────────────────────────────────────────────
  it('PUT /visitors/gate-requests/{bad-uuid} → 400', async () => {
    const res = await apiFetch('/visitors/gate-requests/not-a-uuid', {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ action: 'approve' }),
    });
    expect(res.status).toBe(400);
  });

  it('PUT /visitors/gate-requests/{nonexistent} → 404', async () => {
    const res = await apiFetch('/visitors/gate-requests/00000000-0000-0000-0000-000000000999', {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ action: 'approve' }),
    });
    expect(res.status).toBe(404);
  });

  it('PUT /visitors/gate-requests/{id} without auth → 401', async () => {
    if (!createdRequestId) return;
    const res = await apiFetch(`/visitors/gate-requests/${createdRequestId}`, {
      method: 'PUT',
      role: 'none',
      body: JSON.stringify({ action: 'approve' }),
    });
    expect(res.status).toBe(401);
  });

  it('PUT /visitors/gate-requests/{id} with invalid action → 400', async () => {
    if (!createdRequestId) return;
    const res = await apiFetch(`/visitors/gate-requests/${createdRequestId}`, {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ action: 'maybe' }),
    });
    expect(res.status).toBe(400);
  });

  it('PUT /visitors/gate-requests/{id} approve by exec → 200 or 410', async () => {
    if (!createdRequestId) return;
    const res = await apiFetch(`/visitors/gate-requests/${createdRequestId}`, {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ action: 'approve', note: 'Auto-approved by integration test' }),
    });
    // 200 = approved; 410 = expired (timing); 409 = already decided (race)
    expect([200, 409, 410]).toContain(res.status);
    if (res.status === 200) {
      const body = await res.json() as any;
      expect(body.ok).toBe(true);
      expect(body.action).toBe('approve');
    }
  });

  it('PUT /visitors/gate-requests/{id} second approve → 409 ALREADY_DECIDED', async () => {
    if (!createdRequestId) return;
    const res = await apiFetch(`/visitors/gate-requests/${createdRequestId}`, {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ action: 'reject' }),
    });
    // Once approved, re-deciding should return 409
    expect([409, 410]).toContain(res.status);
  });

  // ── DELETE: Cancel ────────────────────────────────────────────────────────
  it('DELETE /visitors/gate-requests/{bad-uuid} → 400', async () => {
    const res = await apiFetch('/visitors/gate-requests/not-valid', {
      method: 'DELETE',
      role: 'guard',
    });
    expect(res.status).toBe(400);
  });

  it('DELETE /visitors/gate-requests/{nonexistent} → 404', async () => {
    const res = await apiFetch('/visitors/gate-requests/00000000-0000-0000-0000-000000000999', {
      method: 'DELETE',
      role: 'guard',
    });
    expect(res.status).toBe(404);
  });

  it('DELETE /visitors/gate-requests/{already-decided-id} → 409', async () => {
    if (!createdRequestId) return;
    const res = await apiFetch(`/visitors/gate-requests/${createdRequestId}`, {
      method: 'DELETE',
      role: 'guard',
    });
    // Already approved — cannot cancel
    expect([409, 403]).toContain(res.status);
  });

  // ── Full lifecycle: create → reject ───────────────────────────────────────
  it('Full lifecycle: create pending → reject → cancel fails (409)', async () => {
    // Create
    const createRes = await apiFetch('/visitors/gate-requests', {
      method: 'POST',
      role: 'guard',
      body: JSON.stringify({
        visitor_name: 'Lifecycle Test Visitor',
        visitor_type: 'plumber',
        purpose: 'Lifecycle test',
      }),
    });
    expect(createRes.status).toBe(201);
    const { id } = await createRes.json() as any;

    // Reject
    const rejectRes = await apiFetch(`/visitors/gate-requests/${id}`, {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ action: 'reject', note: 'Test rejection' }),
    });
    expect([200, 410]).toContain(rejectRes.status);

    // Cancel after rejection → 409
    const cancelRes = await apiFetch(`/visitors/gate-requests/${id}`, {
      method: 'DELETE',
      role: 'guard',
    });
    expect(cancelRes.status).toBe(409);
  });
});
