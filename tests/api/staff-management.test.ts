import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

let createdActivityId: string | null = null;
let createdLocationId: string | null = null;

// ── Activity Templates ────────────────────────────────────────────────────────

describe('Staff Management — Activity Templates (/staff-management/activities)', () => {
  it('GET /staff-management/activities without auth → 401', async () => {
    const res = await apiFetch('/staff-management/activities', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /staff-management/activities with member auth → 200', async () => {
    const res = await apiFetch('/staff-management/activities', { role: 'member' });
    expect(res.status).toBe(200);
    expect(Array.isArray(await res.json())).toBe(true);
  });

  it('GET /staff-management/activities?department=security → 200', async () => {
    const res = await apiFetch('/staff-management/activities?department=security', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  it('GET /staff-management/activities?frequency=daily → 200', async () => {
    const res = await apiFetch('/staff-management/activities?frequency=daily', { role: 'exec' });
    expect(res.status).toBe(200);
  });

  // ── POST validation ────────────────────────────────────────────────────────
  it('POST /staff-management/activities without auth → 401', async () => {
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'none',
      body: JSON.stringify({ title: 'Test', department: 'security', frequency: 'daily' }),
    });
    expect(res.status).toBe(401);
  });

  it('POST /staff-management/activities with member auth → 403', async () => {
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({ title: 'Test', department: 'security', frequency: 'daily' }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /staff-management/activities missing title → 400', async () => {
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ department: 'security', frequency: 'daily' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /staff-management/activities invalid department → 400', async () => {
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ title: 'Test', department: 'invalid', frequency: 'daily' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /staff-management/activities invalid frequency → 400', async () => {
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ title: 'Test', department: 'security', frequency: 'hourly' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /staff-management/activities with valid body → 201', async () => {
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        title: 'API Test Activity — please ignore',
        department: 'housekeeping',
        frequency: 'daily',
        estimated_mins: 30,
        requires_photo: false,
        checklist: [
          { text_en: 'Check area is clean', severity: 'warning' },
          { text_en: 'Report any damage', severity: 'critical' },
        ],
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    expect(body).toHaveProperty('id');
    createdActivityId = body.id;
  });

  it('POST /staff-management/activities duplicate title → 409', async () => {
    if (!createdActivityId) return;
    const res = await apiFetch('/staff-management/activities', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        title: 'API Test Activity — please ignore',
        department: 'housekeeping',
        frequency: 'daily',
      }),
    });
    expect(res.status).toBe(409);
  });
});

// ── Locations ─────────────────────────────────────────────────────────────────

describe('Staff Management — Locations (/staff-management/locations)', () => {
  it('GET /staff-management/locations without auth → 401', async () => {
    const res = await apiFetch('/staff-management/locations', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /staff-management/locations with member auth → 200', async () => {
    const res = await apiFetch('/staff-management/locations', { role: 'member' });
    expect(res.status).toBe(200);
    expect(Array.isArray(await res.json())).toBe(true);
  });

  it('GET /staff-management/locations?zone_type=common_area → 200', async () => {
    const res = await apiFetch('/staff-management/locations?zone_type=common_area', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('GET /staff-management/locations?active=false → 200', async () => {
    const res = await apiFetch('/staff-management/locations?active=false', { role: 'member' });
    expect(res.status).toBe(200);
  });

  // ── POST validation ────────────────────────────────────────────────────────
  it('POST /staff-management/locations without auth → 401', async () => {
    const res = await apiFetch('/staff-management/locations', {
      method: 'POST',
      role: 'none',
      body: JSON.stringify({ name: 'Test', zone_type: 'common_area' }),
    });
    expect(res.status).toBe(401);
  });

  it('POST /staff-management/locations with member auth → 403', async () => {
    const res = await apiFetch('/staff-management/locations', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({ name: 'Test', zone_type: 'common_area' }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /staff-management/locations missing name → 400', async () => {
    const res = await apiFetch('/staff-management/locations', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ zone_type: 'common_area' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /staff-management/locations invalid zone_type → 400', async () => {
    const res = await apiFetch('/staff-management/locations', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({ name: 'Test', zone_type: 'rooftop' }),
    });
    expect(res.status).toBe(400);
  });

  it('POST /staff-management/locations with valid body → 201', async () => {
    const res = await apiFetch('/staff-management/locations', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        name: 'API Test Location — please ignore',
        zone_type: 'common_area',
        name_hi: 'टेस्ट स्थान',
        name_te: 'టెస్ట్ స్థానం',
      }),
    });
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    expect(body).toHaveProperty('id');
    createdLocationId = body.id;
  });

  it('POST /staff-management/locations duplicate name → 409', async () => {
    if (!createdLocationId) return;
    const res = await apiFetch('/staff-management/locations', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        name: 'API Test Location — please ignore',
        zone_type: 'utility',
      }),
    });
    expect(res.status).toBe(409);
  });
});
