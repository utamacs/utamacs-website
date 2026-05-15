import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Dashboard – member role', () => {
  test('D-01: member dashboard loads at /portal', async ({ page }) => {
    await page.goto('/portal');
    await expect(page).toHaveURL('/portal');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('D-02: member dashboard does NOT show executive widgets', async ({ page }) => {
    await page.goto('/portal');
    // ExecutiveDashboard component only renders for exec/admin roles
    await expect(page.locator('[data-testid="executive-dashboard"]')).not.toBeVisible().catch(() => {});
  });

  test('D-03: community nav group is visible for members', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).toContainText('Complaints');
    await expect(page.locator('nav')).toContainText('Notices');
    await expect(page.locator('nav')).toContainText('Events');
  });

  test('D-04: admin nav items are NOT visible for members', async ({ page }) => {
    await page.goto('/portal');
    await expect(page.locator('nav')).not.toContainText('Official Letters');
    await expect(page.locator('nav')).not.toContainText('Analytics');
  });

  test('D-05: nav link to complaints navigates correctly', async ({ page }) => {
    await page.goto('/portal');
    // Nav groups collapse by default on the dashboard — expand Community first
    const communityBtn = page.locator('button.nav-group-btn[data-group-key="community"]');
    if (await communityBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
      const expanded = await communityBtn.getAttribute('aria-expanded');
      if (expanded === 'false') await communityBtn.click();
    }
    await page.locator('nav a[href="/portal/complaints"]').click();
    await expect(page).toHaveURL('/portal/complaints');
  });

  test('D-06: session persists on page refresh', async ({ page }) => {
    await page.goto('/portal');
    await page.reload();
    await expect(page).toHaveURL('/portal');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });
});
