import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

const dealer = { id: "u-dealer", name: "Demo Traders", email: "demo@example.invalid", phone: "9000000061" }
const group = { id: "grp-1", number: "REQ-2026-00120012" }
const address = {
  fullName: "Demo Traders",
  phone: "9000000061",
  addressLine1: "Market Road",
  city: "Metro City",
  state: "DS",
  pincode: "000001",
}

const listItem = (id: string, name: string, qty: number, price: number, extra: Json = {}) => ({
  id,
  negotiationNumber: `NGT-${id}`,
  wholesaler: dealer,
  product: { id: `p-${id}`, name, price, priceUnit: extra.priceUnit || "Piece", packing: extra.packing || "1" },
  requestedQuantity: qty,
  requestedPricePerUnit: price,
  requestedTotalPrice: qty * price,
  currentPricePerUnit: price,
  currentTotalPrice: qty * price,
  status: "pending",
  orderId: null,
  approvedBy: null,
  requestGroup: group,
  createdAt: "2026-10-01T09:00:00.000Z",
  ...extra,
})

const negotiations = [
  listItem("n1", "4 Core Premium 12mm", 1000, 75, { priceUnit: "Coil", packing: "500 m" }),
  listItem("n2", "2 Inch 28 Kg Green Valley", 30, 720, { priceUnit: "Packet", packing: "15" }),
  listItem("n3", "5HP Openwell", 2, 9000),
  listItem("n4", "1 HP MCB Panel", 20, 740, { requestGroup: null }),
]

const groupDetail = {
  requestGroup: group,
  wholesaler: { ...dealer, address: "Market Road" },
  lastOrderAddress: address,
  items: negotiations.slice(0, 3).map((n) => ({
    id: n.id,
    negotiationNumber: n.negotiationNumber,
    product: n.product,
    requestedQuantity: n.requestedQuantity,
    pricePerUnit: n.currentPricePerUnit,
    totalPrice: n.currentTotalPrice,
    status: "pending",
    isExpired: false,
    order: null,
    canAccept: true,
  })),
}

const singleDetail = {
  _id: "n4",
  negotiationNumber: "NGT-n4",
  productSnapshot: { name: "1 HP MCB Panel", sku: "MCB-1", price: 740, priceUnit: "Piece", packing: "20" },
  wholesalerId: { _id: dealer.id, name: dealer.name, phone: dealer.phone },
  requestedQuantity: 20,
  requestedPricePerUnit: 740,
  currentPricePerUnit: 740,
  currentTotalPrice: 14800,
  status: "pending",
  currentOfferBy: "wholesaler",
  history: [{ action: "requested", by: "wholesaler", pricePerUnit: 740, totalPrice: 14800, timestamp: "2026-10-01T09:00:00.000Z" }],
  expiresAt: "2026-12-01T00:00:00.000Z",
  orderId: null,
  lastOrderAddress: address,
}

