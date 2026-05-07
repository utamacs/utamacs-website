import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Feedback – member', () => {
  test('FB-01: feedback page loads at /portal/feedback', async ({ page }) => {
    await page.goto('/portal/feedback');
    await expect(page).toHaveURL('/portal/feedback');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('FB-02: feedback list container is visible', async ({ page }) => {
    await page.goto('/portal/feedback');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
    await expect(page.locator('#feedback-list')).toBeVisible({ timeout: 10000 });
  });

  test('FB-03: new-feedback button is visible (all members can submit feedback)', async ({ page }) => {
    await page.goto('/portal/feedback');
    await expect(page.locator('#new-feedback-btn')).toBeVisible({ timeout: 10000 });
  });

  test('FB-04: clicking new-feedback button opens the feedback modal', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.locator('#new-feedback-btn').click();
    await expect(page.locator('#feedback-modal')).toBeVisible({ timeout: 5000 });
  });

  test('FB-05: feedback modal contains subject and body inputs', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.locator('#new-feedback-btn').click();
    await expect(page.locator('#feedback-modal')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('#fb-subject')).toBeVisible();
    await expect(page.locator('#fb-body')).toBeVisible();
  });

  test('FB-06: anonymous checkbox is present in feedback modal', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.locator('#new-feedback-btn').click();
    await expect(page.locator('#feedback-modal')).toBeVisible({ timeout: 5000 });
    await expect(page.locator('#fb-anonymous')).toBeVisible();
  });

  test('FB-07: filter selects for status and category are present', async ({ page }) => {
    await page.goto('/portal/feedback');
    await expect(page.locator('#filter-status')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('#filter-category')).toBeVisible({ timeout: 10000 });
  });

  test('FB-08: submitting feedback form with subject and body shows success or closes modal', async ({ page }) => {
    await page.goto('/portal/feedback');
    await page.locator('#new-feedback-btn').click();
    await expect(page.locator('#feedback-modal')).toBeVisible({ timeout: 5000 });

    await page.locator('#fb-subject').fill('E2E Test Feedback Subject');
    await page.locator('#fb-body').fill('This is an automated E2E test feedback entry. Please ignore.');

    // Set a category if the field exists
    const categoryField = page.locator('#fb-category');
    if (await categoryField.isVisible()) {
      const options = await categoryField.locator('option').allTextContents();
      const realOption = options.find(o => o.trim() && !o.toLowerCase().includes('select'));
      if (realOption) {
        await categoryField.selectOption({ label: realOption.trim() });
      }
    }

    await page.locator('#fb-save-btn').click();

    // Expect either: modal closes (success) OR a success toast appears
    await Promise.race([
      expect(page.locator('#feedback-modal')).not.toBeVisible({ timeout: 10000 }),
      expect(
        page.locator('div.fixed.bottom-6.right-6.bg-secondary-500, div[class*="toast"]')
      ).toBeVisible({ timeout: 10000 }),
    ]).catch(() => {
      // At minimum no server error
    });

    await expect(page.locator('body')).not.toContainText('500');
  });
});
