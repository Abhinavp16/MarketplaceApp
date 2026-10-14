import { expect, test } from "@playwright/test"

const applicant = {
  _id: "cust-9",
  name: "Sample Traders",
  email: "",
  phone: "8100000009",
  role: "buyer",
  hiddenBrands: ["b2"],
  businessInfo: { businessName: "Siddhi traders", verified: false, status: "pending", excludedCategories: [] },
  createdAt: "2026-10-12T10:00:00.000Z",
  updatedAt: "2026-10-12T10:00:00.000Z",
}
const brands = [{ _id: "b1", name: "Acme Pumps" }, { _id: "b2", name: "Zenith" }]

test("hide brands from a wholesaler on Account Upgrades too", async ({ page }) => {
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
      return route.fulfill({ json: { success: true, message: "Saved", data: { hiddenBrands: body.hiddenBrands } } })
    }
    if (url.pathname.endsWith("/admin/customers")) return route.fulfill({ json: { success: true, data: [applicant], pagination: { page: 1, total: 1, totalPages: 1 } } })
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { success: true, data: brands, pagination: { page: 1, total: 2, totalPages: 1 } } })
    return route.fulfill({ json: { success: true, data: [] } })
  })

  await page.goto("/account-upgrades")
  await page.getByRole("row", { name: /Sample Traders/ }).getByRole("button", { name: /Review/ }).click()
  const dialog = page.getByRole("dialog")
  await expect(dialog.getByRole("heading", { name: "Hidden brands" })).toBeVisible()
  await expect(dialog.getByLabel("Hide Zenith from this customer")).toBeChecked()
  await dialog.getByLabel("Hide Acme Pumps from this customer").check()
  await dialog.getByRole("button", { name: "Save hidden brands" }).click()

  await expect.poll(() => saves.length).toBe(1)
  expect(saves[0].path).toBe("/api/v1/admin/customers/cust-9/brand-access")
  expect([...saves[0].body.hiddenBrands].sort()).toEqual(["b1", "b2"])
})
