import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Community Board – executive', () => {
  test('COM-E01: community page loads for exec', async ({ page }) => {
    await page.goto('/portal/community');
    await expect(page).toHaveURL('/portal/community');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('COM-E02: /portal/admin/moderation loads for exec', async ({ page }) => {
    await page.goto('/portal/admin/moderation');
    await expect(page).toHaveURL('/portal/admin/moderation');
    await expect(page.locator('body')).not.toContainText('Sign In');
    await expect(page.locator('body')).not.toContainText('Forbidden');
    await expect(page.locator('body')).not.toContainText('403');
  });

  test('COM-E03: moderation page has h1 visible', async ({ page }) => {
    await page.goto('/portal/admin/moderation');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('COM-E04: moderation page does not show 500 error', async ({ page }) => {
    await page.goto('/portal/admin/moderation');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });
});
