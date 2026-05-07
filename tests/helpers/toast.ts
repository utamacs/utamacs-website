import type { Page } from '@playwright/test';
import { expect } from '@playwright/test';

export async function expectToast(page: Page, text: string, type: 'success' | 'error' = 'success') {
  const colorClass = type === 'success' ? 'bg-secondary-500' : 'bg-red-500';
  const toast = page.locator(`div.fixed.bottom-6.right-6.${colorClass}`);
  await expect(toast).toBeVisible({ timeout: 5000 });
  await expect(toast).toContainText(text);
}
