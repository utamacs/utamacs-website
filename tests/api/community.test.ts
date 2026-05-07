import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Community API', () => {
  describe('Posts', () => {
    it('GET /community/posts without auth → 401', async () => {
      const res = await apiFetch('/community/posts', { role: 'none' });
      expect(res.status).toBe(401);
    });

    it('GET /community/posts with member auth → 200, array', async () => {
      const res = await apiFetch('/community/posts', { role: 'member' });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body)).toBe(true);
    });

    it('POST /community/posts with member auth + valid body → 201', async () => {
      const res = await apiFetch('/community/posts', {
        method: 'POST',
        role: 'member',
        body: JSON.stringify({
          title: 'API Test Post',
          body: 'Test post from Vitest API test suite. This content is for testing only.',
          category: 'General',
        }),
      });
      expect(res.status).toBe(201);
    });

    it('POST /community/posts with empty body → 400', async () => {
      const res = await apiFetch('/community/posts', {
        method: 'POST',
        role: 'member',
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(400);
    });

    it('POST /community/posts missing title → 400', async () => {
      const res = await apiFetch('/community/posts', {
        method: 'POST',
        role: 'member',
        body: JSON.stringify({ body: 'Content without a title', category: 'general' }),
      });
      expect(res.status).toBe(400);
    });
  });

  describe('Reports (moderation)', () => {
    it('PATCH /community/reports with member auth → 403 (needs community.moderate)', async () => {
      const res = await apiFetch('/community/reports', {
        method: 'PATCH',
        role: 'member',
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(403);
    });
  });
});
