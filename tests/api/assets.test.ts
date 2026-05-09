import { describe, it, expect, beforeAll } from 'vitest';
import { apiFetch } from './helpers/auth';

let createdAssetId: string | null = null;
let createdLogId: string | null = null;

describe('Assets API — /admin/assets', () => {
  // ── Auth enforcement ──────────────────────────────────────────────────────
  it('GET /admin/assets without auth → 401', async () => {
    const res = await apiFetch('/admin/assets', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /admin/assets with member auth → 403', async () => {
    const res = await apiFetch('/admin/assets', { role: 'member' });
    expect(res.status).toBe(403);
  });

  it('GET /admin/assets with exec auth → 200', async () => {
    const res = await apiFetch('/admin/assets', { role: 'exec' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body) || typeof body === 'object').toBe(true);
  });

  // ── Listing filters ───────────────────────────────────────────────────────
  it('GET /admin/assets?status=active → 200 with status filter', async () => {
    const res = await apiFetch('/admin/assets?status=active', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  it('GET /admin/assets?category=electrical → 200', async () => {
    const res = await apiFetch('/admin/assets?category=electrical', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  // ── Validation errors on POST ─────────────────────────────────────────────
  it('POST /admin/assets with empty body → 400', async () => {
    const res = await apiFetch('/admin/assets', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it('POST /admin/assets missing category → 400', async () => {
    const res = await apiFetch('/admin/assets', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ name: 'Test Asset' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /admin/assets with invalid category → 400', async () => {
    const res = await apiFetch('/admin/assets', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ name: 'Test Asset', category: 'invalid_category' }),
    });
    expect(res.status).toBe(400);
  });

  // ── Happy path: CREATE ────────────────────────────────────────────────────
  it('POST /admin/assets with valid body → 201', async () => {
    const res = await apiFetch('/admin/assets', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        name: 'API Test Asset — please ignore',
        category: 'electrical',
        status: 'active',
        make: 'TestMake',
        model: 'TM-001',
        purchase_date: '2024-01-01',
        purchase_cost: 10000,
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    expect(body).toHaveProperty('id');
    createdAssetId = body.id;
  });

  // ── Read single asset ─────────────────────────────────────────────────────
  it('GET /admin/assets/{id} → 200', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}`, { role: 'exec' });
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.id).toBe(createdAssetId);
    expect(body.name).toBe('API Test Asset — please ignore');
  });

  it('GET /admin/assets/not-a-uuid → 400', async () => {
    const res = await apiFetch('/admin/assets/not-a-uuid', { role: 'exec' });
    expect([400, 404]).toContain(res.status);
  });

  it('GET /admin/assets/00000000-0000-0000-0000-000000000999 → 404', async () => {
    const res = await apiFetch('/admin/assets/00000000-0000-0000-0000-000000000999', { role: 'exec' });
    expect(res.status).toBe(404);
  });

  // ── UPDATE asset ──────────────────────────────────────────────────────────
  it('PUT /admin/assets/{id} updates asset → 200', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}`, {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ make: 'UpdatedMake', model: 'TM-002' }),
    });
    expect(res.status).toBe(200);
  });

  it('PUT /admin/assets/{id} with invalid category → 400', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}`, {
      method: 'PUT',
      role: 'exec',
      body: JSON.stringify({ category: 'bad_cat' }),
    });
    expect(res.status).toBe(400);
  });

  // ── Service logs ─────────────────────────────────────────────────────────
  it('GET /admin/assets/{id}/service-logs → 200', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}/service-logs`, { role: 'exec' });
    expect(res.status).toBe(200);
    expect(Array.isArray(await res.json())).toBe(true);
  });

  it('POST /admin/assets/{id}/service-logs with missing fields → 400', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}/service-logs`, {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ description: 'Missing required fields' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /admin/assets/{id}/service-logs with valid body → 201', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}/service-logs`, {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        service_date: '2024-03-01',
        service_type: 'Routine Inspection',
        description: 'API test service log — please ignore',
        cost: 500,
        next_service_date: '2025-03-01',
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    expect(body).toHaveProperty('id');
    createdLogId = body.id;
  });

  // ── Service logs auth ─────────────────────────────────────────────────────
  it('GET /admin/assets/{id}/service-logs without auth → 401', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}/service-logs`, { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /admin/assets/{id}/service-logs with member → 403', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}/service-logs`, { role: 'member' });
    expect(res.status).toBe(403);
  });

  // ── DELETE (soft-delete) ──────────────────────────────────────────────────
  it('DELETE /admin/assets/{id} → 200 (soft-delete)', async () => {
    if (!createdAssetId) return;
    const res = await apiFetch(`/admin/assets/${createdAssetId}`, {
      method: 'DELETE',
      role: 'exec',
    });
    expect(res.status).toBe(200);
  });

  it('DELETE /admin/assets/{id} with member auth → 403', async () => {
    const res = await apiFetch('/admin/assets/00000000-0000-0000-0000-000000000001', {
      method: 'DELETE',
      role: 'member',
    });
    expect(res.status).toBe(403);
  });
});
