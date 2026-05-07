import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Parking – executive', () => {
  test('P-05: exec sees parking management page', async ({ page }) => {
    await page.goto('/portal/parking');
    await expect(page).toHaveURL('/portal/parking');
  });

  test('P-06: exec parking page loads without error', async ({ page }) => {
    await page.goto('/portal/parking');
    await expect(page.locator('body')).not.toContainText('500');
  });
});
