import { expect, Page, test } from "@playwright/test"

// Brands and categories hidden from customers are hidden from anyone the API
// can't identify. Admin and member pages must send their sign-in when they
// load catalog data, or hidden brands vanish from the panel (13 Oct bug:
// "Category unavailable" on a hidden brand's subcategory).

const hiddenSub = { _id: "6acf00000000000000000002", name: "Series 1 HP", slug: "series-1-hp", parent: { _id: "6acf00000000000000000001", name: "Submersible Series" }, company: { _id: "6acf00000000000000000009", name: "SERIES PUMPS" }, isActive: true }
const categories = [{ _id: "6acf00000000000000000001", name: "Submersible Series", slug: "submersible-series", parent: null, company: { _id: "6acf00000000000000000009", name: "SERIES PUMPS" } }, hiddenSub]
const product = { _id: "prod-1", name: "Series Pump 1HP", sku: "SER-1", retailPrice: 900, wholesalePrice: 800, stock: 5, status: "active", images: [] }

async function mockApi(page: Page, role: "admin" | "staff") {
  const unsigned: string[] = []
  await page.addInitScript(({ role }) => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "u-1", name: "Team", role }))
    localStorage.setItem("loginAt", String(Date.now()))
    if (role === "staff") localStorage.setItem("sessionExpiresAt", new Date(Date.now() + 3600_000).toISOString())
  }, { role })
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const signedIn = Boolean(request.headers()["authorization"])
    const isCatalog = /\/api\/v1\/(categories|companies)(\/|$|\?)/.test(url.pathname + url.search)
    if (isCatalog && !signedIn) {
      // Like the real API: the hidden brand is invisible to guests.
      unsigned.push(url.pathname)
      if (/\/categories\/[^/]+$/.test(url.pathname)) return route.fulfill({ status: 404, json: { success: false, message: "Category not found" } })
      return route.fulfill({ json: { success: true, data: [], pagination: { page: 1, total: 0, totalPages: 1 } } })
    }
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role } } })
    if (url.pathname.endsWith(`/categories/${hiddenSub._id}`)) return route.fulfill({ json: { success: true, data: hiddenSub } })
    if (url.pathname.endsWith("/categories")) return route.fulfill({ json: { success: true, data: categories, pagination: { page: 1, total: 2, totalPages: 1 } } })
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { success: true, data: [{ _id: "6acf00000000000000000009", name: "SERIES PUMPS", hideFromCustomers: true }], pagination: { page: 1, total: 1, totalPages: 1 } } })
    if (url.pathname.endsWith("/admin/products") || url.pathname.endsWith("/staff/products")) return route.fulfill({ json: { success: true, data: [product], pagination: { page: 1, total: 1, totalPages: 1 } } })
    return route.fulfill({ json: { success: true, data: [] } })
  })
  return unsigned
}

test("admin: a hidden brand's subcategory products page opens", async ({ page }) => {
  const unsigned = await mockApi(page, "admin")
  await page.goto(`/categories/${hiddenSub._id}/products`)
  await expect(page.getByText("Series Pump 1HP")).toBeVisible()
  await expect(page.getByText("Category unavailable")).toHaveCount(0)
  expect(unsigned).toEqual([])
})

test("member: a hidden brand's subcategory products page opens", async ({ page }) => {
  const unsigned = await mockApi(page, "staff")
  await page.goto(`/member/products/${hiddenSub._id}`)
  await expect(page.getByText("Series Pump 1HP")).toBeVisible()
  expect(unsigned).toEqual([])
})

for (const path of ["/price-management", "/banners", "/member/products"]) {
  test(`${path} loads catalog data signed in`, async ({ page }) => {
    const unsigned = await mockApi(page, path.startsWith("/member") ? "staff" : "admin")
    const loaded = page.waitForRequest((r) => /\/api\/v1\/(categories|companies)\?/.test(r.url()))
    await page.goto(path)
    await loaded
    await page.waitForTimeout(1500)
    expect(unsigned).toEqual([])
  })
}
