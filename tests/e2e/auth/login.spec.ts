import { test, expect } from '@playwright/test';
import { TEST_USERS } from '../../fixtures/env';

// These tests run WITHOUT stored auth state (public project in playwright.config.ts)

test.describe('Login page', () => {
  test('A-01: login page loads with email and password fields', async ({ page }) => {
    await page.goto('/portal/login');
    await expect(page.locator('#email')).toBeVisible();
    await expect(page.locator('#password')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toContainText('Sign In');
  });

  test('A-02: valid credentials redirect to /portal', async ({ page }) => {
    await page.goto('/portal/login');
    await page.fill('#email', TEST_USERS.member.email);
    await page.fill('#password', TEST_USERS.member.password);
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL('/portal', { timeout: 20000 });
  });

  test('A-03: wrong password does not log in', async ({ page }) => {
    await page.goto('/portal/login');
    await page.fill('#email', TEST_USERS.member.email);
    await page.fill('#password', 'WrongPassword999!');
    await page.click('button[type="submit"]');

    // Must NOT land on /portal dashboard — either stays on login or shows error
    await expect(page).not.toHaveURL('https://portal.utamacs.org/portal', { timeout: 10000 });
  });

  test('A-04: empty form shows required error', async ({ page }) => {
    await page.goto('/portal/login');
    await page.click('button[type="submit"]');
    // HTML5 required validation prevents submit — we stay on the page
    await expect(page).toHaveURL('/portal/login');
  });

  test('A-05: forgot password link is visible and navigates', async ({ page }) => {
    await page.goto('/portal/login');
    await page.click('a[href="/portal/forgot-password"]');
    await expect(page).toHaveURL('/portal/forgot-password');
  });

  test('A-06: unauthenticated access to /portal redirects to login', async ({ page }) => {
    await page.goto('/portal');
    await expect(page).toHaveURL(/\/portal\/login/);
  });

  test('A-07: unauthenticated access to /portal/members redirects to login', async ({ page }) => {
    await page.goto('/portal/members');
    await expect(page).toHaveURL(/\/portal\/login/);
  });

  test('A-08: unauthenticated access to /portal/complaints redirects to login', async ({ page }) => {
    await page.goto('/portal/complaints');
    await expect(page).toHaveURL(/\/portal\/login/);
  });
});
