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

    it('GET /finance/expenses with exec auth → 200', async () => {
      const res = await apiFetch('/finance/expenses', { role: 'exec' });
      expect(res.status).toBe(200);
    });

    it('POST /finance/expenses with member auth → 403', async () => {
      const res = await apiFetch('/finance/expenses', {
        method: 'POST',
        role: 'member',
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

    it('POST /finance/expenses with exec auth + valid body → 201', async () => {
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
      expect(res.status).toBe(201);
    });

    it('POST /finance/expenses with exec auth + empty body → 400', async () => {
      const res = await apiFetch('/finance/expenses', {
        method: 'POST',
        role: 'exec',
        body: JSON.stringify({}),
      });
      expect(res.status).toBe(400);
    });
  });
});
