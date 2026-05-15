import { test, expect } from '@playwright/test';
import path from 'path';

// Runs with member storageState

test.describe('Complaints – member', () => {
  test('C-01: complaints list page loads', async ({ page }) => {
    await page.goto('/portal/complaints');
    await expect(page).toHaveURL('/portal/complaints');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('C-02: new complaint page loads with required fields', async ({ page }) => {
    await page.goto('/portal/complaints/new');
    await expect(page.locator('#title')).toBeVisible();
    await expect(page.locator('#category')).toBeVisible();
    await expect(page.locator('#priority')).toBeVisible();
  });

  test('C-03: submit complaint without title shows browser validation', async ({ page }) => {
    await page.goto('/portal/complaints/new');
    await page.selectOption('#category', 'Plumbing');
    // Scope to the complaint form — avoids matching the sign-out button in the nav header
    await page.click('#complaint-form button[type="submit"]');
    // HTML5 required validation fires — stays on the page
    await expect(page).toHaveURL('/portal/complaints/new');
  });

  test('C-04: submit valid complaint redirects to detail page', async ({ page }) => {
    await page.goto('/portal/complaints/new');
    await page.fill('#title', 'Test: Lift not working in Block B');
    await page.selectOption('#category', 'Lift');
    await page.selectOption('#priority', 'High');

    const descField = page.locator('#description');
    if (await descField.isVisible()) {
      await descField.fill('Automated test complaint — please ignore.');
    }

    // Select first available unit (required field)
    const firstUnit = await page.locator('#unit_id option:not([value=""])').first().getAttribute('value');
    if (firstUnit) await page.selectOption('#unit_id', firstUnit);

    await page.click('#complaint-form button[type="submit"]');
    await expect(page).toHaveURL(/\/portal\/complaints\/[0-9a-f-]+\?created=1/, { timeout: 15000 });
  });

  test('C-05: complaint detail shows success banner after creation', async ({ page }) => {
    await page.goto('/portal/complaints/new');
    await page.fill('#title', 'Test: Waterlogging in basement');
    await page.selectOption('#category', 'Plumbing');

    // Select first available unit (required field)
    const firstUnit = await page.locator('#unit_id option:not([value=""])').first().getAttribute('value');
    if (firstUnit) await page.selectOption('#unit_id', firstUnit);

    await page.click('#complaint-form button[type="submit"]');
    await page.waitForURL(/\?created=1/, { timeout: 15000 });
    await expect(page.locator('#success-banner')).toBeVisible();
  });

  test('C-06: category dropdown has expected options', async ({ page }) => {
    await page.goto('/portal/complaints/new');
    const options = await page.locator('#category option').allTextContents();
    expect(options).toContain('Plumbing');
    expect(options).toContain('Electrical');
    expect(options).toContain('Lift');
    expect(options).toContain('Security');
  });

  test('C-07: priority defaults to Medium', async ({ page }) => {
    await page.goto('/portal/complaints/new');
    const selected = await page.locator('#priority').inputValue();
    expect(selected).toBe('Medium');
  });
});
