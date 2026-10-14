import { expect, Page, test } from "@playwright/test"

const DAY = 24 * 60 * 60 * 1000
const iso = (offsetMs: number) => new Date(Date.now() + offsetMs).toISOString()

const websiteRequest = {
  _id: "req-website-1",
  status: "pending",
  source: "website",
  requestedAt: iso(-27 * DAY),
  dueAt: iso(3 * DAY),
  identityVerification: null,
  userId: { _id: "user-ws", name: "Demo Traders", phone: "9000000091", role: "wholesaler", isActive: true },
}

const appRequest = {
  _id: "req-app-1",
  status: "pending",
  source: "app",
  requestedAt: iso(-2 * DAY),
  dueAt: iso(28 * DAY),
  identityVerification: null,
  userId: { _id: "user-app", name: "Asha Buyer", email: "asha@example.com", role: "buyer", isActive: true },
}

async function mockDeletionRequests(page: Page) {
  const completeBodies: Record<string, unknown>[] = []
  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Test Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (url.pathname.endsWith("/complete") && route.request().method() === "POST") {
      completeBodies.push(route.request().postDataJSON())
      return route.fulfill({ json: { success: true, message: "Account access was revoked and the deletion request was completed." } })
    }
    if (url.pathname.endsWith("/admin/account-deletion-requests")) {
      return route.fulfill({ json: { success: true, data: [websiteRequest, appRequest], pagination: { page: 1, total: 2, totalPages: 1 } } })
    }
    return route.fulfill({ json: { data: [] } })
  })
  return completeBodies
}

test("a verified website request is completed in one step, with the confirmation sent", async ({ page }) => {
  const completeBodies = await mockDeletionRequests(page)
  page.on("dialog", (dialog) => dialog.accept())

  await page.goto("/account-deletion-requests", { waitUntil: "domcontentloaded" })
  await expect(page.getByText(/Due soon:/)).toHaveCount(1)

  await page.getByRole("button", { name: /Demo Traders/ }).click()
  const dialog = page.getByRole("dialog")
  const complete = dialog.getByRole("button", { name: "Complete deletion" })
  await expect(complete).toBeDisabled()
  await expect(dialog.getByText("If you reject the request, this note is shown to the customer in the app.")).toBeVisible()

  await dialog.getByRole("checkbox").check()
  await expect(complete).toBeEnabled()
  await complete.click()

  await expect.poll(() => completeBodies.length).toBe(1)
  expect(completeBodies[0]).toMatchObject({ identityVerified: true })
})

test("an app request needs no verification tick", async ({ page }) => {
  const completeBodies = await mockDeletionRequests(page)
  page.on("dialog", (dialog) => dialog.accept())

  await page.goto("/account-deletion-requests", { waitUntil: "domcontentloaded" })
  await page.getByRole("button", { name: /Asha Buyer/ }).click()
  const dialog = page.getByRole("dialog")
  await expect(dialog.getByRole("checkbox")).toHaveCount(0)
  await dialog.getByRole("button", { name: "Complete deletion" }).click()
  await expect.poll(() => completeBodies.length).toBe(1)
})
