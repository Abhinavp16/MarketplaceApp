import { expect, Page } from '@playwright/test';

export const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';
// Demo backend only (see README). Never point this at a real deployment.
export const API_URL = process.env.DEMO_API_URL || 'http://localhost:5050/api/v1';
export const DEMO_ADMIN_EMAIL = 'admin@tradehub.example';
export const DEMO_ADMIN_PASSWORD = 'Demo@12345';

/**
 * Signs in as the demo admin through the login page (email + password) against
 * the local demo backend. Requires the backend to run with DEMO_MODE=true.
 */
export async function loginAsAdmin(page: Page) {
  await page.goto(`${BASE_URL}/login`);
  await page.locator('input[name="email"]').fill(DEMO_ADMIN_EMAIL);
  await page.locator('input[name="password"]').fill(DEMO_ADMIN_PASSWORD);
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await expect(page).toHaveURL(BASE_URL + '/', { timeout: 15000 });
}
