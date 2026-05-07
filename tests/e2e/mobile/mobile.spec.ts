import { test, expect } from '@playwright/test';

// Runs with member storageState on iPhone 14 viewport

test.describe('Mobile – golden path', () => {
  test('MOB-01: login page is usable on mobile', async ({ page }) => {
    await page.goto('/portal/login');
    await expect(page.locator('#email')).toBeVisible();
    await expect(page.locator('#password')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('MOB-02: dashboard loads on mobile', async ({ page }) => {
    await page.goto('/portal');
    await expect(page).toHaveURL('/portal');
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('MOB-03: complaints list is readable on mobile', async ({ page }) => {
    await page.goto('/portal/complaints');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('MOB-04: notices list is readable on mobile', async ({ page }) => {
    await page.goto('/portal/notices');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('MOB-05: visitors page renders on mobile', async ({ page }) => {
    await page.goto('/portal/visitors');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });
});
