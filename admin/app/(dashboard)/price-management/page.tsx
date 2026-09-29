"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Clock3, Download, FolderTree, History, Loader2, Package, Search } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"
import { describeDiscountSource, type EffectivePricing, type EffectiveRolePricing } from "@/lib/discount"
import { toast } from "sonner"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

type Category = {
  _id: string
  name: string
  nameHindi?: string
  slug: string
  productCount?: number
  isActive?: boolean
  image?: { url?: string }
}

type Product = {
  _id: string
  name: string
  sku?: string
  retailPrice: number
  wholesalePrice: number
  stock: number
  pendingRetailPrice?: number | null
  pendingWholesalePrice?: number | null
  priceChangeScheduledAt?: string | null
  priceChangeEffectiveAt?: string | null
  effectivePricing?: EffectivePricing
}

// A brand/category discount (% off MRP) replaces the stored price; flag it so
// admins know edits to this price won't be what customers pay.
function DiscountOverride({ pricing, format }: { pricing?: EffectiveRolePricing; format: (value: number) => string }) {
  const description = describeDiscountSource(pricing)
  if (!pricing || !description) return null
  return <div className="mt-0.5 text-[11px] font-normal text-amber-400">Selling at {format(pricing.price)} · {description}</div>
}

type PriceChangeAudit = {
  id: string
  productName: string
  productSku?: string
  oldRetailPrice: number
  newRetailPrice: number | null
  oldWholesalePrice: number
  newWholesalePrice: number | null
  scheduleType: string
  status: "scheduled" | "applied" | "superseded"
  scheduledAt: string
  effectiveAt: string
  performedBy: string
}

type RowDraft = {
  retailPrice: string
  wholesalePrice: string
  priceChangeMode: "immediate" | "schedule_24h" | "schedule_48h" | "custom"
  customEffectiveAt: string
}

const DEFAULT_DRAFT: RowDraft = {
  retailPrice: "",
  wholesalePrice: "",
  priceChangeMode: "schedule_24h",
  customEffectiveAt: "",
}

function formatPrice(value: number | null | undefined) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return "—"
  return `₹${Number(value).toLocaleString("en-IN", { maximumFractionDigits: 2 })}`
}

function formatIst(value: string | null | undefined) {
  if (!value) return "—"
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return "—"
  return date.toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  })
}

function modeLabel(mode: RowDraft["priceChangeMode"]) {
  return {
    immediate: "Immediately",
    schedule_24h: "After 24 hours",
    schedule_48h: "After 48 hours",
    custom: "Custom date at 8:00 AM IST",
  }[mode]
}

/** Converts a selected calendar date into 8:00 AM IST as an ISO/UTC value. */
function indiaDateTo8AmIso(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (!match) return null
  const [, year, month, day] = match
  const istOffsetMs = 5.5 * 60 * 60 * 1000
  return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), 8, 0) - istOffsetMs).toISOString()
}

