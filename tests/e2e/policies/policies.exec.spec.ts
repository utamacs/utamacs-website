import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Policies – executive', () => {
  test('POL-E01: policies page loads for exec without redirect', async ({ page }) => {
    await page.goto('/portal/policies');
    await expect(page).toHaveURL('/portal/policies');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('POL-E02: exec sees a button to create a new policy', async ({ page }) => {
    await page.goto('/portal/policies');
    // Button label may vary — accept any variant
    const createBtn = page.locator(
      'button:has-text("New Policy"), button:has-text("Create Policy"), button:has-text("Add Policy"), a:has-text("New Policy"), a:has-text("Create Policy"), a:has-text("Add Policy")'
    );
    await expect(createBtn.first()).toBeVisible({ timeout: 10000 });
  });

  test('POL-E03: no 500 error on policies page for exec', async ({ page }) => {
    await page.goto('/portal/policies');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });
});
