import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Dashboard – executive role', () => {
  test('D-07: exec dashboard loads at /portal', async ({ page }) => {
    await page.goto('/portal');
    await expect(page).toHaveURL('/portal');
  });

  test('D-08: exec nav shows Analytics & Reports', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).toContainText('Analytics');
  });

  test('D-09: exec nav shows Official Letters', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).toContainText('Official Letters');
  });

  test('D-10: exec nav shows Vendor Procurement', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).toContainText('Vendor Procurement');
  });

  test('D-11: exec nav shows HOTO Progress and Pending Approvals', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).toContainText('HOTO Progress');
    await expect(page.locator('nav')).toContainText('Pending Approvals');
  });
});
