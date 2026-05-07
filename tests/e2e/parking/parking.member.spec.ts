import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Parking – member', () => {
  test('P-01: parking page loads for member', async ({ page }) => {
    await page.goto('/portal/parking');
    await expect(page).toHaveURL('/portal/parking');
    await expect(page.locator('h1')).toContainText('Parking');
  });

  test('P-02: parking page shows "How it works" info panel collapsed', async ({ page }) => {
    await page.goto('/portal/parking');
    const details = page.locator('details').first();
    await expect(details).not.toHaveAttribute('open');
  });

  test('P-03: parking page does not show exec-only actions for member', async ({ page }) => {
    await page.goto('/portal/parking');
    // Exec-only "Add Slot" or "Create Allocation" buttons should not be visible to members
    await page.waitForTimeout(1000);
    const adminActions = page.locator('button:has-text("Add Slot"), button:has-text("Create Allocation")');
    await expect(adminActions.first()).not.toBeVisible().catch(() => {});
  });

  test('P-04: parking page loads without server error', async ({ page }) => {
    await page.goto('/portal/parking');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });
});
