import { expect, test } from "@playwright/test"

// A long order: many items + status history, so the details dialog must scroll.
const order = {
  _id: "order-long-1",
  orderNumber: "ORD-2026-SCROLL",
  orderType: "retail",
  acceptanceStatus: null,
  items: Array.from({ length: 12 }, (_, i) => ({ productSnapshot: { name: `Test Pump ${i + 1}` }, quantity: 1, pricePerUnit: 1000 })),
  customerSnapshot: { name: "Scroll Customer", email: "scroll@example.invalid", phone: "9000000009" },
  total: 12000,
  status: "pending_payment",
  createdAt: "2026-09-28T11:30:00.000Z",
  shippingAddress: { addressLine1: "Market Road", city: "Bemetara", state: "CG", pincode: "491335" },
  statusHistory: Array.from({ length: 6 }, (_, i) => ({ status: "pending_payment", timestamp: "2026-09-28T11:30:00.000Z", note: `Update ${i + 1}` })),
  payment: null,
}

for (const viewport of [
  { name: "phone", width: 390, height: 700 },
  { name: "tablet", width: 820, height: 800 },
]) {
  test(`order details scroll to the bottom on a ${viewport.name}`, async ({ page }) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height })
    await page.addInitScript(() => {
      localStorage.setItem("accessToken", "test-token")
      localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
      localStorage.setItem("loginAt", String(Date.now()))
    })
    await page.route("**/api/v1/**", async (route) => {
      const url = new URL(route.request().url())
      if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
      if (url.pathname.endsWith(`/orders/${order._id}`)) return route.fulfill({ json: { data: order } })
      if (url.pathname.endsWith("/orders")) return route.fulfill({ json: { data: [order], pagination: { page: 1, total: 1, totalPages: 1 } } })
      return route.fulfill({ json: { data: [] } })
    })

    await page.goto("/orders")
    await page.getByRole("button", { name: "View", exact: false }).first().click()
    const dialog = page.getByRole("dialog")
    await expect(dialog.getByText("Order Details: ORD-2026-SCROLL")).toBeVisible()

    // The dialog fits the screen...
    const box = await dialog.boundingBox()
    expect(box!.y).toBeGreaterThanOrEqual(0)
    expect(box!.y + box!.height).toBeLessThanOrEqual(viewport.height + 1)

    // ...and its last section can be scrolled into view.
    const lastNote = dialog.getByText("Update 6")
    await lastNote.scrollIntoViewIfNeeded()
    await expect(lastNote).toBeInViewport()
    await page.screenshot({ path: `test-results/order-details-${viewport.name}.png` })
  })
}
