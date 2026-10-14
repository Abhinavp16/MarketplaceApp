import { expect, Page, test } from "@playwright/test"

type Json = Record<string, unknown>

// The Next dev server occasionally serves "Manifest file is empty" while it recompiles on a
// busy machine; a retry gets a clean page. The assertions themselves are deterministic.
test.describe.configure({ retries: 2 })

const xlsxFile = (name = "catalog.xlsx") => ({
  name,
  mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  buffer: Buffer.from("PK-fake-xlsx-bytes"),
})

const baseSummary = {
  totalRows: 3,
  created: 2,
  updated: 1,
  skipped: 0,
  errors: 0,
  warnings: 1,
  errorCount: 0,
  warningCount: 1,
  newBrands: 0,
  newCategories: 0,
}

const okRows = [
  { row: 2, sku: "DM-NEW-001", action: "create", status: "ok", errors: [], warnings: [], normalized: {} },
  {
    row: 3,
    sku: "DM-UPD-002",
    action: "update",
    status: "warning",
    errors: [],
    warnings: [{ field: "wholesalePrice", column: "Wholesale Price", message: "Wholesale price is above the retail price" }],
    changes: [{ field: "retailPrice", column: "Retail Price", from: 1099, to: 1149 }],
    normalized: {},
  },
  { row: 4, sku: "DM-NEW-003", action: "create", status: "ok", errors: [], warnings: [], normalized: {} },
]

function report(overrides: Json = {}): Json {
  return {
    dryRun: true,
    committed: false,
    createMissing: false,
    priceChangeMode: "immediate",
    fileName: "catalog.xlsx",
    summary: baseSummary,
    newBrands: [],
    newCategories: [],
    columns: [],
    ignoredColumns: ["Internal Notes"],
    rows: okRows,
    ...overrides,
  }
}

const errorReport = report({
  summary: { ...baseSummary, totalRows: 3, created: 1, updated: 0, skipped: 0, errors: 2, warnings: 0, errorCount: 2, warningCount: 0, newBrands: 1 },
  newBrands: ["Acme Tools"],
  rows: [
    { row: 2, sku: "DM-OK-001", action: "create", status: "ok", errors: [], warnings: [], normalized: {} },
    {
      row: 3,
      sku: "",
      action: "skip",
      status: "error",
      errors: [{ field: "sku", column: "SKU", message: "SKU is required" }],
      warnings: [],
      normalized: {},
    },
    {
      row: 4,
      sku: "DM-BAD-003",
      action: "create",
      status: "error",
      errors: [{ field: "brand", column: "Brand", message: "Brand not found: Acme Tools" }],
      warnings: [],
      normalized: {},
    },
  ],
})

interface Recorded {
  method: string
  path: string
  search: URLSearchParams
}

async function mockAdminApi(
  page: Page,
  handlers: { importResponse?: (dryRun: boolean) => { status?: number; json: Json } } = {},
) {
  const calls: Recorded[] = []
  let imported = false

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
    calls.push({ method, path: url.pathname, search: url.searchParams })

    if (url.pathname.endsWith("/admin/products/import/template")) {
      return route.fulfill({
        status: 200,
        headers: {
          "content-type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          "content-disposition": 'attachment; filename="catalog-import-template.xlsx"',
          "access-control-expose-headers": "Content-Disposition",
        },
        body: Buffer.from("PK-template"),
      })
    }
    if (url.pathname.endsWith("/admin/products/import") && method === "POST") {
      const dryRun = url.searchParams.get("dryRun") !== "false"
      const response = handlers.importResponse?.(dryRun) ?? { json: { success: true, data: report() } }
      if (!dryRun && (response.status ?? 200) === 200) imported = true
      return route.fulfill({ status: response.status ?? 200, json: response.json })
    }
    if (url.pathname.endsWith("/admin/products") && method === "GET") {
      const data = imported
        ? [
            { _id: "p1", name: "Existing Product", sku: "OLD-1", status: "active", rating: 4 },
            { _id: "p2", name: "Freshly Imported Product", sku: "DM-NEW-001", status: "active", rating: 4 },
          ]
        : [{ _id: "p1", name: "Existing Product", sku: "OLD-1", status: "active", rating: 4 }]
      return route.fulfill({ json: { data, pagination: { page: 1, total: data.length, totalPages: 1 } } })
    }
    return route.fulfill({ json: { data: [] } })
  })

  return calls
}

