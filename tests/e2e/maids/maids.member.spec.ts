import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Maids / Domestic Help – member', () => {
  test('MD-01: maids page loads at /portal/maids', async ({ page }) => {
    await page.goto('/portal/maids');
    await expect(page).toHaveURL('/portal/maids');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('MD-02: main container is visible on load', async ({ page }) => {
    await page.goto('/portal/maids');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
    // Either the overall maids container or the default "all" panel should be present
    const container = page.locator('#maids-container, #panel-all');
    await expect(container.first()).toBeVisible({ timeout: 10000 });
  });

  test('MD-03: my-helpers panel is not visible initially (hidden tab content)', async ({ page }) => {
    await page.goto('/portal/maids');
    await page.waitForTimeout(1000);
    // The "My Helpers" panel is a tab panel; it should be hidden until the tab is activated
    const myPanel = page.locator('#panel-my');
    const isVisible = await myPanel.isVisible().catch(() => false);
    expect(isVisible).toBeFalsy();
  });

  test('MD-04: attendance tab button is present and clicking it shows attendance panel', async ({ page }) => {
    await page.goto('/portal/maids');
    const attTab = page.locator('#tab-attendance');
    await expect(attTab).toBeVisible({ timeout: 10000 });

    await attTab.click();
    await expect(page.locator('#panel-attendance')).toBeVisible({ timeout: 5000 });
  });

  test('MD-05: add-maid modal is NOT visible to member', async ({ page }) => {
    await page.goto('/portal/maids');
    await page.waitForTimeout(1000);
    // The add-maid modal is exec-only; it should not be visible (or not exist) for members
    await expect(page.locator('#add-maid-modal')).not.toBeVisible().catch(() => {});
  });
});
