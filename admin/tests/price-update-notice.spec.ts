import { expect, test } from "@playwright/test"

const product = {
  _id: "prod-1",
  name: "Pump One",
  sku: "P-1",
  retailPrice: 900,
  wholesalePrice: 800,
  stock: 10,
  pendingRetailPrice: null,
  pendingWholesalePrice: null,
  priceChangeEffectiveAt: null,
}

test("an immediate price save says when app users hear, then nudges the API once", async ({ page }) => {
  const flushCalls: number[] = []
  await page.clock.install()
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (url.pathname.endsWith("/admin/price-updates/flush")) {
      flushCalls.push(Date.now())
      return route.fulfill({ json: { success: true, data: { sent: true } } })
    }
    if (url.pathname.endsWith("/price-change")) {
      return route.fulfill({ json: { success: true, message: "Price updated successfully", data: { product: { ...product, retailPrice: 950 } } } })
    }
    if (url.pathname.endsWith("/admin/products")) return route.fulfill({ json: { success: true, data: [product], pagination: { page: 1, total: 1, totalPages: 1 } } })
    if (url.pathname.endsWith("/categories")) return route.fulfill({ json: { success: true, data: [{ _id: "cat-1", name: "Pumps", slug: "pumps", parent: null }] } })
    return route.fulfill({ json: { success: true, data: [] } })
  })
  page.on("dialog", (dialog) => dialog.accept())

  await page.goto("/price-management?categoryId=cat-1")
  const save = async (price: string) => {
    await page.getByLabel("New customer price for Pump One").fill(price)
    await page.getByRole("combobox").first().click()
    await page.getByRole("option", { name: "Immediately" }).click()
    await page.getByRole("button", { name: "Save price" }).click()
  }

  await save("950")
  await expect(page.getByText("App users get one message about your changes about 2 minutes after your last save.")).toBeVisible()

  // Another save 60 seconds later restarts the wait: no nudge at 105 s after the first.
  await page.clock.fastForward(60_000)
  await save("960")
  await page.clock.fastForward(50_000)
  expect(flushCalls).toHaveLength(0)

  // 105 seconds after the last save: one nudge.
  await page.clock.fastForward(60_000)
  await expect.poll(() => flushCalls.length).toBe(1)
  await page.clock.fastForward(300_000)
  expect(flushCalls).toHaveLength(1)
})
