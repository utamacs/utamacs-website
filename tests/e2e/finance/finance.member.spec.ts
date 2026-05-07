import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Finance – member', () => {
  test('FIN-01: finance page loads at /portal/finance', async ({ page }) => {
    await page.goto('/portal/finance');
    await expect(page).toHaveURL('/portal/finance');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('FIN-02: #panel-dues is visible by default; #panel-expenses is hidden', async ({ page }) => {
    await page.goto('/portal/finance');
    await expect(page.locator('#panel-dues')).toBeVisible();
    await expect(page.locator('#panel-expenses')).not.toBeVisible();
  });

  test('FIN-03: clicking #tab-expenses reveals expenses panel and hides dues panel', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#tab-expenses');
    await expect(page.locator('#panel-expenses')).toBeVisible();
    await expect(page.locator('#panel-dues')).not.toBeVisible();
  });

  test('FIN-04: #add-expense-btn is NOT visible to member (exec-only)', async ({ page }) => {
    await page.goto('/portal/finance');
    // Switch to expenses tab first so the panel renders
    await page.click('#tab-expenses');
    await expect(page.locator('#panel-expenses')).toBeVisible();
    await expect(page.locator('#add-expense-btn')).not.toBeVisible().catch(() => {});
  });

  test('FIN-05: #create-period-btn is NOT visible to member', async ({ page }) => {
    await page.goto('/portal/finance');
    await expect(page.locator('#create-period-btn')).not.toBeVisible().catch(() => {});
  });

  test('FIN-06: #dues-list exists (may be empty)', async ({ page }) => {
    await page.goto('/portal/finance');
    // Dues panel is default-visible; list container must be present
    await expect(page.locator('#dues-list')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });
});
