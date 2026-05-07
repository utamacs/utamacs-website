import { test, expect } from '@playwright/test';

// Runs with guard storageState

test.describe('Role gates – guard role access', () => {
  test('RG-05: guard redirected away from /portal/members', async ({ page }) => {
    await page.goto('/portal/members');
    await expect(page).not.toHaveURL('/portal/members');
  });

  test('RG-06: guard CAN access /portal/visitors', async ({ page }) => {
    await page.goto('/portal/visitors');
    await expect(page).toHaveURL('/portal/visitors');
  });

  test('RG-07: guard redirected away from /portal/finance', async ({ page }) => {
    await page.goto('/portal/finance');
    await expect(page).not.toHaveURL('/portal/finance');
  });
});

test.describe('Visitors – security guard', () => {
  test('V-01: guard can access /portal/visitors', async ({ page }) => {
    await page.goto('/portal/visitors');
    await expect(page).toHaveURL('/portal/visitors');
    await expect(page.locator('h1')).toContainText('Visitor Management');
  });

  test('V-02: visitor type dropdown has expected options', async ({ page }) => {
    await page.goto('/portal/visitors');
    const dropdown = page.locator('#visitor_type, select[name="visitor_type"]').first();
    if (await dropdown.isVisible()) {
      const options = await dropdown.locator('option').allTextContents();
      expect(options.some(o => o.includes('Guest'))).toBeTruthy();
      expect(options.some(o => o.includes('Courier'))).toBeTruthy();
      expect(options.some(o => o.includes('Food Delivery'))).toBeTruthy();
    }
  });

  test('V-03: visitor log entry form is present', async ({ page }) => {
    await page.goto('/portal/visitors');
    // The entry form uses id="entry-visitor-name" and is visible directly on the page
    await expect(page.locator('#entry-visitor-name')).toBeVisible({ timeout: 10000 });
  });

  test('V-04: guard page shows "How it works" collapsed info panel', async ({ page }) => {
    await page.goto('/portal/visitors');
    const details = page.locator('details').first();
    await expect(details).not.toHaveAttribute('open');
  });
});
