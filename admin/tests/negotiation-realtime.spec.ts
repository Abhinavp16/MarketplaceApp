import { expect, test } from '@playwright/test'

const negotiationId = '507f1f77bcf86cd799439011'

test('refreshes canonical chat on socket messages and accepts an admin counter', async ({ page }) => {
  let detailRequests = 0
  let status = 'countered'
  let orderId: null | { _id: string; orderNumber: string; status: string; total: number } = null
  let acceptPayload: Record<string, unknown> | null = null
  let emitLiveMessage: (() => void) | null = null
  const history = [{
    action: 'countered',
    by: 'admin',
    actorRole: 'admin',
    pricePerUnit: 90,
    totalPrice: 450,
    message: 'Admin counter',
    timestamp: '2026-09-10T10:00:00.000Z',
  }]

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
    const url = new URL(route.request().url())
    if (route.request().method() === 'PUT' && url.pathname.endsWith(`/${negotiationId}/accept`)) {
      acceptPayload = route.request().postDataJSON()
      status = 'converted'
      orderId = { _id: 'order-1', orderNumber: 'ORD-TEST', status: 'pending_payment', total: 450 }
      history.push({
        action: 'accepted',
        by: 'admin',
        actorRole: 'admin',
        pricePerUnit: 90,
        totalPrice: 450,
        message: 'Accepted by admin',
        timestamp: '2026-09-10T10:02:00.000Z',
      })
      await route.fulfill({
        json: {
          success: true,
          message: 'Negotiation accepted — order confirmed',
          data: {
            status,
            finalPricePerUnit: 90,
            finalTotalPrice: 450,
            orderId: 'order-1',
            orderNumber: 'ORD-TEST',
            addressSource: 'provided',
          },
        },
      })
      return
    }
    if (url.pathname.endsWith(`/${negotiationId}`)) {
      detailRequests += 1
      await route.fulfill({
        json: {
          success: true,
          data: {
            _id: negotiationId,
            negotiationNumber: 'NEG-TEST',
            productSnapshot: { name: 'Test Product', sku: 'TEST-1', price: 100 },
            wholesalerId: { _id: 'buyer-1', name: 'Test Buyer', phone: '9135724680' },
            requestedQuantity: 5,
            requestedPricePerUnit: 80,
            currentPricePerUnit: 90,
            currentTotalPrice: 450,
            currentOfferBy: 'admin',
            status,
            orderId,
            message: '',
            history,
            createdAt: '2026-09-10T09:00:00.000Z',
          },
        },
      })
      return
    }

    await route.fulfill({
      json: {
        success: true,
        data: [{
          id: negotiationId,
          negotiationNumber: 'NEG-TEST',
          product: { name: 'Test Product', price: 100 },
          wholesaler: { name: 'Test Buyer' },
          requestedQuantity: 5,
          requestedPricePerUnit: 80,
          status,
        }],
        pagination: { page: 1, total: 1, totalPages: 1 },
      },
    })
  })

  await page.routeWebSocket('**/socket.io/**', (webSocket) => {
    webSocket.send('0{"sid":"engine-test","upgrades":[],"pingInterval":20000,"pingTimeout":20000,"maxPayload":1000000}')
    webSocket.onMessage((message) => {
      if (message === '40') {
        webSocket.send('40{"sid":"socket-test"}')
      }
      if (typeof message === 'string' && message.startsWith('42["join-negotiation"')) {
        emitLiveMessage = () => {
          history.push({
            action: 'message',
            by: 'wholesaler',
            actorRole: 'wholesaler',
            pricePerUnit: 0,
            totalPrice: 0,
            message: 'Live wholesaler reply',
            timestamp: '2026-09-10T10:01:00.000Z',
          })
          webSocket.send(`42["receive-message",${JSON.stringify({
            negotiationId,
            message: 'Live wholesaler reply',
            userId: 'buyer-1',
            userRole: 'wholesaler',
            timestamp: '2026-09-10T10:01:00.000Z',
          })}]`)
        }
      }
    })
  })

  await page.goto('/negotiations', { waitUntil: 'domcontentloaded' })
  const row = page.getByRole('row').filter({ hasText: 'NEG-TEST' })
  await row.getByRole('button').click()

  await expect(page.getByText('Admin counter', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Accept Deal' })).toBeVisible()
  await expect.poll(() => Boolean(emitLiveMessage)).toBe(true)
  const requestsBeforeMessage = detailRequests
  ;(emitLiveMessage as unknown as () => void)()
  await expect(page.getByText('Live wholesaler reply', { exact: true })).toBeVisible()
  await expect.poll(() => detailRequests).toBe(requestsBeforeMessage + 1)

  await page.getByRole('button', { name: 'Accept Deal' }).click()
  const dialog = page.getByRole('dialog').filter({ hasText: 'Accept Deal & Create Order' })
  const inputs = dialog.getByRole('textbox')
  await inputs.nth(2).fill('1 Test Road')
  await inputs.nth(4).fill('Sample City')
  await inputs.nth(5).fill('Chhattisgarh')
  await inputs.nth(6).fill('492001')
  await dialog.getByRole('button', { name: 'Accept · ₹450' }).click()

  await expect(page.getByRole('button', { name: /Order Created · ORD-TEST/ })).toBeVisible()
  expect(acceptPayload).toMatchObject({
    shippingAddress: {
      fullName: 'Test Buyer',
      phone: '9135724680',
      addressLine1: '1 Test Road',
      city: 'Sample City',
      state: 'Chhattisgarh',
      pincode: '492001',
    },
  })
})

