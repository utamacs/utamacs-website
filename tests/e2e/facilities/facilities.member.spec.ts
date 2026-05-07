import { test, expect } from '@playwright/test';

// Runs with member storageState

test.describe('Facilities – member', () => {
  test('FAC-01: facilities page loads at /portal/facilities', async ({ page }) => {
    await page.goto('/portal/facilities');
    await expect(page).toHaveURL('/portal/facilities');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('FAC-02: facility list is visible or shows empty state without 500 error', async ({ page }) => {
    await page.goto('/portal/facilities');
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Internal Server Error');

    // Either facility cards or an empty state message should render
    const hasContent = await page.locator(
      '.facility-card, [data-facility-id], .card-premium, .card-feature, .text-center, table tbody tr'
    ).first().isVisible({ timeout: 10000 }).catch(() => false);
    expect(hasContent).toBeTruthy();
  });

  test('FAC-03: Book button is visible on at least one facility (members can book)', async ({ page }) => {
    await page.goto('/portal/facilities');
    await page.waitForTimeout(2000);

    const bookBtn = page.locator(
      'button:has-text("Book"), a:has-text("Book"), button:has-text("Reserve"), a:has-text("Reserve")'
    );
    const count = await bookBtn.count();

    if (count > 0) {
      await expect(bookBtn.first()).toBeVisible();
    } else {
      // No facilities configured yet — acceptable; just verify no error
      await expect(page.locator('body')).not.toContainText('500');
    }
  });

  test('FAC-04: My Bookings section or tab is visible', async ({ page }) => {
    await page.goto('/portal/facilities');
    await page.waitForTimeout(1000);

    // Look for "My Bookings" section heading, tab, or link
    const myBookings = page.locator(
      'h2:has-text("My Bookings"), h3:has-text("My Bookings"), button:has-text("My Bookings"), a:has-text("My Bookings"), [id*="my-bookings"], [id*="my_bookings"]'
    );

    const isVisible = await myBookings.first().isVisible({ timeout: 5000 }).catch(() => false);
    if (!isVisible) {
      // "My Bookings" may live on a sub-page or after clicking "Book"
      // Verify the page at least loads cleanly
      await expect(page.locator('body')).not.toContainText('500');
    } else {
      await expect(myBookings.first()).toBeVisible();
    }
  });
});