const isProductList = (c: Recorded) => c.method === "GET" && c.path.endsWith("/admin/products")
const isImport = (c: Recorded) => c.method === "POST" && c.path.endsWith("/admin/products/import")

test("valid file: preview, confirm, success, and the list refreshes", async ({ page }) => {
  const calls = await mockAdminApi(page, {
    importResponse: (dryRun) => ({
      json: {
        success: true,
        data: dryRun
          ? report()
          : report({ dryRun: false, committed: true, rows: okRows.map((r) => ({ ...r, productId: `id-${r.row}` })) }),
      },
    }),
  })
  await page.goto("/products")
  await expect(page.getByText("Existing Product")).toBeVisible()
  const listFetchesBefore = calls.filter(isProductList).length

  await page.getByTestId("import-products-button").click()
  const dialog = page.getByTestId("import-products-dialog")
  await expect(dialog).toBeVisible()
  await expect(page.getByTestId("import-dropzone")).toBeVisible()

  await page.getByTestId("import-file-input").setInputFiles(xlsxFile())

  // Preview call is a dry run with the default options.
  await expect(page.getByTestId("import-preview-banner")).toContainText("Nothing has been saved yet")
  const preview = calls.filter(isImport)
  expect(preview).toHaveLength(1)
  expect(preview[0].search.get("dryRun")).toBe("true")
  expect(preview[0].search.get("createMissing")).toBe("false")
  expect(preview[0].search.get("priceChangeMode")).toBe("immediate")

  await expect(page.getByTestId("import-tile-rows")).toContainText("3")
  await expect(page.getByTestId("import-tile-new")).toContainText("2")
  await expect(page.getByTestId("import-tile-updated")).toContainText("1")
  await expect(page.getByTestId("import-tile-errors")).toContainText("0")
  await expect(page.getByTestId("import-tile-warnings")).toContainText("1")
  await expect(page.getByTestId("import-ignored-columns")).toContainText("Internal Notes")
  await expect(page.getByTestId("import-row-3")).toContainText("DM-UPD-002")

  // Update row: expand to see the before -> after change and the warning.
  await page.getByTestId("import-row-3").getByRole("button", { name: /Show details/ }).click()
  await expect(page.getByTestId("import-row-3-details")).toContainText("Retail Price")
  await expect(page.getByTestId("import-row-3-details")).toContainText("1099")
  await expect(page.getByTestId("import-row-3-details")).toContainText("1149")
  await expect(page.getByTestId("import-row-3-details")).toContainText("Wholesale price is above the retail price")

  const confirm = page.getByTestId("import-confirm")
  await expect(confirm).toBeEnabled()
  await expect(confirm).toHaveText(/Import 3 products/)
  await confirm.click()

  await expect(page.getByTestId("import-result")).toContainText("Import complete")
  await expect(page.getByTestId("import-tile-result-created")).toContainText("2")
  const imports = calls.filter(isImport)
  expect(imports).toHaveLength(2)
  expect(imports[1].search.get("dryRun")).toBe("false")

  await page.getByTestId("import-close-refresh").click()
  await expect(dialog).toBeHidden()
  await expect(page.getByText("Freshly Imported Product")).toBeVisible()
  expect(calls.filter(isProductList).length).toBeGreaterThan(listFetchesBefore)
})

test("file with errors cannot be imported, shows the errors, and filters rows", async ({ page }) => {
  const calls = await mockAdminApi(page, { importResponse: () => ({ json: { success: true, data: errorReport } }) })
  await page.goto("/products")
  await page.getByTestId("import-products-button").click()
  await page.getByTestId("import-file-input").setInputFiles({ name: "bad.csv", mimeType: "text/csv", buffer: Buffer.from("SKU,Name\n,x\n") })

  await expect(page.getByTestId("import-tile-errors")).toContainText("2")
  await expect(page.getByTestId("import-confirm")).toBeDisabled()
  await expect(page.getByTestId("import-footer-note")).toContainText("Fix the 2 errors in your file and upload it again")
  // Unknown brand with "create missing" off: hint to tick the option.
  await expect(page.getByTestId("import-footer-note")).toContainText("Create missing brands and categories")

  // Error rows are expanded by default with column names.
  await expect(page.getByTestId("import-row-3-details")).toContainText("SKU: SKU is required")
  await expect(page.getByTestId("import-row-4-details")).toContainText("Brand: Brand not found: Acme Tools")

  await page.getByTestId("import-filter-errors").click()
  await expect(page.getByTestId("import-row-3")).toBeVisible()
  await expect(page.getByTestId("import-row-4")).toBeVisible()
  await expect(page.getByTestId("import-row-2")).toHaveCount(0)

  await page.getByTestId("import-filter-all").click()
  await page.getByTestId("import-search").fill("ok-001")
  await expect(page.getByTestId("import-row-2")).toBeVisible()
  await expect(page.getByTestId("import-row-4")).toHaveCount(0)

  // Re-check with "create missing" ticked sends that option.
  await page.getByTestId("import-search").fill("")
  await page.getByRole("button", { name: "Tick it and check again" }).click()
  await expect.poll(() => calls.filter(isImport).length).toBe(2)
  expect(calls.filter(isImport)[1].search.get("createMissing")).toBe("true")
  // Nothing was ever committed.
  expect(calls.filter(isImport).every((c) => c.search.get("dryRun") === "true")).toBe(true)
})