test('offers recovery for a legacy accepted deal and rejects a missing order response', async ({ page }) => {
  let acceptPayload: Record<string, unknown> | null = null

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
    json: { success: true, data: { _id: '507f1f77bcf86cd799439012', name: 'Test Admin', role: 'admin' } },
  }))

  await page.route('**/api/v1/admin/negotiations**', async (route) => {
    const url = new URL(route.request().url())
    if (route.request().method() === 'PUT' && url.pathname.endsWith(`/${negotiationId}/accept`)) {
      acceptPayload = route.request().postDataJSON()
      await route.fulfill({ json: { success: true, data: { status: 'accepted' } } })
      return
    }
    if (url.pathname.endsWith(`/${negotiationId}`)) {
      await route.fulfill({
        json: {
          success: true,
          data: {
            _id: negotiationId,
            negotiationNumber: 'NEG-LEGACY',
            productSnapshot: { name: 'Legacy Product', sku: 'LEGACY-1', price: 100 },
            wholesalerId: { _id: 'buyer-1', name: 'Legacy Buyer', phone: '9135724680' },
            requestedQuantity: 5,
            requestedPricePerUnit: 80,
            currentPricePerUnit: 90,
            currentTotalPrice: 450,
            currentOfferBy: 'admin',
            status: 'accepted',
            orderId: null,
            message: '',
            history: [],
            createdAt: '2026-09-10T09:00:00.000Z',
          },
        },
      })
      return
    }
    await route.fulfill({
      json: {
        success: true,
        data: [{
          id: negotiationId,
          negotiationNumber: 'NEG-LEGACY',
          product: { name: 'Legacy Product', price: 100 },
          wholesaler: { name: 'Legacy Buyer' },
          requestedQuantity: 5,
          requestedPricePerUnit: 80,
          status: 'accepted',
        }],
        pagination: { page: 1, total: 1, totalPages: 1 },
      },
    })
  })

  await page.goto('/negotiations', { waitUntil: 'domcontentloaded' })
  await expect(page.getByText('Accepted · Order Pending', { exact: true })).toBeVisible()
  await page.getByRole('row').filter({ hasText: 'NEG-LEGACY' }).getByRole('button').click()
  await page.getByRole('button', { name: 'Create Missing Order' }).click()

  const dialog = page.getByRole('dialog').filter({ hasText: 'Create Missing Order' })
  await expect(dialog.getByRole('button', { name: 'Create Order' })).toBeDisabled()
  const inputs = dialog.getByRole('textbox')
  await inputs.nth(2).fill('1 Recovery Road')
  await inputs.nth(4).fill('Sample City')
  await inputs.nth(5).fill('Chhattisgarh')
  await inputs.nth(6).fill('492001')
  await dialog.getByRole('button', { name: 'Create Order' }).click()

  await expect(page.getByText(/no valid order reference was returned/i)).toBeVisible()
  await expect(dialog).toBeVisible()
  expect(acceptPayload).toMatchObject({
    shippingAddress: {
      fullName: 'Legacy Buyer',
      phone: '9135724680',
      addressLine1: '1 Recovery Road',
      city: 'Sample City',
      state: 'Chhattisgarh',
      pincode: '492001',
    },
  })
})
