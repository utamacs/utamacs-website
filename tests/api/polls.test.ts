import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Polls API', () => {
  it('GET /polls without auth → 401', async () => {
    const res = await apiFetch('/polls', { role: 'none' });
    expect(res.status).toBe(401);
  });

  it('GET /polls with member auth → 200', async () => {
    const res = await apiFetch('/polls', { role: 'member' });
    expect(res.status).toBe(200);
  });

  it('POST /polls with member auth → 403', async () => {
    const res = await apiFetch('/polls', {
      method: 'POST',
      role: 'member',
      body: JSON.stringify({
        question: 'API Test Poll: Best day?',
        options: ['Monday', 'Saturday'],
        poll_type: 'single',
        ends_at: '2026-12-31T23:59:59Z',
      }),
    });
    expect(res.status).toBe(403);
  });

  it('POST /polls with exec auth + valid body → 201', async () => {
    const res = await apiFetch('/polls', {
      method: 'POST',
      role: 'exec',
      body: JSON.stringify({
        question: 'API Test Poll: Best day?',
        options: ['Monday', 'Saturday'],
        poll_type: 'single',
        ends_at: '2026-12-31T23:59:59Z',
      }),
    });
    expect(res.status).toBe(201);
  });
});
