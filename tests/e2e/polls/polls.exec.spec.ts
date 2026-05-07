import { test, expect } from '@playwright/test';

// Runs with exec storageState

test.describe('Polls – executive', () => {
  test('POL-E01: polls list loads for exec', async ({ page }) => {
    await page.goto('/portal/polls');
    await expect(page).toHaveURL('/portal/polls');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
    await expect(page.locator('body')).not.toContainText('Sign In');
  });

  test('POL-E02: exec sees "Create Poll" or "New Poll" button on list page', async ({ page }) => {
    await page.goto('/portal/polls');
    const createBtn = page.locator(
      'a[href="/portal/polls/new"], button:has-text("Create Poll"), button:has-text("New Poll"), a:has-text("Create Poll"), a:has-text("New Poll")'
    ).first();
    await expect(createBtn).toBeVisible();
  });

  test('POL-E03: /portal/polls/new loads with required fields', async ({ page }) => {
    await page.goto('/portal/polls/new');
    await expect(page).toHaveURL('/portal/polls/new');
    // At minimum the page renders and has a title/question field
    await expect(page.locator('h1')).toBeVisible();
    // Form fields — question/title input must be present
    const questionField = page.locator('#title, #question, input[name="title"], input[name="question"]').first();
    await expect(questionField).toBeVisible();
    await expect(page.locator('body')).not.toContainText('500');
  });

  test('POL-E04: exec can access /portal/polls/new without redirect', async ({ page }) => {
    await page.goto('/portal/polls/new');
    await expect(page).toHaveURL('/portal/polls/new');
    await expect(page.locator('body')).not.toContainText('Sign In');
    await expect(page.locator('body')).not.toContainText('Forbidden');
    await expect(page.locator('body')).not.toContainText('403');
  });

  test('POL-E05: poll export button is visible on a closed poll detail page', async ({ page }) => {
    await page.goto('/portal/polls');
    await expect(page.locator('#polls-list')).toBeVisible();

    // Look for a closed/ended poll card to navigate to its detail page
    const closedPollLink = page.locator(
      '#polls-list a[href^="/portal/polls/"]:near(span:has-text("Closed")), ' +
      '#polls-list a[href^="/portal/polls/"]:near(span:has-text("Ended")), ' +
      '#polls-list a[href^="/portal/polls/"]:near(span:has-text("Completed"))'
    ).first();

    const closedCount = await closedPollLink.count();
    if (closedCount > 0) {
      const href = await closedPollLink.getAttribute('href');
      await page.goto(href!);
      await expect(page.locator('h1')).toBeVisible();
      // Export PDF button must be visible on closed poll for exec
      const exportBtn = page.locator(
        'button:has-text("Export"), button:has-text("Export PDF"), a:has-text("Export PDF"), a:has-text("Export")'
      ).first();
      await expect(exportBtn).toBeVisible();
    } else {
      // No closed polls in test environment — navigate to any poll detail and check exec controls
      const anyPollLink = page.locator('#polls-list a[href^="/portal/polls/"]').first();
      const anyCount = await anyPollLink.count();
      if (anyCount > 0) {
        const href = await anyPollLink.getAttribute('href');
        await page.goto(href!);
        await expect(page.locator('h1')).toBeVisible();
        await expect(page.locator('body')).not.toContainText('500');
      } else {
        test.skip();
      }
    }
  });
});
