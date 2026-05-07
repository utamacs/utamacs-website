import { test, expect } from '@playwright/test';

// Runs with guard storageState

test.describe('Dashboard – security guard role', () => {
  test('D-12: guard dashboard shows Security Dashboard heading', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('h2')).toContainText('Security Dashboard');
  });

  test('D-13: guard dashboard shows Go to Visitor Management button', async ({ page }) => {
    await page.goto('/portal');
    // Use btn-primary class to target the dashboard widget link, not the nav sidebar link
    await expect(page.locator('a.btn-primary[href="/portal/visitors"]')).toContainText('Go to Visitor Management');
  });

  test('D-14: guard nav shows only Visitor Management', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).toContainText('Visitor Management');
    await expect(page.locator('nav')).not.toContainText('Complaints');
    await expect(page.locator('nav')).not.toContainText('Member Directory');
  });
});
