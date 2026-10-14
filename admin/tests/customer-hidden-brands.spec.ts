import { expect, test } from "@playwright/test"

const customers = [
  { _id: "cust-1", name: "Demo Buyer", email: "", phone: "8100000001", role: "buyer", createdAt: "2026-10-10T10:00:00.000Z", hiddenBrands: [] },
  { _id: "cust-2", name: "Demo Wholesale", email: "", phone: "8100000002", role: "wholesaler", createdAt: "2026-10-10T10:00:00.000Z", hiddenBrands: ["b2"], businessInfo: { businessName: "kgn pump", gstIn: "" } },
]
const brands = [
  { _id: "b1", name: "Acme Pumps" },
  { _id: "b2", name: "Zenith" },
  { _id: "b3", name: "Orbit", hideFromCustomers: true },
]

test("hide brands from one customer on their profile", async ({ page }) => {
  const saves: { path: string; body: { hiddenBrands: string[] } }[] = []
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (url.pathname.endsWith("/brand-access") && request.method() === "PUT") {
      const body = request.postDataJSON()
      saves.push({ path: url.pathname, body })
      return route.fulfill({ json: { success: true, message: `${body.hiddenBrands.length} brands hidden from this customer`, data: { hiddenBrands: body.hiddenBrands } } })
    }
    const detail = url.pathname.match(/\/admin\/customers\/(cust-\d)$/)
    if (detail) {
      const customer = customers.find((c) => c._id === detail[1])
      return route.fulfill({ json: { success: true, data: { ...customer, stats: { orders: { totalOrders: 0, totalSpent: 0 }, negotiations: {} }, recentOrders: [] } } })
    }
    if (url.pathname.endsWith("/admin/customers")) return route.fulfill({ json: { success: true, data: customers, pagination: { page: 1, total: 2, totalPages: 1 } } })
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { success: true, data: brands, pagination: { page: 1, total: 3, totalPages: 1 } } })
    return route.fulfill({ json: { success: true, data: [] } })
  })

  await page.goto("/customers")
  // The list shows who has hidden brands.
  await expect(page.getByText("1 brand hidden").first()).toBeVisible()

  // Open the retail customer's profile and hide two brands.
  await page.getByRole("row", { name: /Demo Buyer/ }).getByRole("button").first().click()
  const dialog = page.getByRole("dialog")
  await expect(dialog.getByRole("heading", { name: "Hidden brands" })).toBeVisible()
  const save = dialog.getByRole("button", { name: "Save hidden brands" })
  await expect(save).toBeDisabled()
  await dialog.getByLabel("Hide Acme Pumps from this customer").check()
  await dialog.getByLabel("Hide Orbit from this customer").check()
  await expect(dialog.getByText("all retail hidden")).toBeVisible()
  await save.click()

  await expect.poll(() => saves.length).toBe(1)
  expect(saves[0].path).toBe("/api/v1/admin/customers/cust-1/brand-access")
  expect([...saves[0].body.hiddenBrands].sort()).toEqual(["b1", "b3"])
  await expect(dialog.getByText("2 hidden")).toBeVisible()
  await expect(save).toBeDisabled()

  // Clear all, save: everything visible again.
  await dialog.getByRole("button", { name: "Clear all" }).click()
  await save.click()
  await expect.poll(() => saves.length).toBe(2)
  expect(saves[1].body.hiddenBrands).toEqual([])
})
