import type { Page } from '@playwright/test';

export async function loginAs(page: Page, email: string, password: string) {
  await page.goto('/portal/login');
  await page.fill('#email', email);
  await page.fill('#password', password);
  await page.click('button[type="submit"]');
  await page.waitForURL('/portal', { timeout: 15000 });
}

export async function logout(page: Page) {
  await page.goto('/api/v1/auth/signout', { method: 'POST' } as any);
}
