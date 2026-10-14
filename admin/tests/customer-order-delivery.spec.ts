import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

const pendingOrder = (extra: Json = {}) => ({
  _id: "order-c1",
  orderNumber: "ORD-2026-7001",
  orderType: "retail",
  acceptanceStatus: "pending",
  items: [{ productSnapshot: { name: "3 Hp 4 Stage V-6 50ft Orbit" }, quantity: 1, pricePerUnit: 24200 }],
  customerSnapshot: { name: "Asha Devi", email: "asha@example.invalid", phone: "9000000091" },
  subtotal: 24200,
  deliveryFee: 0,
  discount: 0,
  total: 24200,
  status: "pending_payment",
  createdAt: "2026-10-01T11:30:00.000Z",
  shippingAddress: { addressLine1: "Market Road", city: "Metro City", state: "DS", pincode: "000001" },
  statusHistory: [],
  payment: null,
  ...extra,
})

async function mockApi(page: Page, order: Json, base: "admin" | "staff") {
  const writes: { path: string; body: Json }[] = []
  await page.addInitScript((role) => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "u-1", name: "Admin", role }))
    localStorage.setItem("loginAt", String(Date.now()))
    if (role === "staff") localStorage.setItem("sessionExpiresAt", new Date(Date.now() + 60_000).toISOString())
  }, base === "admin" ? "admin" : "staff")
  await page.route("**/socket.io/**", (route) => route.abort())
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: base === "admin" ? "admin" : "staff" } } })
    if (request.method() === "PUT") {
      const body = (request.postDataJSON() || {}) as Json
      writes.push({ path: url.pathname, body })
      const delivery = Number(body.deliveryCharge || 0)
      return route.fulfill({ json: { success: true, data: { deliveryFee: delivery, total: 24200 + delivery } } })
    }
    if (url.pathname.endsWith(`/orders/${order._id}`)) return route.fulfill({ json: { data: order } })
    if (url.pathname.endsWith("/orders")) {
      return route.fulfill({ json: { data: [order], pagination: { page: 1, total: 1, totalPages: 1 }, approvalCounts: { pending: 1 } } })
    }
    return route.fulfill({ json: { data: [] } })
  })
  return writes
}

test("admin adds the delivery charge when accepting a customer order", async ({ page }) => {
  const writes = await mockApi(page, pendingOrder(), "admin")
  await page.goto("/orders")
  await page.getByRole("button", { name: "Accept", exact: true }).first().click()

  const dialog = page.getByTestId("customer-accept-dialog")
  await expect(dialog).toContainText("ORD-2026-7001")
  await dialog.getByLabel("Delivery charge (₹)").fill("150")
  const totals = dialog.getByTestId("order-total-line")
  await expect(totals).toContainText("Subtotal₹24,200")
  await expect(totals).toContainText("Delivery₹150")
  await expect(totals).toContainText("Total₹24,350")
  await page.screenshot({ path: "test-results/customer-order-accept.png" })

  await dialog.getByRole("button", { name: "Accept · ₹24,350" }).click()
  await expect.poll(() => writes.find((w) => w.path.endsWith("/admin/orders/order-c1/accept"))?.body).toEqual({ deliveryCharge: 150 })
})

test("a negative delivery charge can't be submitted, and an old ₹50 order starts at ₹50", async ({ page }) => {
  await mockApi(page, pendingOrder({ deliveryFee: 50, total: 24250 }), "admin")
  await page.goto("/orders")
  await page.getByRole("button", { name: "Accept", exact: true }).first().click()
  const dialog = page.getByTestId("customer-accept-dialog")
  await expect(dialog.getByLabel("Delivery charge (₹)")).toHaveValue("50")
  await expect(dialog.getByTestId("order-total-line")).toContainText("Total₹24,250")
  await dialog.getByLabel("Delivery charge (₹)").fill("-10")
  await expect(dialog).toContainText("Enter 0 or a positive amount.")
  await expect(dialog.getByRole("button", { name: /^Accept ·/ })).toBeDisabled()
})

test("member panel sends the delivery charge too", async ({ page }) => {
  const writes = await mockApi(page, pendingOrder(), "staff")
  await page.goto("/member/orders")
  await page.getByRole("button", { name: "Accept", exact: true }).first().click()
  const dialog = page.getByTestId("customer-accept-dialog")
  await dialog.getByLabel("Delivery charge (₹)").fill("80")
  await dialog.getByRole("button", { name: "Accept · ₹24,280" }).click()
  await expect.poll(() => writes.find((w) => w.path.endsWith("/staff/orders/order-c1/accept"))?.body).toEqual({ deliveryCharge: 80 })
})
