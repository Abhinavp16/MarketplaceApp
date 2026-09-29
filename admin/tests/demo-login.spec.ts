import { test, expect } from '@playwright/test';
import { BASE_URL, loginAsAdmin } from './helpers/auth';

test.describe('Demo login', () => {
  test('shows the password form, demo hint and staff login link', async ({ page }) => {
    await page.goto(`${BASE_URL}/login`);
    await expect(page.getByText('TradeHub Demo').first()).toBeVisible();
    await expect(page.getByText('Demo: admin@tradehub.example / Demo@12345')).toBeVisible();
    await page.getByRole('button', { name: 'Staff login' }).click();
    await expect(page.getByPlaceholder('Username')).toBeVisible();
  });

  // Requires the local demo backend (DEMO_MODE=true) on the URL in tests/helpers/auth.ts.
  test('admin can sign in and sees the demo banner', async ({ page }) => {
    await loginAsAdmin(page);
    await expect(page.getByText(/Demonstration Environment/)).toBeVisible();
  });
});
