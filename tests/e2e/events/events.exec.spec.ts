import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Events – executive', () => {
  test('EV-E01: events list page loads for exec', async ({ page }) => {
    await page.goto('/portal/events');
    await expect(page).toHaveURL('/portal/events');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('EV-E02: exec sees "Create Event" or "New Event" button on list page', async ({ page }) => {
    await page.goto('/portal/events');
    const createBtn = page.locator(
      'a[href="/portal/events/new"], button:has-text("Create Event"), button:has-text("New Event"), a:has-text("Create Event"), a:has-text("New Event")'
    ).first();
    await expect(createBtn).toBeVisible();
  });

  test('EV-E03: /portal/events/new loads with required form fields', async ({ page }) => {
    await page.goto('/portal/events/new');
    await expect(page).toHaveURL('/portal/events/new');
    await expect(page.locator('#title')).toBeVisible();
    await expect(page.locator('#event_date')).toBeVisible();
    await expect(page.locator('#venue')).toBeVisible();
  });

  test('EV-E04: submitting event form without title shows browser validation (stays on page)', async ({ page }) => {
    await page.goto('/portal/events/new');
    // Fill in date and venue but leave title empty — HTML5 required validation should fire
    await page.fill('#event_date', '2026-06-01');
    await page.fill('#venue', 'Clubhouse');
    // Click the submit button inside the form
    const submitBtn = page.locator('form button[type="submit"]').first();
    await submitBtn.click();
    // Browser validation prevents submission — page stays at new event URL
    await expect(page).toHaveURL('/portal/events/new');
  });

  test('EV-E05: event detail page shows attendees section for exec', async ({ page }) => {
    await page.goto('/portal/events');
    const firstCardLink = page.locator('#events-list a[href^="/portal/events/"]').first();
    const count = await firstCardLink.count();
    if (count > 0) {
      const href = await firstCardLink.getAttribute('href');
      await page.goto(href!);
      await expect(page.locator('h1')).toBeVisible();
      // Exec should see attendees table or section
      const attendeesSection = page.locator(
        '#attendees, table, [data-testid="attendees"], h2:has-text("Attendees"), h3:has-text("Attendees")'
      ).first();
      await expect(attendeesSection).toBeVisible();
    } else {
      test.skip();
    }
  });

  test('EV-E06: exec can access /portal/events/new without redirect', async ({ page }) => {
    await page.goto('/portal/events/new');
    await expect(page).toHaveURL('/portal/events/new');
    // Form should be rendered, not a login or forbidden page
    await expect(page.locator('body')).not.toContainText('Sign In');
    await expect(page.locator('body')).not.toContainText('Forbidden');
    await expect(page.locator('body')).not.toContainText('403');
  });
});
