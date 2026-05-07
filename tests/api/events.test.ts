import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Events API', () => {
  it('GET /events without auth → 401', async () => {
    const res = await apiFetch('/events', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /events with member auth → 200, array', async () => {
    const res = await apiFetch('/events', { role: 'member' });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  it('POST /events with member auth → 403 (lacks events.manage)', async () => {
    const res = await apiFetch('/events', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        title: 'API Test Event',
        event_date: '2026-12-31',
        event_time: '18:00',
        venue: 'Clubhouse',
        capacity: 50,
        is_public: true,
      }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /events with exec auth + valid body → 201', async () => {
    const res = await apiFetch('/events', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        title: 'API Test Event',
        event_date: '2026-12-31',
        event_time: '18:00',
        venue: 'Clubhouse',
        capacity: 50,
        is_public: true,
      }),
    });
    expect(res.status).toBe(201);
  });

  it('POST /events with exec auth + empty body → 400', async () => {
    const res = await apiFetch('/events', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });
});
