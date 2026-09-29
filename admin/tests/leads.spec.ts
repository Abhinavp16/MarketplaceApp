import { expect, test } from "@playwright/test"

const leadsResponse = {
  success: true,
  data: {
    potentialCustomers: [
      {
        userId: "u1",
        productId: "p1",
        viewCount: 3,
        totalWatchSeconds: 200,
        averageWatchSeconds: 67,
        lastViewed: new Date(Date.now() - 15 * 60 * 1000).toISOString(),
        addedToCart: true,
        interest: "Hot",
        user: { name: "Asha Buyer", email: "asha@example.invalid", phone: "9000000001", role: "buyer" },
        product: { name: "Pump A", price: 900, mrp: 1000, discountPercent: 10, stock: 20 },
      },
      {
        userId: "u2",
        productId: "p2",
        viewCount: 1,
        totalWatchSeconds: 0,
        averageWatchSeconds: 0,
        lastViewed: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
        addedToCart: false,
        interest: "Browsing",
        user: { name: "Old App User", email: "", phone: "9000000002", role: "buyer" },
        product: { name: "Pump B", price: 480, mrp: 480, stock: 5 },
      },
    ],
    summary: { total: 2, hot: 1, warm: 0, browsing: 1, addedToCart: 1, averageViews: 2, averageWatchSeconds: 100 },
    rules: { periodDays: 5, delayMinutes: 10, retentionDays: 5 },
    pagination: { page: 1, limit: 30, total: 2, pages: 1 },
  },
}

test("leads page shows repeat views, watch time, cart badge and discounted price", async ({ page }) => {
  let requestedPeriod: string | null = null

  await page.addInitScript(() => {
    localStorage.setItem("accessToken", "test-token")
    localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
    localStorage.setItem("loginAt", String(Date.now()))
  })
  await page.route("**/api/v1/**", async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
    if (url.pathname.endsWith("/admin/analytics/potential-customers")) {
      requestedPeriod = url.searchParams.get("period")
      return route.fulfill({ json: leadsResponse })
    }
    return route.fulfill({ json: { data: [] } })
  })

  await page.goto("/potential-customers")

  await expect.poll(() => requestedPeriod).toBe("5d")
  await expect(page.getByText("A lead appears 10 minutes after the last view", { exact: false })).toBeVisible()

  const firstRow = page.getByRole("row", { name: /Asha Buyer/ })
  await expect(firstRow.getByText("Viewed 3 times")).toBeVisible()
  await expect(firstRow.getByText("3m 20s")).toBeVisible()
  await expect(firstRow.getByText("~1m 7s per view")).toBeVisible()
  await expect(firstRow.getByText("Added to cart")).toBeVisible()
  await expect(firstRow.getByText("₹900")).toBeVisible()
  await expect(firstRow.getByText("₹1,000")).toBeVisible()
  await expect(firstRow.getByText("Hot")).toBeVisible()

  const secondRow = page.getByRole("row", { name: /Old App User/ })
  await expect(secondRow.getByText("Viewed 1 time")).toBeVisible()
  await expect(secondRow.getByText("—")).toBeVisible()
  await expect(secondRow.getByText("Added to cart")).toHaveCount(0)

  // Summary cards come from the backend (whole result, not just this page).
  await expect(page.getByText("1 hot · 0 warm")).toBeVisible()
  await expect(page.getByText("1m 40s")).toBeVisible()

  // Period options match the 5-day retention.
  const options = await page.locator("select option").allTextContents()
  expect(options).toEqual(["Last 24 hours", "Last 3 days", "Last 5 days"])
})
