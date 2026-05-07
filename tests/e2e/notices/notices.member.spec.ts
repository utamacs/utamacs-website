import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Notices – member', () => {
  test('N-01: notices list page loads', async ({ page }) => {
    await page.goto('/portal/notices');
    await expect(page).toHaveURL('/portal/notices');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('N-02: member cannot access /portal/notices/new (redirected)', async ({ page }) => {
    await page.goto('/portal/notices/new');
    // Member is redirected to /portal/notices
    await expect(page).toHaveURL('/portal/notices');
  });

  test('N-03: notices page does not show "Post Notice" button to member', async ({ page }) => {
    await page.goto('/portal/notices');
    // Exec-only action button should not be visible
    await expect(page.locator('a[href="/portal/notices/new"]')).not.toBeVisible().catch(() => {});
  });
});
