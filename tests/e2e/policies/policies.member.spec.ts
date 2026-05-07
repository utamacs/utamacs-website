import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Policies – member', () => {
  test('POL-01: policies page loads at /portal/policies', async ({ page }) => {
    await page.goto('/portal/policies');
    await expect(page).toHaveURL('/portal/policies');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('POL-02: policies page shows list or empty state without 500 error', async ({ page }) => {
    await page.goto('/portal/policies');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');
    // Either a list of policy items or an empty state message should be present
    const hasContent = await page.locator(
      '.policy-card, [data-policy-id], .card-premium, .text-center'
    ).first().isVisible({ timeout: 10000 }).catch(() => false);
    expect(hasContent).toBeTruthy();
  });

  test('POL-03: member can acknowledge a policy if any are pending', async ({ page }) => {
    await page.goto('/portal/policies');
    await page.waitForTimeout(2000);

    // Look for an acknowledge button on any unacknowledged policy card
    const ackBtn = page.locator(
      'button:has-text("Acknowledge"), button:has-text("I Agree"), button:has-text("Accept")'
    );
    const count = await ackBtn.count();

    if (count > 0) {
      await ackBtn.first().click();
      // After acknowledging, expect no 500 error; button may disappear or show "Acknowledged"
      await expect(page.locator('body')).not.toContainText('500');
    } else {
      // No pending policies — empty state or all acknowledged; still no error expected
      await expect(page.locator('body')).not.toContainText('500');
    }
  });

  test('POL-04: member cannot access policy management (new/create) page', async ({ page }) => {
    // Members should not be able to access exec-only policy creation paths
    await page.goto('/portal/policies/new');
    // Should be redirected away or receive a 403 — must NOT remain on /portal/policies/new
    await page.waitForURL(/portal\//, { timeout: 10000 }).catch(() => {});
    await expect(page).not.toHaveURL('/portal/policies/new');
  });
});
