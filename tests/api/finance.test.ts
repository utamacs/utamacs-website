import { describe, it, expect } from 'vitest';
import { apiFetch } from './helpers/auth';

describe('Finance API', () => {
  describe('Dues', () => {
    it('GET /finance/dues without auth → 401', async () => {
      const res = await apiFetch('/finance/dues', { role: 'none' });
      expect(res.status).toBe(401);
    });

    it('GET /finance/dues with member auth → 200', async () => {
      const res = await apiFetch('/finance/dues', { role: 'member' });
      expect(res.status).toBe(200);
    });
  });

  describe('Expenses', () => {
    it('GET /finance/expenses without auth → 401', async () => {
      const res = await apiFetch('/finance/expenses', { role: 'none' });
      expect(res.status).toBe(401);
    });

    // finance.view is not in DEFAULT_ROLE_PERMISSIONS.executive — only treasurer-titled execs get it
    it('GET /finance/expenses with exec auth → 403 (needs finance.view, assigned to treasurer+)', async () => {
      const res = await apiFetch('/finance/expenses', { role: 'exec' });
      expect(res.status).toBe(403);
    });

    it('POST /finance/expenses with member auth → 403', async () => {
      const res = await apiFetch('/finance/expenses', {
        method: 'POST',
        role: 'member',
        body: JSON.stringify({ description: 'Test', amount: 1000 }),
      });
      expect(res.status).toBe(403);
    });

    // finance.enter requires a treasurer user_feature_override — exec alone does not have it
    // This 403 is correct RBAC behaviour; only a treasurer-titled exec can POST expenses
    it('POST /finance/expenses with exec auth → 403 (needs finance.enter treasurer override)', async () => {
      const res = await apiFetch('/finance/expenses', {
        method: 'POST',
        role: 'exec',
        body: JSON.stringify({
          description: 'API Test Expense',
          amount: 1000,
          gst_amount: 180,
          tds_deducted: 0,
          bill_date: '2026-01-15',
        }),
      });
      expect(res.status).toBe(403);
    });

    // auth check fires before body validation, so empty body also returns 403 for exec
    it('POST /finance/expenses with exec auth + empty body → 403 (auth before validation)', async () => {
      const res = await apiFetch('/finance/expenses', {
        method: 'POST',
        role: 'exec',
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(403);
    });
  });
});
