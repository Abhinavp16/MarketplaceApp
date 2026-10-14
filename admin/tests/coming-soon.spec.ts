import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

const category = {
  _id: "cat-solar",
  name: "Solar Pumps",
  slug: "solar-pumps",
  company: { _id: "brand-s", name: "Zenith", slug: "zenith" },
  parent: null,
  order: 1,
  isActive: true,
  productCount: 0,
  createdAt: "2026-09-20T09:00:00.000Z",
}

const product = (comingSoon: Json, extra: Json = {}) => ({
  _id: "prod-solar",
  name: "3 HP Solar Pump",
  sku: "SOL-3",
  category: "solar-pumps",
  categoryRef: "cat-solar",
  company: { _id: "brand-s", name: "Zenith" },
  mrp: 90000,
  retailPrice: 85000,
  wholesalePrice: 80000,
  priceUnit: "Set",
  packing: "1",
  stock: 0,
  minWholesaleQuantity: 1,
  negotiationEnabled: true,
  status: "active",
  images: [{ url: "https://example.invalid/solar.jpg", isPrimary: true }],
  specifications: [],
  tags: [],
  labelIds: [],
  comingSoon,
  ...extra,
})

async function mockApi(page: Page, routes: (path: string, url: URL) => Json | null) {
  const writes: { method: string; path: string; body: Json }[] = []
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (request.method() === "PUT" || request.method() === "POST") {
      const body = (request.postDataJSON() || {}) as Json
      writes.push({ method: request.method(), path: url.pathname, body })
      return route.fulfill({ json: { success: true, data: { _id: "prod-solar", ...body }, launchNotified: 3 } })
    }
    const custom = routes(url.pathname, url)
    if (custom) return route.fulfill({ json: custom })
    const pagination = { page: 1, total: 1, totalPages: 1 }
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { data: [category.company], pagination } })
    if (url.pathname.endsWith("/categories")) return route.fulfill({ json: { data: [category], pagination } })
    return route.fulfill({ json: { data: [] } })
  })
  return writes
}

test("mark a product Coming Soon with a hidden price and an auto-launch date", async ({ page }) => {
  const writes = await mockApi(page, (path) =>
    path.endsWith("/admin/products/prod-solar")
      ? { success: true, data: product({ enabled: false, showPrice: true, expectedDate: null, autoLaunch: false }, { notifyCount: 0, isComingSoonNow: false }) }
      : null,
  )
  await page.goto("/products/add?edit=prod-solar")
  const card = page.getByTestId("coming-soon-card")
  await card.getByRole("switch", { name: "Coming Soon" }).click()
  await card.getByRole("switch", { name: "Show price" }).click()
  const auto = card.getByRole("checkbox", { name: "Go live automatically on this date" })
  await expect(auto).toBeDisabled()
  await card.getByLabel("Expected date").fill("2026-10-15")
  await auto.click()
  await page.screenshot({ path: "test-results/coming-soon-form.png", fullPage: true })

  await page.getByRole("button", { name: "Update" }).first().click()
  await expect.poll(() => writes.find((w) => w.path.endsWith("/admin/products/prod-solar"))?.body?.comingSoon).toMatchObject({
    enabled: true,
    showPrice: false,
    autoLaunch: true,
  })
  const sent = writes.find((w) => w.path.endsWith("/admin/products/prod-solar"))!.body.comingSoon as Json
  expect(String(sent.expectedDate)).toContain("2026-10-1")
})

test("turning Coming Soon off tells the admin who will be notified", async ({ page }) => {
  await mockApi(page, (path) =>
    path.endsWith("/admin/products/prod-solar")
      ? { success: true, data: product({ enabled: true, showPrice: false, expectedDate: "2026-10-15T00:00:00.000Z", autoLaunch: false }, { notifyCount: 3, isComingSoonNow: true }) }
      : null,
  )
  await page.goto("/products/add?edit=prod-solar")
  const card = page.getByTestId("coming-soon-card")
  await expect(card.getByLabel("Expected date")).toHaveValue("2026-10-15")
  await expect(card.getByTestId("notify-count")).toContainText("3 people asked to be notified")
  await card.getByRole("switch", { name: "Coming Soon" }).click()
  await expect(card.getByTestId("notify-count")).toContainText("they'll be notified when you save")
  await page.getByRole("button", { name: "Update" }).first().click()
  await expect(page.getByText("Product updated — 3 customers were notified it's available")).toBeVisible()
})

test("products list shows the Coming Soon badge and filter", async ({ page }) => {
  const requests: string[] = []
  await mockApi(page, (path, url) => {
    if (!path.endsWith("/admin/products")) return null
    requests.push(url.search)
    return { success: true, data: [product({ enabled: true })], pagination: { page: 1, total: 1, totalPages: 1 } }
  })
  await page.goto("/products")
  await expect(page.getByTestId("coming-soon-badge").first()).toBeVisible()
  await page.getByRole("button", { name: "Coming Soon" }).click()
  await expect.poll(() => requests.some((q) => q.includes("comingSoon=true"))).toBe(true)
})