test("request errors from the server are shown clearly", async ({ page }) => {
  await mockAdminApi(page, {
    importResponse: () => ({
      status: 400,
      json: { success: false, message: "Only .xlsx and .csv files are accepted", error: { code: "INVALID_FILE_TYPE", message: "Only .xlsx and .csv files are accepted" } },
    }),
  })
  await page.goto("/products")
  await page.getByTestId("import-products-button").click()
  await page.getByTestId("import-file-input").setInputFiles(xlsxFile("weird.xlsx"))

  await expect(page.getByTestId("import-error")).toContainText("Only .xlsx and .csv files are accepted")
  // Still on the upload step, so the admin can pick another file.
  await expect(page.getByTestId("import-dropzone")).toBeVisible()
  await expect(page.getByTestId("import-confirm")).toHaveCount(0)
})

test("unsupported file types are refused before anything is uploaded", async ({ page }) => {
  const calls = await mockAdminApi(page)
  await page.goto("/products")
  await page.getByTestId("import-products-button").click()
  await page.getByTestId("import-file-input").setInputFiles({ name: "notes.txt", mimeType: "text/plain", buffer: Buffer.from("hello") })

  await expect(page.getByTestId("import-error")).toContainText("Upload an .xlsx or .csv file")
  expect(calls.filter(isImport)).toHaveLength(0)
})

test("template download calls the template endpoint", async ({ page }) => {
  const calls = await mockAdminApi(page)
  await page.goto("/products")

  const downloadPromise = page.waitForEvent("download")
  await page.getByTestId("import-template-button").click()
  const download = await downloadPromise
  expect(download.suggestedFilename()).toBe("catalog-import-template.xlsx")
  expect(calls.some((c) => c.method === "GET" && c.path.endsWith("/admin/products/import/template"))).toBe(true)

  // The same link inside the dialog.
  await page.getByTestId("import-products-button").click()
  const second = page.waitForEvent("download")
  await page.getByTestId("import-template-link").click()
  expect((await second).suggestedFilename()).toBe("catalog-import-template.xlsx")
})

test("the schedule option is sent and the result mentions scheduled prices", async ({ page }) => {
  const calls = await mockAdminApi(page, {
    importResponse: (dryRun) => ({
      json: { success: true, data: report({ priceChangeMode: "schedule_24h", dryRun, committed: !dryRun }) },
    }),
  })
  await page.goto("/products")
  await page.getByTestId("import-products-button").click()
  await page.getByRole("button", { name: "Advanced" }).click()
  await page.getByLabel("When price changes take effect").selectOption("schedule_24h")
  await page.getByLabel("Create missing brands and categories").click()
  await page.getByTestId("import-file-input").setInputFiles(xlsxFile())

  await expect(page.getByTestId("import-confirm")).toBeEnabled()
  const preview = calls.filter(isImport)[0]
  expect(preview.search.get("priceChangeMode")).toBe("schedule_24h")
  expect(preview.search.get("createMissing")).toBe("true")

  await page.getByTestId("import-confirm").click()
  await expect(page.getByTestId("import-scheduled-note")).toContainText("24 hours")
  const commit = calls.filter(isImport)[1]
  expect(commit.search.get("dryRun")).toBe("false")
  expect(commit.search.get("priceChangeMode")).toBe("schedule_24h")
  expect(commit.search.get("createMissing")).toBe("true")
})
