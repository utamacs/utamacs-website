import { test, expect } from '@playwright/test';

// Unauthenticated redirect tests — no stored auth, no manual login.
// These run in the "public" project (no storageState).

test.describe('Unauthenticated access redirects', () => {
  const protectedRoutes = [
    '/portal',
    '/portal/members',
    '/portal/complaints',
    '/portal/notices',
    '/portal/parking',
    '/portal/finance',
    '/portal/visitors',
    '/portal/admin',
  ];

  for (const route of protectedRoutes) {
    test(`RG-08: unauthenticated → ${route} redirects to login`, async ({ page }) => {
      await page.goto(route);
      await expect(page).toHaveURL(/\/portal\/login/);
    });
  }
});
