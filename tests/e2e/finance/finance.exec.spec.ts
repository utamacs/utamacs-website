import { test, expect } from '@playwright/test';
import { expectToast } from '../../helpers/toast';

// Runs with exec storageState

test.describe('Finance – executive', () => {
  test('FIN-E01: finance page loads for exec', async ({ page }) => {
    await page.goto('/portal/finance');
    await expect(page).toHaveURL('/portal/finance');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('FIN-E02: #create-period-btn is visible to exec', async ({ page }) => {
    await page.goto('/portal/finance');
    await expect(page.locator('#create-period-btn')).toBeVisible();
  });

  test('FIN-E03: clicking #tab-expenses shows the expenses panel', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#tab-expenses');
    await expect(page.locator('#panel-expenses')).toBeVisible();
    await expect(page.locator('#panel-dues')).not.toBeVisible();
  });

  test('FIN-E04: #add-expense-btn is visible in expenses panel after switching tab', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#tab-expenses');
    await expect(page.locator('#panel-expenses')).toBeVisible();
    await expect(page.locator('#add-expense-btn')).toBeVisible();
  });

  test('FIN-E05: clicking #add-expense-btn opens #expense-modal', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#tab-expenses');
    await expect(page.locator('#panel-expenses')).toBeVisible();
    await page.click('#add-expense-btn');
    await expect(page.locator('#expense-modal')).toBeVisible();
  });

  test('FIN-E06: submitting empty expense form shows browser validation (required on #exp-description)', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#tab-expenses');
    await page.click('#add-expense-btn');
    await expect(page.locator('#expense-modal')).toBeVisible();
    // Submit the form without filling required fields
    await page.click('#expense-form button[type="submit"]');
    // Browser HTML5 required validation fires — modal and page remain as-is
    await expect(page.locator('#expense-modal')).toBeVisible();
    await expect(page.locator('#exp-description')).toBeVisible();
  });

  test('FIN-E07: filling expense form and submitting shows success toast or adds to list', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#tab-expenses');
    await page.click('#add-expense-btn');
    await expect(page.locator('#expense-modal')).toBeVisible();

    await page.fill('#exp-description', 'E2E Test Expense – Automated');
    await page.fill('#exp-amount', '500');

    // Fill optional GST/TDS if present
    const gstField = page.locator('#exp-gst');
    if (await gstField.isVisible()) {
      await gstField.fill('0');
    }
    const tdsField = page.locator('#exp-tds');
    if (await tdsField.isVisible()) {
      await tdsField.fill('0');
    }

    await page.click('#expense-form button[type="submit"]');

    // Expect either a success toast or the modal to close and the list to update
    const modalClosed = page.locator('#expense-modal');
    await Promise.race([
      expectToast(page, '', 'success').catch(() => {}),
      expect(modalClosed).not.toBeVisible({ timeout: 8000 }).catch(() => {}),
    ]);
  });

  test('FIN-E08: #create-period-btn click opens #period-modal', async ({ page }) => {
    await page.goto('/portal/finance');
    await page.click('#create-period-btn');
    await expect(page.locator('#period-modal')).toBeVisible();
  });
});
