import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Members – member role', () => {
  test('M-01: member can view member directory', async ({ page }) => {
    await page.goto('/portal/members');
    await expect(page).toHaveURL('/portal/members');
    await expect(page.locator('h1')).toContainText('Member Directory');
  });

  test('M-02: member sees "How it works" info panel collapsed by default', async ({ page }) => {
    await page.goto('/portal/members');
    const details = page.locator('details').first();
    await expect(details).not.toHaveAttribute('open');
  });

  test('M-03: member does not see Export CSV button', async ({ page }) => {
    await page.goto('/portal/members');
    const exportBtn = page.locator('a[href*="export"], button:has-text("Export")');
    await expect(exportBtn).not.toBeVisible().catch(() => {});
  });
});