async function mockApi(page: Page, extra: (path: string) => Json | null = () => null) {
  const writes: { method: string; path: string; body: Json }[] = []
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/socket.io/**", (route) => route.abort())
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    const method = request.method()
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (method === "PUT" || method === "POST") {
      const body = (request.postDataJSON() || {}) as Json
      writes.push({ method, path: url.pathname, body })
      const delivery = Number(body.deliveryCharge || 0)
      return route.fulfill({ json: { success: true, data: { orderId: "o-1", orderNumber: "ORD-2026-9001", total: 1000 + delivery, deliveryFee: delivery } } })
    }
    const custom = extra(url.pathname)
    if (custom) return route.fulfill({ json: custom })
    if (url.pathname.endsWith(`/admin/negotiations/groups/${group.id}`)) return route.fulfill({ json: { success: true, data: groupDetail } })
    if (url.pathname.endsWith("/admin/negotiations/n4")) return route.fulfill({ json: { success: true, data: singleDetail } })
    if (url.pathname.endsWith("/admin/negotiations")) {
      return route.fulfill({ json: { success: true, data: negotiations, pagination: { page: 1, total: negotiations.length, totalPages: 1 } } })
    }
    return route.fulfill({ json: { data: [] } })
  })
  return writes
}

test("products sent together are accepted into one order with one delivery charge", async ({ page }) => {
  const writes = await mockApi(page)
  await page.goto("/negotiations")

  const header = page.getByTestId("requirement-group-row")
  await expect(header).toHaveCount(1)
  await expect(header).toContainText("REQ-2026-00120012")
  await expect(header).toContainText("3 products")
  await expect(header).toContainText("₹1,14,600")
  // Review opens the requirement's products; accept from there.
  await header.getByRole("button", { name: /Open requirement/ }).click()
  const panel = page.getByTestId("requirement-group-panel")
  await expect(panel.getByTestId("group-panel-item")).toHaveCount(3)
  await page.screenshot({ path: "test-results/deal-desk-group-panel.png" })
  await panel.getByRole("button", { name: "Accept & Create Order" }).click()

  const dialog = page.getByTestId("group-accept-dialog")
  await expect(dialog.getByTestId("group-item")).toHaveCount(3)
  await expect(dialog).toContainText("2 Coils (1,000 m) × ₹75")
  await expect(dialog).toContainText("2 Packets (30 pieces) × ₹720")

  // Leave the pump out of this order.
  await dialog.getByRole("checkbox", { name: "Include 5HP Openwell" }).click()
  await dialog.getByLabel("Delivery charge (₹)").fill("1200")
  const totals = dialog.getByTestId("order-total-line")
  await expect(totals).toContainText("Subtotal₹96,600")
  await expect(totals).toContainText("Delivery₹1,200")
  await expect(totals).toContainText("Total₹97,800")
  await page.screenshot({ path: "test-results/deal-desk-group-accept.png" })

  await dialog.getByRole("button", { name: "Accept 2 products · ₹97,800" }).click()
  await expect.poll(() => writes.find((w) => w.path.endsWith(`/admin/negotiations/groups/${group.id}/accept`))?.body).toMatchObject({
    negotiationIds: ["n1", "n2"],
    deliveryCharge: 1200,
    shippingAddress: { fullName: "Demo Traders", city: "Metro City", pincode: "000001" },
  })
})

test("a negative delivery charge can't be submitted", async ({ page }) => {
  await mockApi(page)
  await page.goto("/negotiations")
  await page.getByTestId("requirement-group-row").getByRole("button", { name: /Open requirement/ }).click()
  await page.getByTestId("requirement-group-panel").getByRole("button", { name: "Accept & Create Order" }).click()
  const dialog = page.getByTestId("group-accept-dialog")
  await dialog.getByLabel("Delivery charge (₹)").fill("-10")
  await expect(dialog).toContainText("Enter 0 or a positive amount.")
  await expect(dialog.getByRole("button", { name: /Accept 3 products/ })).toBeDisabled()
})

test("single requirement: delivery charge is added to the order total", async ({ page }) => {
  const writes = await mockApi(page)
  await page.goto("/negotiations")
  await page.getByRole("button", { name: "Open NGT-n4" }).click()
  await page.getByRole("button", { name: /Accept Deal & Create Order/ }).click()

  const dialog = page.getByRole("dialog", { name: "Accept Deal & Create Order" })
  await dialog.getByLabel("Delivery charge (₹)").fill("300")
  await expect(dialog.getByTestId("order-total-line")).toContainText("Total₹15,100")
  await dialog.getByRole("button", { name: "Accept · ₹15,100" }).click()
  await expect.poll(() => writes.find((w) => w.path.endsWith("/admin/negotiations/n4/accept"))?.body).toMatchObject({ deliveryCharge: 300 })
})

test("order details show subtotal, delivery and total", async ({ page }) => {
  const order = {
    _id: "order-deal-1",
    orderNumber: "ORD-2026-9001",
    orderType: "wholesale",
    acceptanceStatus: null,
    items: [
      { productSnapshot: { name: "4 Core Premium 12mm" }, variantSnapshot: { priceUnit: "Coil", packing: "500 m" }, quantity: 1000, pricePerUnit: 75 },
      { productSnapshot: { name: "2 Inch 28 Kg Green Valley" }, variantSnapshot: { priceUnit: "Packet", packing: "15" }, quantity: 30, pricePerUnit: 720 },
    ],
    customerSnapshot: { name: "Demo Traders", email: "demo@example.invalid", phone: "9000000061" },
    subtotal: 96600,
    deliveryFee: 1200,
    discount: 0,
    total: 97800,
    status: "pending_payment",
    createdAt: "2026-10-01T11:30:00.000Z",
    shippingAddress: address,
    statusHistory: [],
    payment: null,
  }
  await mockApi(page, (path) => {
    if (path.endsWith(`/orders/${order._id}`)) return { data: order }
    if (path.endsWith("/orders")) return { data: [order], pagination: { page: 1, total: 1, totalPages: 1 } }
    return null
  })
  await page.goto("/orders")
  await page.getByRole("button", { name: "View", exact: false }).first().click()
  const breakdown = page.getByRole("dialog").getByTestId("order-price-breakdown")
  await expect(breakdown).toContainText("SubtotalRs 96,600")
  await expect(breakdown).toContainText("DeliveryRs 1,200")
  await expect(page.getByRole("dialog")).toContainText("Rs 97,800")
})
