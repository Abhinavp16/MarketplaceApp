"use client"

import { useCallback, useId, useMemo, useRef, useState } from "react"
import { toast } from "sonner"
import {
  AlertTriangle,
  ArrowRight,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Download,
  Loader2,
  Search,
  Upload,
  XCircle,
} from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  CatalogImportError,
  IMPORT_ACCEPT,
  IMPORT_MAX_BYTES,
  downloadImportTemplate,
  formatChangeValue,
  isSupportedImportFile,
  uploadCatalogFile,
  type ImportReport,
  type ImportRow,
  type PriceChangeMode,
} from "@/lib/catalog-import"

type Step = "upload" | "review" | "result"
type Filter = "all" | "errors" | "warnings" | "changes"

const PAGE_SIZE = 100

function formatSize(bytes: number) {
  return bytes >= 1024 * 1024 ? `${(bytes / (1024 * 1024)).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`
}

function plural(count: number, one: string, many = `${one}s`) {
  return `${count.toLocaleString()} ${count === 1 ? one : many}`
}

function ActionBadge({ action }: { action: ImportRow["action"] }) {
  if (action === "create") return <Badge className="border-transparent bg-emerald-100 text-emerald-800">Create</Badge>
  if (action === "update") return <Badge className="border-transparent bg-indigo-100 text-indigo-800">Update</Badge>
  return <Badge className="border-transparent bg-slate-100 text-slate-600">Unchanged</Badge>
}

function StatusBadge({ status }: { status: ImportRow["status"] }) {
  if (status === "error") return <Badge className="border-transparent bg-red-100 text-red-800">Error</Badge>
  if (status === "warning") return <Badge className="border-transparent bg-amber-100 text-amber-800">Warning</Badge>
  return <Badge className="border-transparent bg-slate-100 text-slate-600">OK</Badge>
}

function Tile({ id, label, value, tone }: { id: string; label: string; value: number; tone?: "red" | "amber" | "indigo" | "green" }) {
  const toneClass =
    tone === "red" && value > 0
      ? "border-red-200 bg-red-50 text-red-800"
      : tone === "amber" && value > 0
        ? "border-amber-200 bg-amber-50 text-amber-800"
        : tone === "indigo"
          ? "border-indigo-200 bg-indigo-50 text-indigo-800"
          : tone === "green"
            ? "border-emerald-200 bg-emerald-50 text-emerald-800"
            : "border-[#d0d1e3] bg-white text-slate-900"
  return (
    <div data-testid={`import-tile-${id}`} className={`rounded-xl border px-3 py-2 ${toneClass}`}>
      <p className="text-xs font-medium opacity-80">{label}</p>
      <p className="text-xl font-semibold tabular-nums">{value.toLocaleString()}</p>
    </div>
  )
}

