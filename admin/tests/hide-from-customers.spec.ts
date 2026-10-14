import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

const shownBrand = { _id: "brand-a", name: "Brand A", slug: "brand-a", order: 1, createdAt: "2026-09-20T09:00:00.000Z" }
const hiddenBrand = { _id: "brand-b", name: "Brand B", slug: "brand-b", order: 2, createdAt: "2026-09-20T09:00:00.000Z", hideFromCustomers: true }

const topCategory = {
  _id: "cat-pumps",
  name: "Pumps",
  slug: "pumps",
  company: { _id: "brand-a", name: "Brand A", slug: "brand-a" },
  parent: null,
  order: 1,
  isActive: true,
  productCount: 0,
  createdAt: "2026-09-20T09:00:00.000Z",
  hideFromCustomers: true,
}

async function mockAdminApi(page: Page, { companies, categories = [] }: { companies: Json[]; categories?: Json[] }) {
  const writes: { method: string; path: string; body: Json }[] = []
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const method = request.method()
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (method === "POST" || method === "PUT") {
      const body = (request.postDataJSON() || {}) as Json
      writes.push({ method, path: url.pathname, body })
      return route.fulfill({ json: { success: true, data: { _id: "saved", ...body } } })
    }
    const pagination = { page: 1, total: companies.length, totalPages: 1 }
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { data: companies, pagination } })
    if (url.pathname.endsWith("/categories")) return route.fulfill({ json: { data: categories, pagination } })
    return route.fulfill({ json: { data: [] } })
  })
  return writes
}

test("a new brand can be hidden from customers and guests", async ({ page }) => {
  const writes = await mockAdminApi(page, { companies: [shownBrand, hiddenBrand] })
  await page.goto("/brands")

  // The list marks the hidden brand only.
  await expect(page.getByText("Hidden from customers")).toHaveCount(1)

  await page.getByRole("button", { name: "Add Brand" }).click()
  await page.getByPlaceholder("e.g., John Deere, Mahindra").fill("Brand C")
  const toggle = page.getByRole("switch", { name: "Hide from customers and guests" })
  await expect(toggle).not.toBeChecked()
  await toggle.click()
  await page.getByRole("button", { name: "Create Brand" }).click()

  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0]).toMatchObject({ method: "POST", body: { name: "Brand C", hideFromCustomers: true } })
})

test("editing a hidden brand shows it switched on and can show it again", async ({ page }) => {
  const writes = await mockAdminApi(page, { companies: [hiddenBrand] })
  await page.goto("/brands")
  await page.getByRole("button", { name: "Edit brand" }).first().click()
  const toggle = page.getByRole("switch", { name: "Hide from customers and guests" })
  await expect(toggle).toBeChecked()
  await toggle.click()
  await page.getByRole("button", { name: "Update Brand" }).click()
  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0]).toMatchObject({ method: "PUT", path: "/api/v1/companies/brand-b", body: { hideFromCustomers: false } })
})

test("only top-level categories get the switch", async ({ page }) => {
  const writes = await mockAdminApi(page, { companies: [shownBrand], categories: [topCategory] })
  await page.goto("/categories")
  await expect(page.getByText("Hidden from customers").first()).toBeVisible()

  await page.getByRole("button", { name: "Add Category" }).click()
  await page.getByPlaceholder("e.g., Machinery, Seeds, Fertilizers").fill("Cables")
  const toggle = page.getByRole("switch", { name: "Hide from customers and guests" })
  await expect(toggle).toBeVisible()
  await toggle.click()

  // Choosing a parent makes it a subcategory: the switch goes away.
  const dialog = page.getByRole("dialog")
  await dialog.getByText("None (Root Category)").click()
  await page.getByRole("option", { name: "Pumps" }).click()
  await expect(page.getByRole("switch", { name: "Hide from customers and guests" })).toHaveCount(0)

  // Back to top-level: the switch returns, still on, and is saved.
  await dialog.getByText("Pumps", { exact: true }).click()
  await page.getByRole("option", { name: "None (Root Category)" }).click()
  await expect(page.getByRole("switch", { name: "Hide from customers and guests" })).toBeChecked()
  await page.getByRole("button", { name: "Create Category" }).click()

  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0]).toMatchObject({ method: "POST", body: { name: "Cables", parent: null, hideFromCustomers: true } })
})
