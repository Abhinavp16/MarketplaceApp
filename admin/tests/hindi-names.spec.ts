import { expect, Page, test } from "@playwright/test"

async function mockAdmin(page: Page) {
  const writes: { path: string; body: Record<string, unknown> }[] = []
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (url.pathname.endsWith("/admin/hindi-name/suggest")) {
      const body = request.postDataJSON() as { text: string }
      writes.push({ path: url.pathname, body })
      return route.fulfill({ json: { success: true, data: { text: body.text, suggestion: "सबमर्सिबल पंप 1.5 HP" } } })
    }
    if (url.pathname.endsWith("/hindi-names/generate-missing")) {
      writes.push({ path: url.pathname, body: request.postDataJSON() })
      return route.fulfill({ json: { success: true, data: { processed: 4, updated: 3, skipped: 0, failed: 1 } } })
    }
    if (url.pathname.endsWith("/companies")) return route.fulfill({ json: { data: [{ _id: "brand-a", name: "Brand A", slug: "brand-a" }], pagination: { page: 1, total: 1, totalPages: 1 } } })
    return route.fulfill({ json: { data: [], pagination: { page: 1, total: 0, totalPages: 1 } } })
  })
  return writes
}

test("category form suggests a Hindi name and notes automatic filling", async ({ page }) => {
  const writes = await mockAdmin(page)
  await page.goto("/categories")
  await page.getByRole("button", { name: "Add Category" }).click()
  await expect(page.getByPlaceholder("Leave empty to fill automatically").first()).toBeVisible()
  await page.getByPlaceholder("e.g., Machinery, Seeds, Fertilizers").fill("Submersible Pump 1.5 HP")
  await page.getByRole("button", { name: "Suggest Hindi" }).first().click()
  await expect(page.getByPlaceholder("Leave empty to fill automatically").first()).toHaveValue("सबमर्सिबल पंप 1.5 HP")
  expect(writes[0].body).toEqual({ text: "Submersible Pump 1.5 HP" })
})

test("fix broken Hindi names runs the repair mode", async ({ page }) => {
  const writes = await mockAdmin(page)
  page.on("dialog", (dialog) => dialog.accept())
  await page.goto("/products")
  await page.getByRole("button", { name: "Fix Broken Hindi Names Now" }).click()
  await expect.poll(() => writes.length).toBe(1)
  expect(writes[0].path).toMatch(/\/admin\/products\/hindi-names\/generate-missing$/)
  expect(writes[0].body).toEqual({ mode: "repair" })
  await expect(page.getByText("Hindi names: 3 updated out of 4, 1 could not be converted", { exact: false })).toBeVisible()
  await expect(page.getByRole("button", { name: "Convert Hindi Names Now" })).toBeVisible()
})
