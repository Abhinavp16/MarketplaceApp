import { expect, Page, test } from "@playwright/test"

// The backend still identifies members with the role value "staff".
const MEMBER_ROLE = "staff"

async function signIn(page: Page, role: "admin" | typeof MEMBER_ROLE) {
  await page.addInitScript(({ role }) => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "user-1", name: "Test User", role }))
    localStorage.setItem("loginAt", String(Date.now()))
    if (role !== "admin") localStorage.setItem("sessionExpiresAt", new Date(Date.now() + 60_000).toISOString())
  }, { role })
}

async function mockApi(page: Page, role: string, handlers: Record<string, unknown> = {}) {
  await page.route("**/api/v1/**", async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role } } })
    for (const [suffix, json] of Object.entries(handlers)) {
      if (url.pathname.endsWith(suffix)) return route.fulfill({ json })
    }
    return route.fulfill({ json: { data: [], pagination: { page: 1, total: 0, totalPages: 1 } } })
  })
}

test("old /staff links redirect to the member pages", async ({ page }) => {
  await signIn(page, MEMBER_ROLE)
  await mockApi(page, MEMBER_ROLE)

  await page.goto("/staff/orders")
  await expect(page).toHaveURL(/\/member\/orders$/)

  await page.goto("/staff/products")
  await expect(page).toHaveURL(/\/member\/products$/)
  await expect(page.getByRole("link", { name: "ORDERS" }).first()).toHaveAttribute("href", "/member/orders")
})

test("old member-management link redirects", async ({ page }) => {
  await signIn(page, "admin")
  await mockApi(page, "admin")
  await page.goto("/staff-management")
  await expect(page).toHaveURL(/\/member-management$/)
  await expect(page.getByText("Member Management").first()).toBeVisible()
})

test("deal desk shows Member for deals approved by a member", async ({ page }) => {
  await signIn(page, "admin")
  await mockApi(page, "admin", {
    "/admin/negotiations": {
      success: true,
      data: [{
        id: "507f1f77bcf86cd799439011",
        negotiationNumber: "NEG-MEMBER",
        product: { name: "Test Product", price: 100 },
        wholesaler: { name: "Test Buyer" },
        requestedQuantity: 5,
        requestedPricePerUnit: 80,
        status: "converted",
        approvedBy: { role: MEMBER_ROLE, name: "Ravi" },
      }],
      pagination: { page: 1, total: 1, totalPages: 1 },
    },
  })

  await page.goto("/negotiations")
  await expect(page.getByText("Member · Ravi").first()).toBeVisible()
  await expect(page.getByText(/Staff/)).toHaveCount(0)
})

test("customer list labels member accounts as member", async ({ page }) => {
  await signIn(page, "admin")
  await mockApi(page, "admin", {
    "/admin/customers": {
      success: true,
      data: [{ _id: "c1", name: "Ravi Member", email: "ravi@example.invalid", phone: "9000000003", role: MEMBER_ROLE, createdAt: "2026-09-20T09:00:00.000Z" }],
      pagination: { page: 1, total: 1, totalPages: 1 },
    },
  })

  await page.goto("/customers")
  // The page renders both a table and a (hidden) mobile card list; check the visible one.
  await expect(page.getByText("Ravi Member").locator("visible=true").first()).toBeVisible()
  await expect(page.getByText("member", { exact: true }).locator("visible=true").first()).toBeVisible()
  await expect(page.getByText("staff", { exact: true })).toHaveCount(0)
})
