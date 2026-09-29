import { expect, test } from '@playwright/test'

test('renders reviews returned as a flat array', async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('accessToken', 'test-token')
    localStorage.setItem('user', JSON.stringify({
      _id: '507f1f77bcf86cd799439012',
      name: 'Test Admin',
      role: 'admin',
    }))
    localStorage.setItem('loginAt', String(Date.now()))
  })

  await page.route('**/api/v1/auth/me', (route) => route.fulfill({
    json: {
      success: true,
      data: {
        _id: '507f1f77bcf86cd799439012',
        name: 'Test Admin',
        role: 'admin',
      },
    },
  }))

  await page.route('**/api/v1/admin/reviews', (route) => route.fulfill({
    json: {
      success: true,
      data: [{
        _id: 'review-1',
        name: 'Flat Array Farmer',
        role: 'Wholesaler, Sample City',
        review: 'Quality seeds, on-time delivery.',
        rating: 5,
        isActive: true,
        createdAt: '2026-09-10T09:00:00.000Z',
      }],
      pagination: { page: 1, limit: 20, total: 1, totalPages: 1 },
    },
  }))

  await page.goto('/reviews', { waitUntil: 'domcontentloaded' })

  await expect(page.getByText('Flat Array Farmer', { exact: true })).toBeVisible()
  await expect(page.getByText('No reviews found. Click "Add Review" to create one.')).toBeHidden()
})

test('sends negotiation search text to the backend', async ({ page }) => {
  let searchParam = ''
  await page.addInitScript(() => {
    localStorage.setItem('accessToken', 'test-token')
    localStorage.setItem('user', JSON.stringify({
      _id: '507f1f77bcf86cd799439012',
      name: 'Test Admin',
      role: 'admin',
    }))
    localStorage.setItem('loginAt', String(Date.now()))
  })

  await page.route('**/api/v1/auth/me', (route) => route.fulfill({
    json: {
      success: true,
      data: {
        _id: '507f1f77bcf86cd799439012',
        name: 'Test Admin',
        role: 'admin',
      },
    },
  }))

  await page.route('**/api/v1/admin/negotiations**', async (route) => {
    searchParam = new URL(route.request().url()).searchParams.get('search') || ''
    await route.fulfill({
      json: {
        success: true,
        data: [],
        pagination: { page: 1, total: 0, totalPages: 1 },
      },
    })
  })

  await page.goto('/negotiations', { waitUntil: 'domcontentloaded' })
  await page.getByPlaceholder('Search negotiations...').fill('NEG-42')
  await page.getByRole('button', { name: 'Search' }).click()

  await expect.poll(() => searchParam).toBe('NEG-42')
})
