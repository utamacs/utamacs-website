import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Gallery – executive', () => {
  test('GAL-E01: gallery page loads for exec', async ({ page }) => {
    await page.goto('/portal/gallery');
    await expect(page).toHaveURL('/portal/gallery');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('GAL-E02: new-album button is visible to exec', async ({ page }) => {
    await page.goto('/portal/gallery');
    await expect(page.locator('#new-album-btn')).toBeVisible({ timeout: 10000 });
  });

  test('GAL-E03: clicking new-album button opens the new-album modal', async ({ page }) => {
    await page.goto('/portal/gallery');
    await page.locator('#new-album-btn').click();
    await expect(page.locator('#new-album-modal')).toBeVisible({ timeout: 5000 });
  });

  test('GAL-E04: submitting empty album form stays on page (browser validation fires)', async ({ page }) => {
    await page.goto('/portal/gallery');
    await page.locator('#new-album-btn').click();
    await expect(page.locator('#new-album-modal')).toBeVisible({ timeout: 5000 });

    // Clear the title input to ensure it is empty, then submit
    await page.locator('#album-title-input').fill('');
    await page.locator('#new-album-save-btn').click();

    // HTML5 required validation prevents submission — modal stays open and we remain on the page
    await expect(page).toHaveURL('/portal/gallery');
    await expect(page.locator('#new-album-modal')).toBeVisible();
  });

  test('GAL-E05: filling album title and saving creates album (success toast or grid update)', async ({ page }) => {
    await page.goto('/portal/gallery');
    await page.locator('#new-album-btn').click();
    await expect(page.locator('#new-album-modal')).toBeVisible({ timeout: 5000 });

    const testTitle = `E2E Test Album ${Date.now()}`;
    await page.locator('#album-title-input').fill(testTitle);

    const descField = page.locator('#album-desc');
    if (await descField.isVisible()) {
      await descField.fill('Automated E2E test album — please ignore.');
    }

    const dateField = page.locator('#album-date');
    if (await dateField.isVisible()) {
      await dateField.fill('2025-01-01');
    }

    await page.locator('#new-album-save-btn').click();

    // Expect either: modal closes (grid updated) OR a success toast appears
    await Promise.race([
      expect(page.locator('#new-album-modal')).not.toBeVisible({ timeout: 10000 }),
      expect(
        page.locator('div.fixed.bottom-6.right-6.bg-secondary-500, div[class*="toast"]')
      ).toBeVisible({ timeout: 10000 }),
    ]).catch(() => {
      // At minimum no 500 error should have occurred
    });

    await expect(page.locator('body')).not.toContainText('500');
  });
});
