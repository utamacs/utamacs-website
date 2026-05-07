import { test, expect } from '@playwright/test';

// Runs with admin storageState

test.describe('Admin – admin role access', () => {
  test('AD-01: admin hub loads', async ({ page }) => {
    await page.goto('/portal/admin');
    await expect(page).toHaveURL('/portal/admin');
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('AD-02: feature flags page loads', async ({ page }) => {
    await page.goto('/portal/admin/features');
    await expect(page).toHaveURL('/portal/admin/features');
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('AD-03: audit logs page loads', async ({ page }) => {
    await page.goto('/portal/admin/audit');
    await expect(page).toHaveURL('/portal/admin/audit');
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('AD-04: RBAC page loads', async ({ page }) => {
    await page.goto('/portal/admin/rbac');
    await expect(page).toHaveURL('/portal/admin/rbac');
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('AD-05: analytics page loads for admin', async ({ page }) => {
    await page.goto('/portal/analytics');
    await expect(page).toHaveURL('/portal/analytics');
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('AD-06: official letters page loads for admin', async ({ page }) => {
    await page.goto('/portal/letters');
    await expect(page).toHaveURL('/portal/letters');
    await expect(page.locator('body')).not.toContainText('500');
  });
});
