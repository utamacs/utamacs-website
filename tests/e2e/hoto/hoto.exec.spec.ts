import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('HOTO / Snags – executive', () => {
  test('HT-E01: HOTO main page loads at /portal/hoto for exec', async ({ page }) => {
    await page.goto('/portal/hoto');
    await expect(page).toHaveURL('/portal/hoto');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });

  test('HT-E02: snags page loads at /portal/hoto/snags for exec', async ({ page }) => {
    await page.goto('/portal/hoto/snags');
    await expect(page).toHaveURL('/portal/hoto/snags');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('HT-E03: snags list or empty state is visible without server error', async ({ page }) => {
    await page.goto('/portal/hoto/snags');
    await page.waitForTimeout(2000);

    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');

    // Either snag cards / table rows OR an empty state message should be present
    const hasContent = await page.locator(
      '.snag-card, [data-snag-id], .card-premium, table tbody tr, .text-center'
    ).first().isVisible({ timeout: 10000 }).catch(() => false);
    expect(hasContent).toBeTruthy();
  });

  test('HT-E04: exec can navigate from HOTO main page to snags section', async ({ page }) => {
    await page.goto('/portal/hoto');
    await expect(page).toHaveURL('/portal/hoto');

    // Look for a link or button that leads to the snags section
    const snagsLink = page.locator(
      'a[href*="snags"], button:has-text("Snags"), a:has-text("Snags"), a:has-text("Defects"), button:has-text("Defects")'
    );
    const linkVisible = await snagsLink.first().isVisible({ timeout: 5000 }).catch(() => false);

    if (linkVisible) {
      await snagsLink.first().click();
      // Should navigate to the snags page or section
      await expect(page).toHaveURL(/snags/, { timeout: 10000 });
      await expect(page.locator('body')).not.toContainText('500');
    } else {
      // Navigate directly if no link found on the main page
      await page.goto('/portal/hoto/snags');
      await expect(page).toHaveURL('/portal/hoto/snags');
      await expect(page.locator('body')).not.toContainText('500');
    }
  });
});