export default function PriceManagementPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const selectedCategoryId = searchParams.get("categoryId") || ""
  const [categories, setCategories] = useState<Category[]>([])
  const [categorySearch, setCategorySearch] = useState("")
  const [products, setProducts] = useState<Product[]>([])
  const [productSearch, setProductSearch] = useState("")
  const [appliedProductSearch, setAppliedProductSearch] = useState("")
  const [audits, setAudits] = useState<PriceChangeAudit[]>([])
  const [drafts, setDrafts] = useState<Record<string, RowDraft>>({})
  const [stockDrafts, setStockDrafts] = useState<Record<string, string>>({})
  const [savingProductId, setSavingProductId] = useState<string | null>(null)
  const [savingStockProductId, setSavingStockProductId] = useState<string | null>(null)
  const [isCategoriesLoading, setIsCategoriesLoading] = useState(true)
  const [isProductsLoading, setIsProductsLoading] = useState(false)
  const [isHistoryLoading, setIsHistoryLoading] = useState(false)
  const [historyPage, setHistoryPage] = useState(1)
  const [hasMoreHistory, setHasMoreHistory] = useState(false)
  const [page, setPage] = useState(1)
  const [totalProducts, setTotalProducts] = useState(0)
  const [hasMore, setHasMore] = useState(false)
  const [isExporting, setIsExporting] = useState(false)

  const selectedCategory = useMemo(
    () => categories.find((category) => category._id === selectedCategoryId) || null,
    [categories, selectedCategoryId],
  )

  const exportPriceSnapshot = async () => {
    setIsExporting(true)
    try {
      const response = await apiFetch("/admin/products/price-snapshot.xlsx")
      if (!response.ok) {
        const data = await response.json().catch(() => null)
        throw new Error(data?.message || "Failed to export price snapshot")
      }

      const blob = await response.blob()
      const contentDisposition = response.headers.get("Content-Disposition") || ""
      const fileNameMatch = /filename=\"?([^\";]+)\"?/i.exec(contentDisposition)
      const link = document.createElement("a")
      const downloadUrl = window.URL.createObjectURL(blob)
      link.href = downloadUrl
      link.download = fileNameMatch?.[1] || "product-price-snapshot.xlsx"
      document.body.appendChild(link)
      link.click()
      link.remove()
      window.URL.revokeObjectURL(downloadUrl)
      toast.success("Price snapshot downloaded")
    } catch (error: any) {
      toast.error(error?.message || "Failed to export price snapshot")
    } finally {
      setIsExporting(false)
    }
  }

  const filteredCategories = useMemo(() => {
    const query = categorySearch.trim().toLowerCase()
    if (!query) return categories
    return categories.filter((category) =>
      `${category.name} ${category.nameHindi || ""}`.toLowerCase().includes(query),
    )
  }, [categories, categorySearch])

  const fetchCategories = useCallback(async () => {
    setIsCategoriesLoading(true)
    try {
      const response = await apiFetch("/categories?page=1&limit=200", { skipAuth: true })
      const data = await response.json()
      if (!response.ok) throw new Error(data?.message || "Failed to load categories")
      setCategories(Array.isArray(data?.data) ? data.data : [])
    } catch (error: any) {
      toast.error(error?.message || "Failed to load categories")
    } finally {
      setIsCategoriesLoading(false)
    }
  }, [])

  const fetchProducts = useCallback(async (nextPage = 1, append = false, search = "") => {
    if (!selectedCategoryId) return
    append ? setIsProductsLoading(false) : setIsProductsLoading(true)
    try {
      const params = new URLSearchParams({
        categoryId: selectedCategoryId,
        page: String(nextPage),
        limit: "20",
      })
      if (search.trim()) params.set("search", search.trim())
      const response = await apiFetch(`/admin/products?${params.toString()}`)
      const data = await response.json()
      if (!response.ok) throw new Error(data?.message || "Failed to load products")
      const nextProducts = Array.isArray(data?.data) ? data.data : []
      setProducts((current) => (append ? [...current, ...nextProducts] : nextProducts))
      setPage(Number(data?.pagination?.page || nextPage))
      setTotalProducts(Number(data?.pagination?.total || nextProducts.length))
      setHasMore(Boolean(data?.pagination?.hasNext))
    } catch (error: any) {
      toast.error(error?.message || "Failed to load products")
      if (!append) setProducts([])
    } finally {
      setIsProductsLoading(false)
    }
  }, [selectedCategoryId])

  const fetchHistory = useCallback(async (nextPage = 1, append = false) => {
    setIsHistoryLoading(true)
    try {
      const response = await apiFetch(`/admin/price-change-history?page=${nextPage}&limit=5`)
      const data = await response.json()
      if (!response.ok) throw new Error(data?.message || "Failed to load price history")
      const nextAudits = Array.isArray(data?.data) ? data.data : []
      setAudits((current) => (append ? [...current, ...nextAudits] : nextAudits))
      setHistoryPage(Number(data?.pagination?.page || nextPage))
      setHasMoreHistory(Boolean(data?.pagination?.hasNext))
    } catch (error: any) {
      toast.error(error?.message || "Failed to load price history")
      if (!append) setAudits([])
    } finally {
      setIsHistoryLoading(false)
    }
  }, [])

  useEffect(() => {
    void fetchCategories()
    void fetchHistory()
  }, [fetchCategories, fetchHistory])

  useEffect(() => {
    if (!selectedCategoryId) {
      setProducts([])
      setDrafts({})
      setStockDrafts({})
      return
    }
    setDrafts({})
    setStockDrafts({})
    void fetchProducts(1, false, "")
  }, [fetchProducts, selectedCategoryId])

  const updateDraft = (productId: string, patch: Partial<RowDraft>) => {
    setDrafts((current) => ({
      ...current,
      [productId]: { ...(current[productId] || DEFAULT_DRAFT), ...patch },
    }))
  }

  const updateStockDraft = (productId: string, quantity: string) => {
    setStockDrafts((current) => ({ ...current, [productId]: quantity }))
  }

  const addStock = async (product: Product) => {
    const quantityText = (stockDrafts[product._id] || "").trim()
    const quantity = Number(quantityText)

    if (!Number.isSafeInteger(quantity) || quantity <= 0) {
      toast.error("Enter a positive whole number of units to add")
      return
    }

    if (!window.confirm(`Add ${quantity} unit${quantity === 1 ? "" : "s"} to ${product.name}?`)) {
      return
    }

    setSavingStockProductId(product._id)
    try {
      const response = await apiFetch(`/admin/products/${product._id}/stock`, {
        method: "PUT",
        body: JSON.stringify({ adjustment: `+${quantity}` }),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data?.message || "Failed to add stock")

      const newStock = Number(data?.data?.newStock)
      if (!Number.isFinite(newStock)) throw new Error("The stock update response was invalid")

      setProducts((current) => current.map((currentProduct) => (
        currentProduct._id === product._id ? { ...currentProduct, stock: newStock } : currentProduct
      )))
      setStockDrafts((current) => ({ ...current, [product._id]: "" }))
      toast.success(data?.message || "Stock added successfully")
    } catch (error: any) {
      toast.error(error?.message || "Failed to add stock")
    } finally {
      setSavingStockProductId(null)
    }
  }

  const selectCategory = (categoryId: string) => {
    router.replace(`/price-management?categoryId=${encodeURIComponent(categoryId)}`)
  }

  const clearCategory = () => {
    router.replace("/price-management")
  }

  const schedulePriceChange = async (product: Product) => {
    const draft = drafts[product._id] || DEFAULT_DRAFT
    const retailPrice = draft.retailPrice.trim()
    const wholesalePrice = draft.wholesalePrice.trim()

    if (!retailPrice && !wholesalePrice) {
      toast.error("Enter a new customer or wholesale price first")
      return
    }

    const payload: Record<string, string | number> = {
      priceChangeMode: draft.priceChangeMode,
    }
    if (retailPrice) payload.retailPrice = Number(retailPrice)
    if (wholesalePrice) payload.wholesalePrice = Number(wholesalePrice)

    if (draft.priceChangeMode === "custom") {
      const effectiveAt = indiaDateTo8AmIso(draft.customEffectiveAt)
      if (!effectiveAt || new Date(effectiveAt).getTime() <= Date.now()) {
        toast.error("Select a future custom date. Changes apply at 8:00 AM IST.")
        return
      }
      payload.effectiveAt = effectiveAt
    }

    const priceSummary = [
      retailPrice ? `Customer: ₹${retailPrice}` : "",
      wholesalePrice ? `Wholesale: ₹${wholesalePrice}` : "",
    ].filter(Boolean).join(" · ")
    if (!window.confirm(`${priceSummary}\n\nApply: ${modeLabel(draft.priceChangeMode)}?\n\nThis replaces any pending change for this product.`)) {
      return
    }

    setSavingProductId(product._id)
    try {
      const response = await apiFetch(`/admin/products/${product._id}/price-change`, {
        method: "PUT",
        body: JSON.stringify(payload),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data?.message || "Failed to update price")

      const updatedProduct = data?.data?.product as Product | undefined
      if (updatedProduct) {
        setProducts((current) => current.map((currentProduct) =>
          currentProduct._id === product._id ? { ...currentProduct, ...updatedProduct } : currentProduct,
        ))
      }
      setDrafts((current) => ({ ...current, [product._id]: { ...DEFAULT_DRAFT } }))
      toast.success(data?.message || "Price change saved")
      void fetchHistory()
    } catch (error: any) {
      toast.error(error?.message || "Failed to update price")
    } finally {
      setSavingProductId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white sm:text-3xl">Price Management</h1>
          <p className="mt-1 text-sm text-gray-400">Choose a category, then schedule each product price change independently.</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button type="button" onClick={() => void exportPriceSnapshot()} disabled={isExporting} className="bg-[#818cf8] text-black hover:bg-[#818cf8]/90">
            {isExporting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Download className="mr-2 h-4 w-4" />}
            {isExporting ? "Preparing Excel..." : "Export Excel"}
          </Button>
          {selectedCategory ? (
            <Button type="button" onClick={clearCategory} variant="outline" className="border-[#333] bg-[#161616] text-white hover:bg-[#1A1A1A]">
              <FolderTree className="mr-2 h-4 w-4" /> All Categories
            </Button>
          ) : null}
        </div>
      </div>

      {!selectedCategoryId ? (
        <section className="space-y-4">
          <div className="relative max-w-md">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
            <Input value={categorySearch} onChange={(event) => setCategorySearch(event.target.value)} placeholder="Search categories..." className="border-[#333] bg-[#161616] pl-9 text-white placeholder:text-gray-500" />
          </div>
          {isCategoriesLoading ? (
            <div className="flex h-48 items-center justify-center rounded-xl border border-[#333] bg-[#161616]"><Loader2 className="h-7 w-7 animate-spin text-[#818cf8]" /></div>
          ) : filteredCategories.length === 0 ? (
            <div className="flex h-48 flex-col items-center justify-center rounded-xl border border-[#333] bg-[#161616] text-gray-400"><FolderTree className="mb-3 h-9 w-9" />No categories found</div>
          ) : (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {filteredCategories.map((category) => (
                <button key={category._id} type="button" onClick={() => selectCategory(category._id)} className="rounded-xl border border-[#333] bg-[#161616] p-4 text-left transition-colors hover:border-[#818cf8]/70 hover:bg-[#1A1A1A] focus:outline-none focus:ring-2 focus:ring-[#818cf8]">
                  <div className="flex items-start gap-3">
                    {category.image?.url ? <img src={category.image.url} alt="" className="h-11 w-11 rounded-lg object-cover" /> : <span className="flex h-11 w-11 items-center justify-center rounded-lg bg-[#0D0D0D]"><FolderTree className="h-5 w-5 text-[#818cf8]" /></span>}
                    <div className="min-w-0"><h2 className="truncate font-semibold text-white">{category.name}</h2>{category.nameHindi ? <p className="mt-0.5 truncate text-xs text-gray-400">{category.nameHindi}</p> : null}</div>
                  </div>
                  <div className="mt-4 flex items-center justify-between border-t border-[#333] pt-3 text-sm"><span className="text-gray-400">Products</span><span className="font-semibold text-[#818cf8]">{category.productCount || 0}</span></div>
                </button>
              ))}
            </div>
          )}
        </section>
      ) : (
        <section className="space-y-4">
          <div className="rounded-xl border border-[#333] bg-[#161616] p-5">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div className="flex items-center gap-3"><span className="flex h-11 w-11 items-center justify-center rounded-lg bg-[#0D0D0D]"><Package className="h-5 w-5 text-[#818cf8]" /></span><div><h2 className="text-xl font-semibold text-white">{selectedCategory?.name || "Selected Category"}</h2><p className="text-sm text-gray-400">{totalProducts} product{totalProducts === 1 ? "" : "s"} · prices are in ₹</p></div></div>
              <form onSubmit={(event) => { event.preventDefault(); setAppliedProductSearch(productSearch); void fetchProducts(1, false, productSearch) }} className="flex w-full gap-2 lg:w-auto"><div className="relative flex-1 lg:w-72"><Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" /><Input value={productSearch} onChange={(event) => setProductSearch(event.target.value)} placeholder="Search name or SKU..." className="border-[#333] bg-[#0D0D0D] pl-9 text-white placeholder:text-gray-500" /></div><Button type="submit" className="bg-[#818cf8] text-black hover:bg-[#818cf8]/90">Search</Button></form>
            </div>
          </div>

          <div className="overflow-x-auto rounded-xl border border-[#333] bg-[#161616]">
            <Table className="min-w-[1320px] border-separate border-spacing-0 border-2 border-slate-300 text-[13px]">
              <TableHeader className="[&_th]:border-b [&_th]:border-r [&_th]:border-slate-300"><TableRow className="border-slate-300 hover:bg-transparent"><TableHead className="w-11 whitespace-normal px-2 text-xs leading-tight text-gray-400">S.No.</TableHead><TableHead className="min-w-48 whitespace-normal px-2 text-xs leading-tight text-gray-400">Product</TableHead><TableHead className="min-w-28 whitespace-normal px-2 text-xs leading-tight text-gray-400">Customer Price</TableHead><TableHead className="min-w-28 whitespace-normal px-2 text-xs leading-tight text-gray-400">Wholesale Price</TableHead><TableHead className="min-w-32 whitespace-normal px-2 text-xs leading-tight text-gray-400">New Customer Price</TableHead><TableHead className="min-w-32 whitespace-normal px-2 text-xs leading-tight text-gray-400">New Wholesale Price</TableHead><TableHead className="min-w-36 whitespace-normal px-2 text-xs leading-tight text-gray-400">Schedule</TableHead><TableHead className="min-w-32 whitespace-normal px-2 text-xs leading-tight text-gray-400">Stock</TableHead><TableHead className="min-w-44 whitespace-normal px-2 text-xs leading-tight text-gray-400">Pending Change</TableHead><TableHead className="min-w-28 whitespace-normal px-2 text-right text-xs leading-tight text-gray-400">Action</TableHead></TableRow></TableHeader>
              <TableBody className="[&_td]:border-b [&_td]:border-r [&_td]:border-slate-300">
                {isProductsLoading ? <TableRow className="border-[#333]"><TableCell colSpan={10} className="h-48 text-center"><Loader2 className="mx-auto h-6 w-6 animate-spin text-[#818cf8]" /></TableCell></TableRow> : products.length === 0 ? <TableRow className="border-[#333]"><TableCell colSpan={10} className="h-48 text-center text-gray-400">No products found in this category.</TableCell></TableRow> : products.map((product, index) => {
                  const draft = drafts[product._id] || DEFAULT_DRAFT
                  const stockDraft = stockDrafts[product._id] || ""
                  const hasPending = product.priceChangeEffectiveAt && (product.pendingRetailPrice !== null || product.pendingWholesalePrice !== null)
                  return <TableRow key={product._id} className="border-[#333] hover:bg-[#1A1A1A]/70"><TableCell className="px-2 text-xs text-gray-400">{(page - 1) * 20 + index + 1}</TableCell><TableCell className="px-2"><div className="font-medium text-white">{product.name}</div><div className="mt-0.5 text-xs text-gray-500">{product.sku || "No SKU"}</div></TableCell><TableCell className="font-medium text-white">{formatPrice(product.retailPrice)}<DiscountOverride pricing={product.effectivePricing?.buyer} format={formatPrice} /></TableCell><TableCell className="font-medium text-white">{formatPrice(product.wholesalePrice)}<DiscountOverride pricing={product.effectivePricing?.wholesaler} format={formatPrice} /></TableCell><TableCell><Input type="text" inputMode="decimal" value={draft.retailPrice} onChange={(event) => updateDraft(product._id, { retailPrice: event.target.value })} placeholder="Enter customer price" aria-label={`New customer price for ${product.name}`} className="h-8 border-[#333] bg-[#0D0D0D] px-2 text-sm text-white placeholder:text-xs placeholder:text-gray-600" /></TableCell><TableCell><Input type="text" inputMode="decimal" value={draft.wholesalePrice} onChange={(event) => updateDraft(product._id, { wholesalePrice: event.target.value })} placeholder="Enter wholesale price" aria-label={`New wholesale price for ${product.name}`} className="h-8 border-[#333] bg-[#0D0D0D] px-2 text-sm text-white placeholder:text-xs placeholder:text-gray-600" /></TableCell><TableCell><div className="space-y-1"><Select value={draft.priceChangeMode} onValueChange={(value) => updateDraft(product._id, { priceChangeMode: value as RowDraft["priceChangeMode"] })}><SelectTrigger className="h-8 border-[#333] bg-[#0D0D0D] px-2 text-sm text-white"><SelectValue /></SelectTrigger><SelectContent><SelectItem value="immediate">Immediately</SelectItem><SelectItem value="schedule_24h">After 24 hours</SelectItem><SelectItem value="schedule_48h">After 48 hours</SelectItem><SelectItem value="custom">Custom date (8:00 AM IST)</SelectItem></SelectContent></Select>{draft.priceChangeMode === "custom" ? <Input type="date" value={draft.customEffectiveAt} onChange={(event) => updateDraft(product._id, { customEffectiveAt: event.target.value })} className="h-8 border-[#333] bg-[#0D0D0D] px-2 text-sm text-white" aria-label={`Custom date at 8:00 AM IST for ${product.name}`} /> : null}</div></TableCell><TableCell><div className="space-y-1"><p className="text-sm font-medium text-white">{Number(product.stock || 0).toLocaleString("en-IN")} units</p><div className="flex gap-1"><Input type="text" inputMode="numeric" pattern="[0-9]*" value={stockDraft} onChange={(event) => updateStockDraft(product._id, event.target.value)} placeholder="Qty to add" aria-label={`Add stock for ${product.name}`} className="h-8 min-w-0 border-[#333] bg-[#0D0D0D] px-2 text-sm text-white placeholder:text-xs placeholder:text-gray-600" /><Button type="button" onClick={() => void addStock(product)} disabled={savingStockProductId === product._id} className="h-8 shrink-0 bg-[#818cf8] px-2 text-sm text-black hover:bg-[#818cf8]/90">{savingStockProductId === product._id ? <Loader2 className="h-4 w-4 animate-spin" /> : "Add"}</Button></div></div></TableCell><TableCell>{hasPending ? <div className="space-y-1 text-xs"><Badge className="bg-amber-500/15 text-amber-300 hover:bg-amber-500/15">Pending</Badge>{product.pendingRetailPrice !== null && product.pendingRetailPrice !== undefined ? <p className="text-gray-300">Customer: {formatPrice(product.pendingRetailPrice)}</p> : null}{product.pendingWholesalePrice !== null && product.pendingWholesalePrice !== undefined ? <p className="text-gray-300">Wholesale: {formatPrice(product.pendingWholesalePrice)}</p> : null}<p className="text-gray-500">{formatIst(product.priceChangeEffectiveAt)}</p></div> : <span className="text-xs text-gray-500">No pending change</span>}</TableCell><TableCell className="text-right"><Button type="button" onClick={() => void schedulePriceChange(product)} disabled={savingProductId === product._id} className="h-8 min-w-28 px-2 text-sm text-black bg-[#818cf8] hover:bg-[#818cf8]/90">{savingProductId === product._id ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Clock3 className="mr-2 h-4 w-4" />}Save price</Button></TableCell></TableRow>
                })}
              </TableBody>
            </Table>
          </div>
          {hasMore ? <div className="flex justify-center"><Button type="button" onClick={() => void fetchProducts(page + 1, true, appliedProductSearch)} variant="outline" className="border-[#333] bg-[#161616] text-white hover:bg-[#1A1A1A]">Load more products</Button></div> : null}
        </section>
      )}

      <section className="overflow-hidden rounded-xl border border-[#333] bg-[#161616]">
        <div className="flex items-center justify-between border-b border-[#333] px-5 py-4"><div><h2 className="flex items-center gap-2 text-lg font-semibold text-white"><History className="h-5 w-5 text-[#818cf8]" /> Price Change History</h2><p className="mt-1 text-sm text-gray-400">Latest scheduled, applied, and replaced product price changes.</p></div><Button type="button" onClick={() => void fetchHistory()} variant="outline" disabled={isHistoryLoading} className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]">Refresh</Button></div>
        <div className="overflow-x-auto"><Table className="min-w-[940px]"><TableHeader><TableRow className="border-[#333] hover:bg-transparent"><TableHead className="text-gray-400">Product</TableHead><TableHead className="text-gray-400">Customer</TableHead><TableHead className="text-gray-400">Wholesale</TableHead><TableHead className="text-gray-400">Timing</TableHead><TableHead className="text-gray-400">Status</TableHead><TableHead className="text-gray-400">Effective (IST)</TableHead><TableHead className="text-gray-400">By</TableHead></TableRow></TableHeader><TableBody>{isHistoryLoading && audits.length === 0 ? <TableRow className="border-[#333]"><TableCell colSpan={7} className="h-24 text-center"><Loader2 className="mx-auto h-5 w-5 animate-spin text-[#818cf8]" /></TableCell></TableRow> : audits.length === 0 ? <TableRow className="border-[#333]"><TableCell colSpan={7} className="h-24 text-center text-gray-500">No price changes recorded yet.</TableCell></TableRow> : audits.map((audit) => <TableRow key={audit.id} className="border-[#333]"><TableCell><p className="font-medium text-white">{audit.productName}</p><p className="text-xs text-gray-500">{audit.productSku || "—"}</p></TableCell><TableCell className="text-gray-300">{formatPrice(audit.oldRetailPrice)} → {formatPrice(audit.newRetailPrice)}</TableCell><TableCell className="text-gray-300">{formatPrice(audit.oldWholesalePrice)} → {formatPrice(audit.newWholesalePrice)}</TableCell><TableCell className="text-gray-300">{audit.scheduleType === "schedule_24h" ? "24 hours" : audit.scheduleType === "schedule_48h" ? "48 hours" : audit.scheduleType === "custom" ? "Custom" : "Immediate"}</TableCell><TableCell><Badge className={audit.status === "applied" ? "bg-indigo-500/15 text-indigo-300 hover:bg-indigo-500/15" : audit.status === "superseded" ? "bg-gray-500/15 text-gray-300 hover:bg-gray-500/15" : "bg-amber-500/15 text-amber-300 hover:bg-amber-500/15"}>{audit.status}</Badge></TableCell><TableCell className="text-gray-300">{formatIst(audit.effectiveAt)}</TableCell><TableCell className="text-gray-400">{audit.performedBy}</TableCell></TableRow>)}</TableBody></Table></div>
        {hasMoreHistory ? <div className="flex justify-center border-t border-[#333] px-5 py-4"><Button type="button" onClick={() => void fetchHistory(historyPage + 1, true)} variant="outline" disabled={isHistoryLoading} className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]">{isHistoryLoading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}Load more changes</Button></div> : null}
      </section>
    </div>
  )
}
