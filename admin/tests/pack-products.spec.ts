import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

const cableCategory = {
  _id: "cat-cable",
  name: "Submersible Cable",
  slug: "submersible-cable",
  company: { _id: "brand-m", name: "Orbit", slug: "orbit" },
  parent: null,
  order: 1,
  isActive: true,
  productCount: 0,
  createdAt: "2026-09-20T09:00:00.000Z",
}

async function mockAdminApi(page: Page, extra: (path: string) => Json | null = () => null) {
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
    const custom = extra(url.pathname)
    if (custom) return route.fulfill({ json: custom })
    const pagination = { page: 1, total: 1, totalPages: 1 }
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { data: [cableCategory.company], pagination } })
    if (url.pathname.endsWith("/categories")) return route.fulfill({ json: { data: [cableCategory], pagination } })
    return route.fulfill({ json: { data: [] } })
  })
  return writes
}

test("bundle cable: priced per meter, stock typed in bundles, live preview", async ({ page }) => {
  const writes = await mockAdminApi(page)
  await page.goto("/products/add?categoryId=cat-cable")

  await page.getByLabel("Product Name", { exact: true }).fill("4.0 sqmm Test Cable")
  await page.getByLabel("MRP (₹)").fill("88")
  await page.getByLabel("Customer Price (₹)").fill("82")
  await page.getByLabel("Wholesale Price (₹)").fill("75")

  await page.getByRole("combobox").filter({ hasText: "Select price unit" }).click()
  await page.getByRole("option", { name: "Bundle" }).click()

  // A plain number is ambiguous for a bundle: the form asks for "m".
  const packing = page.getByLabel("Packing")
  await packing.fill("500")
  await expect(page.getByTestId("packing-hint")).toContainText('Add "m" (e.g. 500 m)')
  await packing.fill("500 m")
  await expect(page.getByTestId("packing-hint")).toContainText("1 bundle = 500 m")

  // Stock typed in bundles is stored in meters.
  await page.getByLabel("Stock in bundles").fill("25")
  await expect(page.getByLabel("Stock (meters)")).toHaveValue("12500")
  await expect(page.getByTestId("stock-in-packs")).toContainText("12,500 m = 25 bundles")

  await page.getByLabel("Min Wholesale Qty (bundles)").fill("1")
  await page.getByLabel("Min Customer Qty (meters)").fill("10")

  const preview = page.getByTestId("pack-preview")
  await expect(preview).toContainText("Sold by the bundle · priced per meter")
  await expect(preview).toContainText("₹75/Meter · 1 Bundle (500 m) = ₹37,500")
  await expect(preview).toContainText("minimum 1 Bundle (500 m)")
  await expect(preview).toContainText("₹82/Meter")
  await expect(preview).toContainText("Buys cut lengths · minimum 10 m")
  await page.screenshot({ path: "test-results/pack-product-form.png", fullPage: true })
})

test("editing a service wire saves meters, coil minimum and customer minimum", async ({ page }) => {
  const product = {
    _id: "prod-wire",
    name: "4 Core Premium 12mm",
    sku: "MOU-SC-020",
    category: "submersible-cable",
    categoryRef: "cat-cable",
    company: { _id: "brand-m", name: "Orbit" },
    mrp: 82,
    retailPrice: 82,
    wholesalePrice: 75,
    priceUnit: "Coil",
    packing: "500 m",
    stock: 50000,
    lowStockThreshold: 500,
    minWholesaleQuantity: 1,
    minCustomerQuantity: 1,
    negotiationEnabled: true,
    status: "active",
    images: [{ url: "https://example.invalid/wire.jpg", isPrimary: true }],
    specifications: [],
    tags: [],
    labelIds: [],
  }
  const writes = await mockAdminApi(page, (path) => (path.endsWith("/admin/products/prod-wire") ? { success: true, data: product } : null))
  await page.goto("/products/add?edit=prod-wire")

  await expect(page.getByLabel("Stock (meters)")).toHaveValue("50000")
  await expect(page.getByLabel("Stock in coils")).toHaveValue("100")
  await page.getByLabel("Stock in coils").fill("80")
  await expect(page.getByLabel("Stock (meters)")).toHaveValue("40000")
  await page.getByLabel("Min Customer Qty (meters)").fill("25")
  await expect(page.getByTestId("pack-preview")).toContainText("₹75/Meter · 1 Coil (500 m) = ₹37,500")

  await page.getByRole("button", { name: "Update" }).first().click()
  await expect.poll(() => writes.find((write) => write.path.endsWith("/admin/products/prod-wire"))?.body).toMatchObject({
    priceUnit: "Coil",
    packing: "500 m",
    stock: 40000,
    minWholesaleQuantity: 1,
    minCustomerQuantity: 25,
  })
})

test("packet product: pieces per packet and plain products keep the old hint", async ({ page }) => {
  await mockAdminApi(page)
  await page.goto("/products/add?categoryId=cat-cable")
  await expect(page.getByTestId("packing-hint")).toHaveText("Packaging or pack size shown to customers.")
  await page.getByRole("combobox").filter({ hasText: "Select price unit" }).click()
  await page.getByRole("option", { name: "Packet" }).click()
  await page.getByLabel("Packing").fill("15")
  await page.getByLabel("Wholesale Price (₹)").fill("720")
  await expect(page.getByTestId("packing-hint")).toContainText("1 packet = 15 pieces")
  await expect(page.getByTestId("pack-preview")).toContainText("₹720/Piece · 1 Packet (15 pieces) = ₹10,800")
  await expect(page.getByLabel("Stock (pieces)")).toBeVisible()
})

test("order details show bundles next to meters", async ({ page }) => {
  const order = {
    _id: "order-cable-1",
    orderNumber: "ORD-2026-CABLE",
    orderType: "retail",
    acceptanceStatus: null,
    items: [
      { productSnapshot: { name: "4.0 sqmm Test Cable" }, variantSnapshot: { priceUnit: "Bundle", packing: "500 m" }, quantity: 1000, pricePerUnit: 75 },
      { productSnapshot: { name: "Test Pump" }, variantSnapshot: { priceUnit: "Set", packing: "1" }, quantity: 2, pricePerUnit: 9000 },
    ],
    customerSnapshot: { name: "Dealer", email: "dealer@example.invalid", phone: "9000000010" },
    total: 93000,
    status: "pending_payment",
    createdAt: "2026-09-30T11:30:00.000Z",
    shippingAddress: { addressLine1: "Market Road", city: "Metro City", state: "DS", pincode: "000001" },
    statusHistory: [],
    payment: null,
  }
  await mockAdminApi(page, (path) => {
    if (path.endsWith(`/orders/${order._id}`)) return { data: order }
    if (path.endsWith("/orders")) return { data: [order], pagination: { page: 1, total: 1, totalPages: 1 } }
    return null
  })
  await page.goto("/orders")
  await page.getByRole("button", { name: "View", exact: false }).first().click()
  const dialog = page.getByRole("dialog")
  await expect(dialog.getByText("Qty: 2 Bundles (1,000 m)")).toBeVisible()
  await expect(dialog.getByText("Qty: 2", { exact: true })).toBeVisible()
})