export function ImportProductsDialog({
  open,
  onOpenChange,
  onImported,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  onImported: () => void
}) {
  const [step, setStep] = useState<Step>("upload")
  const [file, setFile] = useState<File | null>(null)
  const [createMissing, setCreateMissing] = useState(false)
  const [priceMode, setPriceMode] = useState<PriceChangeMode>("immediate")
  const [advancedOpen, setAdvancedOpen] = useState(false)
  const [busy, setBusy] = useState<"preview" | "commit" | null>(null)
  const [report, setReport] = useState<ImportReport | null>(null)
  // Options the preview was made with; the confirm call must repeat them exactly.
  const [usedOpts, setUsedOpts] = useState<{ createMissing: boolean; priceMode: PriceChangeMode }>({ createMissing: false, priceMode: "immediate" })
  const [error, setError] = useState<string | null>(null)
  const [dragActive, setDragActive] = useState(false)
  const [filter, setFilter] = useState<Filter>("all")
  const [query, setQuery] = useState("")
  const [toggled, setToggled] = useState<Set<number>>(new Set())
  const [visible, setVisible] = useState(PAGE_SIZE)
  const [downloading, setDownloading] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const submitting = useRef(false)
  const ids = useId()

  const reset = useCallback(() => {
    setStep("upload")
    setFile(null)
    setCreateMissing(false)
    setPriceMode("immediate")
    setAdvancedOpen(false)
    setBusy(null)
    setReport(null)
    setError(null)
    setDragActive(false)
    setFilter("all")
    setQuery("")
    setToggled(new Set())
    setVisible(PAGE_SIZE)
    submitting.current = false
  }, [])

  function handleOpenChange(next: boolean) {
    if (!next && busy === "commit") return
    if (!next && step === "result" && report?.committed) onImported()
    if (!next) reset()
    onOpenChange(next)
  }

  async function runPreview(target: File, opts: { createMissing: boolean; priceMode: PriceChangeMode }) {
    if (submitting.current) return
    submitting.current = true
    setBusy("preview")
    setError(null)
    try {
      const result = await uploadCatalogFile(target, {
        dryRun: true,
        createMissing: opts.createMissing,
        priceChangeMode: opts.priceMode,
      })
      setReport(result)
      setUsedOpts(opts)
      setFilter("all")
      setQuery("")
      setToggled(new Set())
      setVisible(PAGE_SIZE)
      setStep("review")
    } catch (err) {
      const message = err instanceof CatalogImportError ? err.message : "Could not check the file. Try again."
      setError(message)
      toast.error(message)
    } finally {
      submitting.current = false
      setBusy(null)
    }
  }

  function chooseFile(candidate: File | null | undefined) {
    if (!candidate || busy) return
    if (!isSupportedImportFile(candidate)) {
      const message = "That file type is not supported. Upload an .xlsx or .csv file."
      setFile(null)
      setError(message)
      toast.error(message)
      return
    }
    if (candidate.size > IMPORT_MAX_BYTES) {
      const message = `That file is ${formatSize(candidate.size)}. The limit is 5 MB, so split it into smaller files.`
      setFile(null)
      setError(message)
      toast.error(message)
      return
    }
    setFile(candidate)
    void runPreview(candidate, { createMissing, priceMode })
  }

  async function confirmImport() {
    if (!file || !report || submitting.current) return
    submitting.current = true
    setBusy("commit")
    setError(null)
    try {
      const result = await uploadCatalogFile(file, {
        dryRun: false,
        createMissing: usedOpts.createMissing,
        priceChangeMode: usedOpts.priceMode,
      })
      if (!result.committed) {
        // The file now has problems (for example the catalog changed meanwhile): show them, save nothing.
        setReport(result)
        setToggled(new Set())
        const message = "Nothing was imported. The file has errors. Fix them and upload it again."
        setError(message)
        toast.error(message)
        return
      }
      setReport(result)
      setStep("result")
      toast.success(`Imported ${plural(result.summary.created + result.summary.updated, "product")}`)
    } catch (err) {
      const message = err instanceof CatalogImportError ? err.message : "The import failed. Nothing was saved. Try again."
      setError(message)
      toast.error(message)
    } finally {
      submitting.current = false
      setBusy(null)
    }
  }

  async function handleTemplate() {
    setDownloading(true)
    try {
      await downloadImportTemplate()
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Could not download the template")
    } finally {
      setDownloading(false)
    }
  }

  const rows = useMemo(() => report?.rows ?? [], [report])
  const counts = useMemo(
    () => ({
      errors: rows.filter((r) => r.status === "error").length,
      warnings: rows.filter((r) => r.status === "warning" || r.warnings.length > 0).length,
      changes: rows.filter((r) => r.action !== "skip").length,
    }),
    [rows],
  )

  const filteredRows = useMemo(() => {
    const needle = query.trim().toLowerCase()
    return rows.filter((r) => {
      if (filter === "errors" && r.status !== "error") return false
      if (filter === "warnings" && !(r.status === "warning" || r.warnings.length > 0)) return false
      if (filter === "changes" && r.action === "skip") return false
      if (needle && !String(r.sku || "").toLowerCase().includes(needle)) return false
      return true
    })
  }, [rows, filter, query])

  const summary = report?.summary
  const errorRows = summary ? Math.max(summary.errors, counts.errors) : 0
  const importCount = summary ? summary.created + summary.updated : 0
  const missingHint =
    report &&
    !usedOpts.createMissing &&
    report.rows.some((r) =>
      r.errors.some((e) => /brand|categor/i.test(`${e.field || ""} ${e.column || ""}`) && /not found|unknown|does not exist|no such|missing/i.test(e.message)),
    )

  const filters: { id: Filter; label: string; count?: number }[] = [
    { id: "all", label: "All", count: rows.length },
    { id: "errors", label: "Errors", count: counts.errors },
    { id: "warnings", label: "Warnings", count: counts.warnings },
    { id: "changes", label: "Changes", count: counts.changes },
  ]

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent
        data-testid="import-products-dialog"
        className="flex max-h-[92vh] flex-col gap-0 overflow-hidden p-0 sm:max-w-5xl"
        onInteractOutside={(e) => e.preventDefault()}
      >
        <DialogHeader className="border-b border-[#e2e2f0] px-6 py-4 pr-12">
          <DialogTitle className="text-xl text-slate-900">Import products</DialogTitle>
          <DialogDescription>
            {step === "upload" && "Step 1 of 3. Upload a spreadsheet to add or update products in bulk."}
            {step === "review" && "Step 2 of 3. Review what will change. Nothing is saved yet."}
            {step === "result" && "Step 3 of 3. Import finished."}
          </DialogDescription>
        </DialogHeader>

        <div className="min-h-0 flex-1 overflow-y-auto px-6 py-4">
          {error && step !== "result" ? (
            <div
              role="alert"
              data-testid="import-error"
              className="mb-4 flex items-start gap-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800"
            >
              <XCircle className="mt-0.5 h-4 w-4 shrink-0" />
              <p>{error}</p>
            </div>
          ) : null}

          {step === "upload" && (
            <div className="space-y-5">
              <div
                data-testid="import-dropzone"
                data-active={dragActive}
                onDragOver={(e) => {
                  e.preventDefault()
                  setDragActive(true)
                }}
                onDragLeave={() => setDragActive(false)}
                onDrop={(e) => {
                  e.preventDefault()
                  setDragActive(false)
                  chooseFile(e.dataTransfer.files?.[0])
                }}
                className={`flex flex-col items-center justify-center gap-3 rounded-2xl border-2 border-dashed px-6 py-10 text-center transition-colors ${
                  dragActive ? "border-indigo-500 bg-indigo-50" : "border-[#cacbdf] bg-[#f8f8fd]"
                }`}
              >
                {busy === "preview" ? (
                  <>
                    <Loader2 className="h-8 w-8 animate-spin text-indigo-500" />
                    <p className="text-sm font-medium text-slate-700" data-testid="import-checking">
                      Checking {file?.name ?? "file"}…
                    </p>
                  </>
                ) : (
                  <>
                    <Upload className="h-8 w-8 text-indigo-500" />
                    <p className="text-sm font-medium text-slate-800">Drag a file here, or choose one</p>
                    <p className="text-xs text-slate-500">.xlsx or .csv, up to 5 MB and 5,000 rows</p>
                    <input
                      ref={inputRef}
                      id={`${ids}-file`}
                      data-testid="import-file-input"
                      type="file"
                      accept={IMPORT_ACCEPT}
                      className="sr-only"
                      aria-label="Catalog file (.xlsx or .csv)"
                      onChange={(e) => {
                        chooseFile(e.target.files?.[0])
                        e.target.value = ""
                      }}
                    />
                    <Button type="button" variant="outline" className="border-indigo-300 bg-white text-indigo-700 hover:bg-indigo-50" onClick={() => inputRef.current?.click()}>
                      Choose file
                    </Button>
                    {file ? (
                      <div className="flex flex-wrap items-center justify-center gap-2 text-sm text-slate-700">
                        <span data-testid="import-selected-file">
                          Selected: <strong>{file.name}</strong> ({formatSize(file.size)})
                        </span>
                        <Button type="button" size="sm" className="bg-indigo-600 text-white hover:bg-indigo-700" onClick={() => runPreview(file, { createMissing, priceMode })}>
                          Check file again
                        </Button>
                      </div>
                    ) : null}
                  </>
                )}
              </div>

              <div className="flex items-start gap-3 rounded-xl border border-[#d0d1e3] bg-white p-4">
                <Checkbox
                  id={`${ids}-create-missing`}
                  data-testid="import-create-missing"
                  checked={createMissing}
                  disabled={busy !== null}
                  onCheckedChange={(v) => setCreateMissing(v === true)}
                  className="mt-0.5"
                />
                <div className="space-y-1">
                  <Label htmlFor={`${ids}-create-missing`} className="text-sm font-medium text-slate-900">
                    Create missing brands and categories
                  </Label>
                  <p className="text-xs text-slate-500">
                    Off: a row naming a brand or category that does not exist is an error. On: they are created when you import.
                  </p>
                </div>
              </div>

              <div className="rounded-xl border border-[#d0d1e3] bg-white">
                <button
                  type="button"
                  aria-expanded={advancedOpen}
                  aria-controls={`${ids}-advanced`}
                  onClick={() => setAdvancedOpen((v) => !v)}
                  className="flex w-full items-center gap-2 px-4 py-3 text-left text-sm font-medium text-slate-800"
                >
                  {advancedOpen ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
                  Advanced
                </button>
                {advancedOpen ? (
                  <div id={`${ids}-advanced`} className="space-y-1 border-t border-[#e2e2f0] px-4 py-3">
                    <Label htmlFor={`${ids}-price-mode`} className="text-sm font-medium text-slate-900">
                      When price changes take effect
                    </Label>
                    <select
                      id={`${ids}-price-mode`}
                      data-testid="import-price-mode"
                      value={priceMode}
                      disabled={busy !== null}
                      onChange={(e) => setPriceMode(e.target.value as PriceChangeMode)}
                      className="h-9 w-full rounded-md border border-[#cacbdf] bg-white px-3 text-sm text-slate-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400 sm:max-w-xs"
                    >
                      <option value="immediate">Apply immediately</option>
                      <option value="schedule_24h">Schedule in 24 hours</option>
                    </select>
                    <p className="text-xs text-slate-500">Only matters for rows that change the price of an existing product.</p>
                  </div>
                ) : null}
              </div>

              <button
                type="button"
                data-testid="import-template-link"
                onClick={handleTemplate}
                disabled={downloading}
                className="inline-flex items-center gap-2 text-sm font-medium text-indigo-700 underline-offset-2 hover:underline disabled:opacity-60"
              >
                {downloading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
                Download template
              </button>
            </div>
          )}

          {step === "review" && report && summary && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-6">
                <Tile id="rows" label="Rows" value={summary.totalRows} />
                <Tile id="new" label="New" value={summary.created} tone="green" />
                <Tile id="updated" label="Updated" value={summary.updated} tone="indigo" />
                <Tile id="unchanged" label="Unchanged" value={summary.skipped} />
                <Tile id="errors" label="Errors" value={errorRows} tone="red" />
                <Tile id="warnings" label="Warnings" value={summary.warnings} tone="amber" />
              </div>

              <div className="flex items-start gap-2 rounded-lg border border-indigo-200 bg-indigo-50 px-3 py-2 text-sm text-indigo-900" data-testid="import-preview-banner">
                <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
                <p>
                  This is a preview. <strong>Nothing has been saved yet.</strong> Review the rows below, then confirm to import.
                </p>
              </div>

              {report.newBrands.length > 0 || report.newCategories.length > 0 ? (
                <div className="rounded-lg border border-[#d0d1e3] bg-white px-3 py-2 text-sm" data-testid="import-new-items">
                  <p className="font-medium text-slate-900">Will be created on import</p>
                  {report.newBrands.length > 0 ? (
                    <p className="text-slate-700">
                      <span className="font-medium">Brands ({report.newBrands.length}):</span> {report.newBrands.join(", ")}
                    </p>
                  ) : null}
                  {report.newCategories.length > 0 ? (
                    <div className="text-slate-700">
                      <span className="font-medium">Categories ({report.newCategories.length}):</span>
                      <ul className="ml-5 list-disc">
                        {report.newCategories.map((c) => (
                          <li key={c}>{c}</li>
                        ))}
                      </ul>
                    </div>
                  ) : null}
                </div>
              ) : null}

              {report.ignoredColumns.length > 0 ? (
                <p className="text-xs text-slate-500" data-testid="import-ignored-columns">
                  Ignored columns (not part of the catalog): {report.ignoredColumns.join(", ")}
                </p>
              ) : null}

              <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex flex-wrap gap-2" role="group" aria-label="Filter rows">
                  {filters.map((f) => (
                    <button
                      key={f.id}
                      type="button"
                      data-testid={`import-filter-${f.id}`}
                      aria-pressed={filter === f.id}
                      onClick={() => {
                        setFilter(f.id)
                        setVisible(PAGE_SIZE)
                      }}
                      className={`rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                        filter === f.id ? "border-indigo-600 bg-indigo-600 text-white" : "border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8]"
                      }`}
                    >
                      {f.label} ({f.count})
                    </button>
                  ))}
                </div>
                <div className="relative w-full sm:max-w-xs">
                  <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                  <Input
                    aria-label="Search rows by SKU"
                    data-testid="import-search"
                    placeholder="Search by SKU"
                    value={query}
                    onChange={(e) => {
                      setQuery(e.target.value)
                      setVisible(PAGE_SIZE)
                    }}
                    className="h-9 border-[#cacbdf] bg-white pl-9"
                  />
                </div>
              </div>

              <div className="overflow-x-auto rounded-xl border border-[#d0d1e3] bg-white">
                <table className="w-full text-sm" data-testid="import-rows-table">
                  <thead>
                    <tr className="border-b border-[#e2e2f0] bg-[#f3f3fa] text-left text-xs text-slate-500">
                      <th className="w-14 px-3 py-2 font-medium">Row</th>
                      <th className="px-3 py-2 font-medium">SKU</th>
                      <th className="px-3 py-2 font-medium">Action</th>
                      <th className="px-3 py-2 font-medium">Status</th>
                      <th className="px-3 py-2 font-medium">Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredRows.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-3 py-6 text-center text-slate-500" data-testid="import-no-rows">
                          No rows match.
                        </td>
                      </tr>
                    ) : null}
                    {filteredRows.slice(0, visible).map((r) => {
                      const hasDetails = r.errors.length > 0 || r.warnings.length > 0 || (r.changes?.length ?? 0) > 0 || !!r.note
                      const isOpen = hasDetails && (r.status === "error") !== toggled.has(r.row)
                      const detailsId = `${ids}-row-${r.row}`
                      return (
                        <RowItem
                          key={r.row}
                          r={r}
                          hasDetails={hasDetails}
                          isOpen={isOpen}
                          detailsId={detailsId}
                          onToggle={() =>
                            setToggled((prev) => {
                              const next = new Set(prev)
                              if (next.has(r.row)) next.delete(r.row)
                              else next.add(r.row)
                              return next
                            })
                          }
                        />
                      )
                    })}
                  </tbody>
                </table>
              </div>
              {filteredRows.length > visible ? (
                <div className="text-center">
                  <Button type="button" variant="outline" size="sm" onClick={() => setVisible((v) => v + PAGE_SIZE)}>
                    Show more ({(filteredRows.length - visible).toLocaleString()} more rows)
                  </Button>
                </div>
              ) : null}
            </div>
          )}

          {step === "result" && report && summary && (
            <div className="space-y-4" data-testid="import-result">
              <div className="flex items-center gap-3 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-emerald-900">
                <CheckCircle2 className="h-6 w-6 shrink-0" />
                <div>
                  <p className="font-semibold">Import complete</p>
                  <p className="text-sm">
                    {plural(summary.created + summary.updated, "product")} saved from {report.fileName || file?.name}.
                  </p>
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2">
                <Tile id="result-created" label="Created" value={summary.created} tone="green" />
                <Tile id="result-updated" label="Updated" value={summary.updated} tone="indigo" />
                <Tile id="result-skipped" label="Unchanged (skipped)" value={summary.skipped} />
              </div>
              {summary.newBrands > 0 || summary.newCategories > 0 ? (
                <p className="text-sm text-slate-700">
                  Also created {plural(summary.newBrands, "brand")} and {plural(summary.newCategories, "category", "categories")}.
                </p>
              ) : null}
              {usedOpts.priceMode === "schedule_24h" && summary.updated > 0 ? (
                <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900" data-testid="import-scheduled-note">
                  Price changes on updated products are scheduled and will go live in 24 hours. Other changes are already live.
                </p>
              ) : null}
            </div>
          )}
        </div>

        <DialogFooter className="items-center border-t border-[#e2e2f0] bg-white px-6 py-3 sm:justify-between">
          {step === "upload" && (
            <>
              <p className="text-xs text-slate-500">Your file is checked first. Nothing is saved until you confirm.</p>
              <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
                Cancel
              </Button>
            </>
          )}

          {step === "review" && summary && (
            <>
              <div className="text-sm" data-testid="import-footer-note">
                {errorRows > 0 ? (
                  <div className="text-red-700">
                    <p className="font-medium">Fix the {errorRows.toLocaleString()} {errorRows === 1 ? "error" : "errors"} in your file and upload it again.</p>
                    {missingHint ? (
                      <p className="text-xs">
                        Some errors are unknown brands or categories. Tick &quot;Create missing brands and categories&quot; to create them.{" "}
                        <button
                          type="button"
                          className="font-medium underline"
                          disabled={busy !== null}
                          onClick={() => {
                            setCreateMissing(true)
                            if (file) void runPreview(file, { createMissing: true, priceMode: usedOpts.priceMode })
                          }}
                        >
                          Tick it and check again
                        </button>
                      </p>
                    ) : null}
                  </div>
                ) : importCount === 0 ? (
                  <p className="text-slate-600">Nothing to import. Every row matches what is already saved.</p>
                ) : (
                  <p className="text-slate-600">Ready to import {plural(importCount, "product")}.</p>
                )}
              </div>
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant="outline"
                  disabled={busy !== null}
                  onClick={() => {
                    setError(null)
                    setStep("upload")
                  }}
                >
                  Back
                </Button>
                <Button
                  type="button"
                  data-testid="import-confirm"
                  className="bg-indigo-600 text-white hover:bg-indigo-700"
                  disabled={busy !== null || errorRows > 0 || importCount === 0}
                  onClick={confirmImport}
                >
                  {busy === "commit" ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <ArrowRight className="mr-2 h-4 w-4" />}
                  {busy === "commit" ? "Importing…" : `Import ${plural(importCount, "product")}`}
                </Button>
              </div>
            </>
          )}

          {step === "result" && (
            <>
              <span />
              <Button
                type="button"
                data-testid="import-close-refresh"
                className="bg-indigo-600 text-white hover:bg-indigo-700"
                onClick={() => handleOpenChange(false)}
              >
                Close and refresh list
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function RowItem({
  r,
  hasDetails,
  isOpen,
  detailsId,
  onToggle,
}: {
  r: ImportRow
  hasDetails: boolean
  isOpen: boolean
  detailsId: string
  onToggle: () => void
}) {
  const issueCount = r.errors.length + r.warnings.length
  return (
    <>
      <tr
        data-testid={`import-row-${r.row}`}
        data-status={r.status}
        data-action={r.action}
        className={`border-b border-[#eeeef7] align-top ${r.status === "error" ? "bg-red-50/60" : ""}`}
      >
        <td className="px-3 py-2 tabular-nums text-slate-500">{r.row}</td>
        <td className="px-3 py-2 font-medium text-slate-900">{r.sku || <span className="text-slate-400">(no SKU)</span>}</td>
        <td className="px-3 py-2">
          <ActionBadge action={r.action} />
        </td>
        <td className="px-3 py-2">
          <StatusBadge status={r.status} />
        </td>
        <td className="px-3 py-2">
          {hasDetails ? (
            <button
              type="button"
              aria-expanded={isOpen}
              aria-controls={detailsId}
              onClick={onToggle}
              className="inline-flex items-center gap-1 text-xs font-medium text-indigo-700 hover:underline"
            >
              {isOpen ? <ChevronDown className="h-3.5 w-3.5" /> : <ChevronRight className="h-3.5 w-3.5" />}
              {isOpen ? "Hide" : "Show"} details
              {issueCount > 0 ? ` (${issueCount})` : r.changes?.length ? ` (${r.changes.length} changes)` : ""}
            </button>
          ) : (
            <span className="text-xs text-slate-400">-</span>
          )}
        </td>
      </tr>
      {isOpen ? (
        <tr id={detailsId} data-testid={`import-row-${r.row}-details`} className="border-b border-[#eeeef7] bg-[#f8f8fd]">
          <td />
          <td colSpan={4} className="space-y-2 px-3 py-2 text-xs">
            {r.errors.length > 0 ? (
              <ul className="space-y-0.5 text-red-700">
                {r.errors.map((e, i) => (
                  <li key={`e${i}`}>
                    <span className="font-semibold">{e.column || e.field || "Row"}:</span> {e.message}
                  </li>
                ))}
              </ul>
            ) : null}
            {r.warnings.length > 0 ? (
              <ul className="space-y-0.5 text-amber-800">
                {r.warnings.map((w, i) => (
                  <li key={`w${i}`}>
                    <span className="font-semibold">{w.column || w.field || "Row"}:</span> {w.message}
                  </li>
                ))}
              </ul>
            ) : null}
            {r.changes && r.changes.length > 0 ? (
              <ul className="space-y-0.5 text-slate-700">
                {r.changes.map((c, i) => (
                  <li key={`c${i}`}>
                    <span className="font-semibold">{c.column || c.field}:</span>{" "}
                    <span className="text-slate-500 line-through">{formatChangeValue(c.from)}</span>{" "}
                    <span aria-hidden>→</span>
                    <span className="sr-only">changes to</span> <span className="font-medium text-slate-900">{formatChangeValue(c.to)}</span>
                  </li>
                ))}
              </ul>
            ) : null}
            {r.note ? <p className="text-slate-600">{r.note}</p> : null}
          </td>
        </tr>
      ) : null}
    </>
  )
}
