import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

const brand = {
  _id: "brand-a",
  name: "Brand A",
  slug: "brand-a",
  order: 1,
  createdAt: "2026-09-20T09:00:00.000Z",
  customerDiscountPercent: 10,
  wholesalerDiscountPercent: null,
}

const parentCategory = {
  _id: "cat-pumps",
  name: "Pumps",
  slug: "pumps",
  company: { _id: "brand-a", name: "Brand A", slug: "brand-a" },
  parent: null,
  order: 1,
  isActive: true,
  productCount: 0,
  createdAt: "2026-09-20T09:00:00.000Z",
  customerDiscountPercent: null,
  wholesalerDiscountPercent: 30,
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
    const pagination = { page: 1, total: 1, totalPages: 1 }
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { data: companies, pagination } })
    if (url.pathname.endsWith("/categories")) return route.fulfill({ json: { data: categories, pagination } })
    return route.fulfill({ json: { data: [] } })
  })

  return writes
}

test("brand discount is shown and both percentages are saved", async ({ page }) => {
  const writes = await mockAdminApi(page, { companies: [brand] })
  await page.goto("/brands")

  await expect(page.getByText("Customer 10% off")).toBeVisible()
  await page.getByRole("button", { name: "Edit brand" }).first().click()

  await expect(page.getByLabel("Customer discount")).toHaveValue("10")
  await page.getByLabel("Wholesaler discount").fill("35")
  await page.getByRole("button", { name: "Update Brand" }).click()

  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0].method).toBe("PUT")
  expect(writes[0].path).toMatch(/\/companies\/brand-a$/)
  expect(writes[0].body).toMatchObject({ customerDiscountPercent: 10, wholesalerDiscountPercent: 35 })
})

test("brand form never overwrites discounts it could not load", async ({ page }) => {
  const { customerDiscountPercent: _c, wholesalerDiscountPercent: _w, ...brandWithoutDiscounts } = brand
  const writes = await mockAdminApi(page, { companies: [brandWithoutDiscounts] })
  await page.goto("/brands")

  await page.getByRole("button", { name: "Edit brand" }).first().click()
  await expect(page.getByText("Couldn't load the saved discounts", { exact: false })).toBeVisible()
  await expect(page.getByLabel("Customer discount")).toBeDisabled()
  await page.getByRole("button", { name: "Update Brand" }).click()

  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0].body).not.toHaveProperty("customerDiscountPercent")
  expect(writes[0].body).not.toHaveProperty("wholesalerDiscountPercent")
})

test("new category saves its discount and warns that the brand discount overrides it", async ({ page }) => {
  const writes = await mockAdminApi(page, { companies: [brand], categories: [parentCategory] })
  await page.goto("/categories")

  await expect(page.getByText("Dealer 30% off")).toBeVisible()
  await page.getByRole("button", { name: "Add Category" }).click()
  await page.getByPlaceholder("e.g., Machinery, Seeds, Fertilizers").fill("Cables")
  await page.getByLabel("Customer discount").fill("5")
  await expect(page.getByText("Brand Brand A has 10% — it overrides this.")).toBeVisible()
  await page.getByLabel("Wholesaler discount").fill("abc")
  await expect(page.getByLabel("Wholesaler discount")).toHaveValue("")
  await page.getByRole("button", { name: "Create Category" }).click()

  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0].method).toBe("POST")
  expect(writes[0].body).toMatchObject({
    name: "Cables",
    company: "brand-a",
    customerDiscountPercent: 5,
    wholesalerDiscountPercent: null,
  })
})

test("product form previews the discounted price from MRP", async ({ page }) => {
  await mockAdminApi(page, { companies: [brand], categories: [parentCategory] })
  await page.goto("/products/add?categoryId=cat-pumps")

  await page.getByLabel("MRP (₹)").fill("1000")
  const preview = page.getByTestId("effective-price-preview")
  await expect(preview).toBeVisible()
  // Brand A: customer 10% off MRP; Pumps category: wholesaler 30% off MRP.
  await expect(preview).toContainText("₹900")
  await expect(preview).toContainText("₹700")
  await expect(preview).toContainText("Brand Brand A: 10% off MRP")
  await expect(preview).toContainText("Category Pumps: 30% off MRP")
})
