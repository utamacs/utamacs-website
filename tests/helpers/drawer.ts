import type { Page } from '@playwright/test';
import { expect } from '@playwright/test';

export async function openDrawer(page: Page, triggerSelector: string) {
  await page.click(triggerSelector);
  await expect(page.locator('#detail-panel')).not.toHaveClass(/translate-x-full/);
}

export async function closeDrawer(page: Page) {
  await page.click('#close-panel');
  await expect(page.locator('#detail-panel')).toHaveClass(/translate-x-full/);
}
