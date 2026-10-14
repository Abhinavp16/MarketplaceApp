import { expect, Page, test } from "@playwright/test"

const group = { id: "grp-1", number: "REQ-2026-81581241" }
const dealer = { id: "u-dealer", name: "Dev Kumar", email: "dev@example.invalid", phone: "9000000061" }

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
    const writes: { path: string; body: Record<string, unknown> }[] = []
    await page.addInitScript((r) => {
        localStorage.setItem("accessToken", "test-token")
        localStorage.setItem("user", JSON.stringify({ _id: "u-1", name: "Asha", role: r }))
        localStorage.setItem("loginAt", String(Date.now()))
        if (r === "staff") localStorage.setItem("sessionExpiresAt", new Date(Date.now() + 60 * 60_000).toISOString())
    }, role)
    await page.route("**/socket.io/**", (route) => route.abort())
    await page.route("**/api/v1/**", async (route) => {
        const request = route.request()
        const path = new URL(request.url()).pathname.replace(/^.*\/api\/v1/, "")
        if (path === "/auth/me") return route.fulfill({ json: { data: { role } } })
        if (request.method() === "DELETE") {
            writes.push({ path, body: {} })
            const all = path.endsWith("/declined")
            return route.fulfill({ json: { success: true, message: all ? "Cleared 1 declined requirement" : "Declined requirement deleted", data: { deleted: 1 } } })
        }
        if (request.method() === "PUT") {
            writes.push({ path, body: (request.postDataJSON() || {}) as Record<string, unknown> })
            const isGroup = path.includes("/groups/")
            return route.fulfill({ json: { success: true, message: isGroup ? `Requirement ${group.number} declined (2 products)` : "Requirement declined" } })
        }
        if (path === `/admin/negotiations/groups/${group.id}`) {
            const items = ["g1", "g2"].map((id) => ({
                id, negotiationNumber: `NGT-${id}`, product: { name: `Product ${id}`, priceUnit: "Piece", packing: "1" },
                requestedQuantity: 2, pricePerUnit: 100, totalPrice: 200, status: "pending", isExpired: false, order: null, canAccept: true,
            }))
            return route.fulfill({ json: { success: true, data: { requestGroup: group, wholesaler: dealer, lastOrderAddress: null, items } } })
        }
        if (path === "/admin/negotiations") {
            const data = [
                listItem("g1", { requestGroup: group }),
                listItem("g2", { requestGroup: group }),
                listItem("s1"),
                listItem("s2", { status: "countered" }),
                listItem("done", { status: "converted", orderId: "order-1" }),
                listItem("no", { status: "rejected" }),
            ]
            return route.fulfill({ json: { success: true, data, pagination: { page: 1, total: data.length, totalPages: 1 } } })
        }
        if (path === "/staff/negotiations") {
            const data = [
                { _id: "m1", negotiationNumber: "NGT-m1", productSnapshot: { name: "Pump" }, wholesalerId: { name: "Dev Kumar" }, requestedQuantity: 1, requestedPricePerUnit: 9000, currentPricePerUnit: 9000, status: "pending", orderId: null, isExpired: false },
                { _id: "m2", negotiationNumber: "NGT-m2", productSnapshot: { name: "Pipe" }, wholesalerId: { name: "Asha" }, requestedQuantity: 1, requestedPricePerUnit: 100, currentPricePerUnit: 100, status: "converted", orderId: "order-2", isExpired: false },
            ]
            return route.fulfill({ json: { success: true, data, pagination: { page: 1, total: data.length, totalPages: 1 } } })
        }
        return route.fulfill({ json: { success: true, data: [] } })
    })
    return writes
}

