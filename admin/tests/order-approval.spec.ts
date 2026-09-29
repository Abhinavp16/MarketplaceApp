import { expect, Page, test } from "@playwright/test"

type MockOrder = {
  _id: string
  orderNumber: string
  orderType: string
  acceptanceStatus: "pending" | "accepted" | "rejected"
  acceptedAt?: string
  acceptedBy?: { name: string }
  items: { productSnapshot: { name: string }; quantity: number; pricePerUnit: number }[]
  customerSnapshot: { name: string; email: string; phone: string }
  total: number
  status: string
  createdAt: string
  shippingAddress: { addressLine1: string; city: string; state: string; pincode: string }
  payment: null
}

const order: MockOrder = {
  _id: "order-pending-1",
  orderNumber: "ORD-APPROVAL-1",
  orderType: "retail",
  acceptanceStatus: "pending",
  items: [{ productSnapshot: { name: "Test Seeds" }, quantity: 2, pricePerUnit: 100 }],
  customerSnapshot: { name: "Retail Customer", email: "retail@example.com", phone: "9999999999" },
  total: 200,
  status: "pending_payment",
  createdAt: "2026-09-20T09:00:00.000Z",
  shippingAddress: { addressLine1: "Market Road", city: "Pune", state: "Maharashtra", pincode: "411001" },
  payment: null,
}

async function mockOrders(page: Page, role: "admin" | "staff") {
  let currentOrder = { ...order }
  await page.addInitScript(({ role }) => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "user-1", name: "Test User", role }))
    localStorage.setItem("loginAt", String(Date.now()))
    if (role === "staff") localStorage.setItem("sessionExpiresAt", new Date(Date.now() + 60_000).toISOString())
  }, { role })

  await page.route("**/api/v1/**", async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role } } })
    if (url.pathname.endsWith(`/orders/${order._id}/accept`) && route.request().method() === "PUT") {
      currentOrder = { ...currentOrder, acceptanceStatus: "accepted", acceptedAt: "2026-09-20T10:00:00.000Z", acceptedBy: { name: "Test User" } }
      return route.fulfill({ json: { data: currentOrder } })
    }
    if (url.pathname.endsWith(`/orders/${order._id}`)) return route.fulfill({ json: { data: currentOrder } })
    if (url.pathname.endsWith("/orders")) return route.fulfill({ json: { data: [currentOrder], pagination: { page: 1, total: 1, totalPages: 1 } } })
    return route.fulfill({ json: { data: [] } })
  })
}

for (const surface of [
  { role: "admin" as const, path: "/orders" },
  { role: "staff" as const, path: "/member/orders" },
]) {
  test(`${surface.role} can approve a pending retail order before payment completion`, async ({ page }) => {
    await mockOrders(page, surface.role)
    await page.goto(surface.path)

    await expect(page.getByText("Awaiting Approval", { exact: false }).first()).toBeVisible()
    await page.getByRole("button", { name: "View", exact: false }).first().click()
    await expect(page.getByRole("button", { name: "Mark Payment Completed" })).toHaveCount(0)
    await page.getByRole("button", { name: "Accept Order" }).click()

    await expect(page.getByText("Accepted by Test User", { exact: false })).toBeVisible()
    await expect(page.getByRole("button", { name: "Mark Payment Completed" })).toBeVisible()
  })
}

test("admin rejection requires a reason and sends the reason payload", async ({ page }) => {
  await mockOrders(page, "admin")
  await page.goto("/orders")
  await page.getByRole("button", { name: "View", exact: false }).first().click()
  await page.getByRole("button", { name: "Reject Order" }).click()

  const submit = page.getByRole("button", { name: "Reject Order" }).last()
  await expect(submit).toBeDisabled()
  await page.getByRole("textbox", { name: "Rejection reason" }).fill("Inventory unavailable")
  await expect(submit).toBeEnabled()

  const requestPromise = page.waitForRequest((request) => request.url().endsWith(`/orders/${order._id}/reject`))
  await submit.click()
  const request = await requestPromise
  expect(request.postDataJSON()).toEqual({ reason: "Inventory unavailable" })
})
