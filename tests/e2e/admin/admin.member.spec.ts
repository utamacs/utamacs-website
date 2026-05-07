import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Admin – member access denied', () => {
  const adminRoutes = [
    '/portal/admin',
    '/portal/admin/features',
    '/portal/admin/rbac',
    '/portal/admin/rules',
    '/portal/admin/staff',
    '/portal/letters',
    '/portal/analytics',
  ];

  for (const route of adminRoutes) {
    test(`AD-deny: member redirected from ${route}`, async ({ page }) => {
      await page.goto(route);
      await expect(page).not.toHaveURL(route, { timeout: 10000 });
    });
  }
});

test.describe('Role gates – member cannot access exec-only pages', () => {
  test('RG-01: member redirected away from /portal/notices/new', async ({ page }) => {
    await page.goto('/portal/notices/new');
    await expect(page).not.toHaveURL('/portal/notices/new');
    await expect(page).toHaveURL(/\/portal\/notices/);
  });

  test('RG-02: member redirected away from /portal/admin', async ({ page }) => {
    await page.goto('/portal/admin');
    await expect(page).not.toHaveURL('/portal/admin');
  });

  test('RG-03: member redirected away from /portal/letters', async ({ page }) => {
    await page.goto('/portal/letters');
    await expect(page).not.toHaveURL('/portal/letters');
  });

  test('RG-04: member redirected away from /portal/analytics', async ({ page }) => {
    await page.goto('/portal/analytics');
    await expect(page).not.toHaveURL('/portal/analytics');
  });
});
