import { expect, Page, test } from "@playwright/test"

const IMG = "https://example.invalid/banner.webp"
const banner = (title: string, order: number, extra: Record<string, unknown> = {}) => ({
    _id: `id-${title}`, title, subtitle: "", tag: "", imageUrl: IMG, mediaType: "image", videoUrl: "",
    linkUrl: "", buttonText: "Shop Now", buttonIcon: "ArrowRight", isActive: true, order, ...extra,
})

async function mockApi(page: Page) {
    const saves: Record<string, unknown>[] = []
    await page.addInitScript(() => {
        localStorage.setItem("accessToken", "test-token")
        localStorage.setItem("user", JSON.stringify({ _id: "admin-1", name: "Admin", role: "admin" }))
        localStorage.setItem("loginAt", String(Date.now()))
    })
    await page.route("**/socket.io/**", (route) => route.abort())
    await page.route("**/*.webp", (route) => route.fulfill({ status: 200, contentType: "image/svg+xml", body: "<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10'/>" }))
    await page.route("**/api/v1/**", async (route) => {
        const request = route.request()
        const path = new URL(request.url()).pathname
        if (path.endsWith("/auth/me")) return route.fulfill({ json: { data: { role: "admin" } } })
        if (path.endsWith("/admin/settings")) {
            if (request.method() === "PUT") {
                saves.push(request.postDataJSON())
                return route.fulfill({ json: { success: true } })
            }
            // Stored out of order on purpose: the page shows them by saved order.
            return route.fulfill({ json: { success: true, data: { heroBanners: [banner("Third", 2), banner("First", 0), banner("Second", 1)], promoBanners: [] } } })
        }
        return route.fulfill({ json: { success: true, data: [] } })
    })
    return saves
}

const titles = (page: Page) => page.getByTestId("banner-card").locator('input[placeholder="e.g. Summer Sale"]').evaluateAll((inputs) => inputs.map((input) => (input as HTMLInputElement).value))

test("admin reorders hero banners with the arrows and by dragging, then saves the order", async ({ page }) => {
    const saves = await mockApi(page)
    await page.goto("/banners")
    await expect(page.getByTestId("banner-card")).toHaveCount(3)
    await expect.poll(() => titles(page)).toEqual(["First", "Second", "Third"])
    await expect(page.getByRole("button", { name: "Move banner 1 up" })).toBeDisabled()
    await expect(page.getByRole("button", { name: "Move banner 3 down" })).toBeDisabled()

    await page.getByRole("button", { name: "Move banner 3 up" }).click()
    await expect.poll(() => titles(page)).toEqual(["First", "Third", "Second"])
    await expect(page.getByText("Order changed. Save to show this order in the app.")).toBeVisible()

    // Drag the first banner to the end (keyboard drag: Space, arrows, Space).
    const handle = page.getByRole("button", { name: "Drag to reorder" }).first()
    await handle.focus()
    for (const key of ["Space", "ArrowDown", "ArrowDown", "Space"]) {
        await page.keyboard.press(key)
        await page.waitForTimeout(300) // let the drag animation settle
    }
    await expect.poll(() => titles(page)).toEqual(["Third", "Second", "First"])
    await page.screenshot({ path: "test-results/banner-reorder.png", fullPage: true })

    await page.getByRole("button", { name: "Save Hero Banners" }).click()
    await expect.poll(() => saves.length).toBe(1)
    const saved = (saves[0].heroBanners as { title: string; order: number; key?: string }[])
    expect(saved.map((b) => [b.title, b.order])).toEqual([["Third", 0], ["Second", 1], ["First", 2]])
    expect(saved.every((b) => !("key" in b))).toBe(true)
    await expect(page.getByText("Order changed.")).toHaveCount(0)
})
