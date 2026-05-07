import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Community Board – member', () => {
  test('COM-01: community page loads at /portal/community', async ({ page }) => {
    await page.goto('/portal/community');
    await expect(page).toHaveURL('/portal/community');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('COM-02: #posts-feed exists (may show empty state)', async ({ page }) => {
    await page.goto('/portal/community');
    await expect(page.locator('#posts-feed')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
  });

  test('COM-03: #category-filters is visible on community page', async ({ page }) => {
    await page.goto('/portal/community');
    await expect(page.locator('#category-filters')).toBeVisible();
  });

  test('COM-04: member cannot access /portal/admin/moderation (redirected or 403)', async ({ page }) => {
    await page.goto('/portal/admin/moderation');
    // Member should not remain on the moderation page
    const url = page.url();
    const body = page.locator('body');
    // Either redirected away from the URL or shown a 403/forbidden message
    const isForbiddenInPlace =
      url.includes('/portal/admin/moderation') &&
      (await body.textContent())?.match(/403|Forbidden|Access Denied/i);
    const isRedirectedAway = !url.includes('/portal/admin/moderation');
    expect(isForbiddenInPlace || isRedirectedAway).toBeTruthy();
  });

  test('COM-05: category filter buttons are clickable without navigation', async ({ page }) => {
    await page.goto('/portal/community');
    await expect(page.locator('#category-filters')).toBeVisible();
    // Click the first filter button; URL should stay on /portal/community
    const firstFilter = page.locator('#category-filters button').first();
    const count = await firstFilter.count();
    if (count > 0) {
      await firstFilter.click();
      await expect(page).toHaveURL('/portal/community');
    } else {
      // No filter buttons rendered (empty board) — acceptable
      await expect(page.locator('#category-filters')).toBeVisible();
    }
  });
});
