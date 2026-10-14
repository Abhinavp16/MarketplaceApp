import { expect, Page, test } from "@playwright/test"

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n")
const FILE_NAME = "Ravi-Traders-ORD-2026-9001.pdf"
const group = { id: "grp-1", number: "REQ-2026-00120012" }
const dealer = { id: "u-dealer", name: "Dev Kumar", email: "demo@example.invalid", phone: "9000000061" }

const listItem = (id: string, extra: Record<string, unknown> = {}) => ({
    id,
    negotiationNumber: `NGT-${id}`,
    wholesaler: dealer,
    product: { id: `p-${id}`, name: `Product ${id}`, price: 100, priceUnit: "Piece", packing: "1" },
    requestedQuantity: 2,
    requestedPricePerUnit: 100,
    requestedTotalPrice: 200,
    currentPricePerUnit: 100,
    currentTotalPrice: 200,
    status: "pending",
    orderId: null,
    approvedBy: null,
    requestGroup: null,
    createdAt: "2026-10-01T09:00:00.000Z",
    ...extra,
})

async function mockApi(page: Page, role: "admin" | "staff") {
    const receiptRequests: string[] = []
    await page.addInitScript((r) => {
        localStorage.setItem("accessToken", "test-token")
        localStorage.setItem("user", JSON.stringify({ _id: "u-1", name: "Asha", role: r }))
        localStorage.setItem("loginAt", String(Date.now()))
        if (r === "staff") localStorage.setItem("sessionExpiresAt", new Date(Date.now() + 60 * 60_000).toISOString())
    }, role)
    await page.route("**/socket.io/**", (route) => route.abort())
    await page.route("**/api/v1/**", async (route) => {
        const url = new URL(route.request().url())
        const path = url.pathname.replace(/^.*\/api\/v1/, "")
        if (path === "/auth/me") return route.fulfill({ json: { data: { role } } })
        if (/\/orders\/[^/]+\/receipt$/.test(path)) {
            receiptRequests.push(path)
            return route.fulfill({
                status: 200,
                body: PDF,
                headers: {
                    "content-type": "application/pdf",
                    "x-receipt-filename": encodeURIComponent(FILE_NAME),
                    "access-control-expose-headers": "Content-Disposition, X-Receipt-Filename",
                },
            })
        }
        if (path === "/admin/negotiations") {
            const data = [
                listItem("n1", { status: "converted", orderId: "order-1", approvedBy: { name: "Mayur", role: "admin" } }),
                listItem("n2"),
                listItem("n3", { status: "converted", orderId: "order-2", requestGroup: group }),
                listItem("n4", { status: "converted", orderId: "order-2", requestGroup: group }),
            ]
            return route.fulfill({ json: { success: true, data, pagination: { page: 1, total: data.length, totalPages: 1 } } })
        }
        if (path === "/staff/negotiations") {
            const data = [
                { _id: "m1", negotiationNumber: "NGT-m1", productSnapshot: { name: "Pump" }, wholesalerId: { name: "Dev Kumar", businessInfo: { businessName: "Demo Traders" } }, requestedQuantity: 1, requestedPricePerUnit: 9000, currentPricePerUnit: 9000, status: "converted", orderId: { _id: "order-9", orderNumber: "ORD-2026-9001" }, isExpired: false },
                { _id: "m2", negotiationNumber: "NGT-m2", productSnapshot: { name: "Pipe" }, wholesalerId: { name: "Asha" }, requestedQuantity: 1, requestedPricePerUnit: 100, currentPricePerUnit: 100, status: "pending", orderId: null, isExpired: false },
            ]
            return route.fulfill({ json: { success: true, data, pagination: { page: 1, total: data.length, totalPages: 1 } } })
        }
        return route.fulfill({ json: { success: true, data: [] } })
    })
    return receiptRequests
}

test("admin Deal Desk: Receipt menu downloads, shares and prints the order PDF", async ({ page }) => {
    const requests = await mockApi(page, "admin")
    await page.goto("/negotiations")

    await expect(page.getByRole("columnheader", { name: "Receipt" })).toBeVisible()
    // Only rows with an order get the button: n1, the REQ group row, and its two products.
    await expect(page.getByRole("button", { name: /^Receipt/ })).toHaveCount(4)
    const pendingRow = page.getByRole("row", { name: /NGT-n2/ })
    await expect(pendingRow.getByRole("button", { name: /^Receipt/ })).toHaveCount(0)

    const row = page.getByRole("row", { name: /NGT-n1/ })
    await row.getByRole("button", { name: /^Receipt/ }).click()
    await expect(page.getByRole("menuitem")).toHaveText(["Download PDF", "Share", "Print"])
    await page.screenshot({ path: "test-results/deal-desk-receipt-menu.png" })

    const [download] = await Promise.all([
        page.waitForEvent("download"),
        page.getByRole("menuitem", { name: "Download PDF" }).click(),
    ])
    expect(download.suggestedFilename()).toBe(FILE_NAME)
    expect(requests).toEqual(["/admin/orders/order-1/receipt"])

    // Share hands the PDF file to the device share sheet.
    await page.evaluate(() => {
        const w = window as unknown as { __shared?: string }
        navigator.canShare = () => true
        navigator.share = async (data?: ShareData) => { w.__shared = data?.files?.[0]?.name }
    })
    await row.getByRole("button", { name: /^Receipt/ }).click()
    await page.getByRole("menuitem", { name: "Share" }).click()
    await expect.poll(() => page.evaluate(() => (window as unknown as { __shared?: string }).__shared)).toBe(FILE_NAME)

    // Browsers that can't share files get the PDF downloaded instead.
    await page.evaluate(() => { navigator.canShare = () => false })
    await row.getByRole("button", { name: /^Receipt/ }).click()
    const [shared] = await Promise.all([
        page.waitForEvent("download"),
        page.getByRole("menuitem", { name: "Share" }).click(),
    ])
    expect(shared.suggestedFilename()).toBe(FILE_NAME)
    await expect(page.getByText(/can't share files/)).toBeVisible()

    await row.getByRole("button", { name: /^Receipt/ }).click()
    await page.getByRole("menuitem", { name: "Print" }).click()
    await expect(page.locator('iframe[src^="blob:"]')).toHaveCount(1)
    // The PDF was fetched once and reused.
    expect(requests).toHaveLength(1)

    // The grouped requirement's row shares the combined order's receipt.
    // The menu closes once an action finishes.
    await expect(page.getByRole("menu")).toHaveCount(0)
    await page.getByTestId("requirement-group-row").getByRole("button", { name: /^Receipt/ }).click()
    await page.getByRole("menuitem", { name: "Download PDF" }).click()
    await expect.poll(() => requests.at(-1)).toBe("/admin/orders/order-2/receipt")
})

test("member Deal Desk uses the member receipt endpoint", async ({ page }) => {
    const requests = await mockApi(page, "staff")
    await page.goto("/member/negotiations")
    await expect(page.getByRole("button", { name: /^Receipt/ })).toHaveCount(1)
    await page.getByRole("button", { name: /^Receipt/ }).click()
    const [download] = await Promise.all([
        page.waitForEvent("download"),
        page.getByRole("menuitem", { name: "Download PDF" }).click(),
    ])
    expect(download.suggestedFilename()).toBe(FILE_NAME)
    expect(requests).toEqual(["/staff/orders/order-9/receipt"])
})
