import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Visitors – member', () => {
  test('V-05: member can access /portal/visitors', async ({ page }) => {
    await page.goto('/portal/visitors');
    await expect(page).toHaveURL('/portal/visitors');
    await expect(page.locator('h1')).toContainText('Visitor Management');
  });

  test('V-06: visitor management page loads without error', async ({ page }) => {
    await page.goto('/portal/visitors');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });
});