test("admin declines a whole cart requirement from its row, with a reason", async ({ page }) => {
    const writes = await mockApi(page, "admin")
    await page.goto("/negotiations")

    const groupRow = page.getByTestId("requirement-group-row")
    await expect(groupRow).toContainText("2 awaiting review")
    // The row's Review action opens the products; accept or decline from the panel.
    await groupRow.getByRole("button", { name: /Open requirement/ }).click()
    const panel = page.getByTestId("requirement-group-panel")
    await expect(panel.getByTestId("group-panel-item")).toHaveCount(2)
    await expect(panel.getByRole("button", { name: "Accept & Create Order" })).toBeVisible()
    await panel.getByRole("button", { name: "Decline requirement" }).click()

    const dialog = page.getByTestId("decline-requirement-dialog")
    await expect(dialog).toContainText(group.number)
    await expect(dialog).toContainText("2 open products")
    await dialog.getByLabel("Reason for declining").fill("Price changed")
    await page.screenshot({ path: "test-results/deal-desk-decline-group.png" })
    await dialog.getByRole("button", { name: "Decline requirement" }).click()

    await expect.poll(() => writes[0]).toEqual({ path: `/admin/negotiations/groups/${group.id}/reject`, body: { reason: "Price changed" } })
    await expect(page.getByText(`Requirement ${group.number} declined (2 products)`)).toBeVisible()
})

test("admin declines a single open requirement; finished ones have no Decline", async ({ page }) => {
    const writes = await mockApi(page, "admin")
    await page.goto("/negotiations")

    // Only the two open single requirements get the row button (grouped ones decline via the group row).
    await expect(page.getByRole("button", { name: /^Decline NGT-/ })).toHaveCount(2)
    await expect(page.getByRole("button", { name: "Decline NGT-done" })).toHaveCount(0)
    await expect(page.getByRole("button", { name: "Decline NGT-no" })).toHaveCount(0)
    await expect(page.getByRole("button", { name: "Decline NGT-g1" })).toHaveCount(0)

    await page.getByRole("button", { name: "Decline NGT-s2" }).click()
    const dialog = page.getByTestId("decline-requirement-dialog")
    await dialog.getByRole("button", { name: "Decline", exact: true }).click()
    await expect.poll(() => writes[0]).toEqual({ path: "/admin/negotiations/s2/reject", body: {} })
})

test("members can decline through the member endpoint", async ({ page }) => {
    const writes = await mockApi(page, "staff")
    await page.goto("/member/negotiations")
    await expect(page.getByRole("button", { name: /^Decline NGT-/ })).toHaveCount(1)
    await page.getByRole("button", { name: "Decline NGT-m1" }).click()
    const dialog = page.getByTestId("decline-requirement-dialog")
    await dialog.getByLabel("Reason for declining").fill("Out of stock")
    await dialog.getByRole("button", { name: "Decline", exact: true }).click()
    await expect.poll(() => writes[0]).toEqual({ path: "/staff/negotiations/m1/reject", body: { reason: "Out of stock" } })
})

test("admin deletes one declined requirement, or clears all declined", async ({ page }) => {
    const writes = await mockApi(page, "admin")
    await page.goto("/negotiations")
    await expect(page.getByText("removed automatically 5 days after")).toBeVisible()

    // Only declined rows can be deleted.
    await expect(page.getByRole("button", { name: /^Delete NGT-/ })).toHaveCount(1)
    await page.getByRole("button", { name: "Delete NGT-no" }).click()
    await expect(page.getByRole("alertdialog")).toContainText("Delete NGT-no?")
    await page.getByRole("button", { name: "Delete", exact: true }).click()
    await expect.poll(() => writes.at(-1)?.path).toBe("/admin/negotiations/no")
    await expect(page.getByText("Declined requirement deleted")).toBeVisible()

    await page.getByRole("button", { name: "Clear declined" }).click()
    await expect(page.getByRole("alertdialog")).toContainText("Clear all declined requirements?")
    await page.getByRole("alertdialog").getByRole("button", { name: "Clear declined" }).click()
    await expect.poll(() => writes.at(-1)?.path).toBe("/admin/negotiations/declined")
})
