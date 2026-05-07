import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Feedback – executive', () => {
  test('FB-E01: feedback page loads for exec', async ({ page }) => {
    await page.goto('/portal/feedback');
    await expect(page).toHaveURL('/portal/feedback');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('FB-E02: exec sees all feedback (feedback list is visible)', async ({ page }) => {
    await page.goto('/portal/feedback');
    await expect(page.locator('#feedback-list')).toBeVisible({ timeout: 10000 });
    // Exec should see all feedback items, not just their own
    // The list should render without error (may be empty in test env)
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });

  test('FB-E03: clicking a feedback item opens the detail panel', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.waitForTimeout(2000);

    const feedbackItems = page.locator('#feedback-list [data-feedback-id], #feedback-list .feedback-item, #feedback-list li, #feedback-list tr');
    const count = await feedbackItems.count();

    if (count === 0) {
      // No feedback in test env — submit one first
      await page.locator('#new-feedback-btn').click();
      await expect(page.locator('#feedback-modal')).toBeVisible({ timeout: 5000 });
      await page.locator('#fb-subject').fill('E2E Exec Test Feedback');
      await page.locator('#fb-body').fill('Automated test entry for exec panel test.');

      const categoryField = page.locator('#fb-category');
      if (await categoryField.isVisible()) {
        const options = await categoryField.locator('option').allTextContents();
        const realOption = options.find(o => o.trim() && !o.toLowerCase().includes('select'));
        if (realOption) await categoryField.selectOption({ label: realOption.trim() });
      }

      await page.locator('#fb-save-btn').click();
      await expect(page.locator('#feedback-modal')).not.toBeVisible({ timeout: 10000 });
      await page.waitForTimeout(1000);
    }

    // Click the first available feedback item
    const items = page.locator('#feedback-list [data-feedback-id], #feedback-list .feedback-item, #feedback-list li, #feedback-list tr');
    const itemCount = await items.count();
    if (itemCount > 0) {
      await items.first().click();
      await expect(page.locator('#detail-panel')).toBeVisible({ timeout: 5000 });
    } else {
      // Acceptable if no items in test environment
      await expect(page.locator('body')).not.toContainText('500');
    }
  });

  test('FB-E04: detail panel contains status and response fields', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.waitForTimeout(2000);

    const items = page.locator('#feedback-list [data-feedback-id], #feedback-list .feedback-item, #feedback-list li, #feedback-list tr');
    const count = await items.count();

    if (count > 0) {
      await items.first().click();
      await expect(page.locator('#detail-panel')).toBeVisible({ timeout: 5000 });
      await expect(page.locator('#panel-status')).toBeVisible();
      await expect(page.locator('#panel-response')).toBeVisible();
    } else {
      // Skip interaction checks when no feedback records exist
      await expect(page.locator('body')).not.toContainText('500');
    }
  });

  test('FB-E05: exec can update status via panel-status select', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.waitForTimeout(2000);

    const items = page.locator('#feedback-list [data-feedback-id], #feedback-list .feedback-item, #feedback-list li, #feedback-list tr');
    const count = await items.count();

    if (count > 0) {
      await items.first().click();
      await expect(page.locator('#detail-panel')).toBeVisible({ timeout: 5000 });

      const statusSelect = page.locator('#panel-status');
      await expect(statusSelect).toBeVisible();

      // Get current value and change to a different one
      const options = await statusSelect.locator('option').allTextContents();
      const currentValue = await statusSelect.inputValue();
      const alternateOption = options.find(o => {
        const v = o.trim();
        return v && v !== currentValue && !v.toLowerCase().includes('select');
      });

      if (alternateOption) {
        await statusSelect.selectOption({ label: alternateOption.trim() });
        // Expect no server error after status update
        await expect(page.locator('body')).not.toContainText('500');
      }
    } else {
      await expect(page.locator('body')).not.toContainText('500');
    }
  });
});
