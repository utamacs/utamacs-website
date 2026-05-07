import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Notices – executive', () => {
  test('N-04: exec can access /portal/notices/new', async ({ page }) => {
    await page.goto('/portal/notices/new');
    await expect(page).toHaveURL('/portal/notices/new');
    await expect(page.locator('#title')).toBeVisible();
  });

  test('N-05: new notice form has category and audience dropdowns', async ({ page }) => {
    await page.goto('/portal/notices/new');
    await expect(page.locator('#category')).toBeVisible();
    await expect(page.locator('#target_audience')).toBeVisible();
  });

  test('N-06: category dropdown has expected options', async ({ page }) => {
    await page.goto('/portal/notices/new');
    const options = await page.locator('#category option').allTextContents();
    expect(options).toContain('General');
    expect(options).toContain('Urgent');
    expect(options).toContain('Financial');
    expect(options).toContain('Governance');
  });

  test('N-07: submit notice without title shows validation', async ({ page }) => {
    await page.goto('/portal/notices/new');
    await page.selectOption('#category', 'General');
    // Scope to notice form — avoids nav sign-out button
    await page.click('#notice-form button[type="submit"]');
    await expect(page).toHaveURL('/portal/notices/new');
  });

  test('N-08: exec can submit a valid notice', async ({ page }) => {
    await page.goto('/portal/notices/new');
    await page.fill('#title', 'Test Notice – Automated E2E');
    await page.selectOption('#category', 'General');

    const bodyField = page.locator('#body, #content, textarea').first();
    if (await bodyField.isVisible()) {
      await bodyField.fill('This is an automated test notice. Please ignore.');
    }

    await page.click('#notice-form button[type="submit"]');
    await expect(page).not.toHaveURL('/portal/notices/new', { timeout: 15000 });
  });
});
