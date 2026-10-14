import { apiFetch } from "@/lib/api"

export type PriceChangeMode = "immediate" | "schedule_24h"
export type ImportAction = "create" | "update" | "skip"
export type ImportRowStatus = "ok" | "warning" | "error"

export interface ImportIssue {
  field?: string
  column?: string
  message: string
}

export interface ImportChange {
  field?: string
  column?: string
  from: unknown
  to: unknown
}

export interface ImportRow {
  row: number
  sku: string
  action: ImportAction
  status: ImportRowStatus
  errors: ImportIssue[]
  warnings: ImportIssue[]
  changes?: ImportChange[]
  normalized?: Record<string, unknown>
  note?: string
  productId?: string
}

export interface ImportSummary {
  totalRows: number
  created: number
  updated: number
  skipped: number
  errors: number
  warnings: number
  errorCount: number
  warningCount: number
  newBrands: number
  newCategories: number
}

export interface ImportReport {
  dryRun: boolean
  committed: boolean
  createMissing: boolean
  priceChangeMode: PriceChangeMode
  fileName: string
  summary: ImportSummary
  newBrands: string[]
  newCategories: string[]
  columns: { header: string; field: string; label: string }[]
  ignoredColumns: string[]
  rows: ImportRow[]
}

export interface ImportOptions {
  dryRun: boolean
  createMissing: boolean
  priceChangeMode: PriceChangeMode
}

export const IMPORT_ACCEPT = ".xlsx,.csv"
export const IMPORT_MAX_BYTES = 5 * 1024 * 1024

// Request-level failure (HTTP 4xx/5xx or network). Row problems are NOT errors:
// they come back inside a normal report.
export class CatalogImportError extends Error {
  code?: string
  status?: number
  constructor(message: string, code?: string, status?: number) {
    super(message)
    this.name = "CatalogImportError"
    this.code = code
    this.status = status
  }
}

const FRIENDLY: Record<string, string> = {
  FILE_REQUIRED: "Choose a file to import.",
  INVALID_FILE_TYPE: "That file type is not supported. Upload an .xlsx or .csv file.",
  FILE_TOO_LARGE: "That file is larger than 5 MB. Split it into smaller files.",
  TOO_MANY_ROWS: "That file has more than 5,000 rows. Split it into smaller files.",
}

export function isSupportedImportFile(file: File): boolean {
  return /\.(xlsx|csv)$/i.test(file.name)
}

async function readError(res: Response): Promise<CatalogImportError> {
  const data = await res.json().catch(() => ({}))
  const code: string | undefined = data?.error?.code
  const detail: string | undefined = data?.error?.message || data?.message
  const message = (code && FRIENDLY[code] && !detail ? FRIENDLY[code] : detail) || (code && FRIENDLY[code]) || `Import failed (HTTP ${res.status})`
  return new CatalogImportError(message, code, res.status)
}

// Sends the file to the import endpoint. dryRun=true only validates and previews;
// nothing is saved until the same call is made with dryRun=false.
export async function uploadCatalogFile(file: File, options: ImportOptions): Promise<ImportReport> {
  const body = new FormData()
  body.append("file", file)
  const params = new URLSearchParams({
    dryRun: String(options.dryRun),
    createMissing: String(options.createMissing),
    priceChangeMode: options.priceChangeMode,
  })
  const res = await apiFetch(`/admin/products/import?${params.toString()}`, { method: "POST", body })
  if (!res.ok) throw await readError(res)
  const data = await res.json().catch(() => null)
  if (!data?.data?.summary || !Array.isArray(data.data.rows)) {
    throw new CatalogImportError("The server sent an unexpected response. Try again.")
  }
  return data.data as ImportReport
}

export async function downloadImportTemplate(): Promise<void> {
  const res = await apiFetch("/admin/products/import/template")
  if (!res.ok) throw await readError(res)
  const blob = await res.blob()
  const disposition = res.headers.get("Content-Disposition") || ""
  const match = /filename="?([^";]+)"?/i.exec(disposition)
  const name = match ? decodeURIComponent(match[1]) : "catalog-import-template.xlsx"
  const url = URL.createObjectURL(blob)
  const link = document.createElement("a")
  link.href = url
  link.download = name
  document.body.appendChild(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 30_000)
}

export function formatChangeValue(value: unknown): string {
  if (value === null || value === undefined || value === "") return "empty"
  if (Array.isArray(value)) return value.length ? value.join(", ") : "empty"
  if (typeof value === "boolean") return value ? "Yes" : "No"
  if (typeof value === "object") return JSON.stringify(value)
  return String(value)
}
