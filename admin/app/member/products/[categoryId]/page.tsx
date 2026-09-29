"use client"
/* eslint-disable @next/next/no-img-element, react-hooks/set-state-in-effect */

import Link from "next/link"
import { FormEvent, useEffect, useState } from "react"
import { useParams } from "next/navigation"
import { apiFetch } from "@/lib/api"
import { type EffectivePricing, type EffectiveRolePricing } from "@/lib/discount"
import { toast } from "sonner"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ArrowLeft, FolderTree, Loader2, Package, Search } from "@/components/hugeicons"

type Category = {
  _id: string
  name: string
  nameHindi?: string
  description?: string
  image?: { url?: string }
  company?: { name?: string } | string | null
}

type Product = {
  _id: string
  name: string
  nameHindi?: string
  sku?: string
  category?: string
  retailPrice: number
  wholesalePrice: number
  effectivePricing?: EffectivePricing
  stock?: number
  status: string
  priceUnit?: string
  packing?: string
  images?: Array<{ url?: string; isPrimary?: boolean }>
}

function isObjectId(value?: string) {
  return Boolean(value && /^[a-f\d]{24}$/i.test(value))
}

function formatPrice(value: number) {
  return `₹${Number(value || 0).toLocaleString("en-IN")}`
}

// Member quote the price customers actually pay (after brand/category discount).
function sellingPrice(pricing: EffectiveRolePricing | undefined, fallback: number) {
  return pricing && pricing.price > 0 ? pricing.price : fallback
}

function DiscountNote({ pricing }: { pricing?: EffectiveRolePricing }) {
  if (!pricing?.discountPercent) return null
  return <p className="mt-0.5 text-[10px] font-medium text-amber-600">{pricing.discountPercent}% off MRP</p>
}

function productImage(product: Product) {
  return product.images?.find((image) => image.isPrimary)?.url || product.images?.[0]?.url
}

function ProductCard({ product }: { product: Product }) {
  const image = productImage(product)
  return <article className="catalog-card-borderless flex min-h-[280px] flex-col rounded-[22px] bg-white p-4 shadow-[0_12px_32px_rgba(50,58,110,0.07)]"><div className="mb-4 flex items-start justify-between gap-3">{image ? <img src={image} alt={product.name} className="h-12 w-12 rounded-xl object-cover" /> : <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-[#e8e8f5]"><Package className="h-5 w-5 text-slate-500" /></div>}<Badge variant="outline" className={`capitalize ${product.status === "active" ? "border-indigo-200 bg-indigo-50 text-indigo-700" : "border-slate-200 bg-slate-100 text-slate-600"}`}>{product.status}</Badge></div><h2 className="line-clamp-2 text-sm font-bold leading-5 text-slate-900">{product.name}</h2>{product.nameHindi && <p className="mt-1 line-clamp-1 text-xs text-slate-500">{product.nameHindi}</p>}<p className="mt-1.5 truncate text-[10px] text-slate-500">SKU: {product.sku || "—"}</p><div className="mt-3 flex flex-wrap gap-1.5"><span className="max-w-full truncate rounded-full border border-[#dce7ef] bg-[#f4f9fc] px-2 py-0.5 text-[10px] text-slate-600">{product.category || "Uncategorized"}</span>{product.packing && <span className="rounded-full border border-[#d8d9ea] bg-[#f0f0f9] px-2 py-0.5 text-[10px] text-slate-600">{product.packing}</span>}</div><div className="mt-auto grid grid-cols-2 gap-3 border-t border-[#e7e7f0] pt-4"><div><p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">Customer price</p><p className="mt-1 text-sm font-bold text-blue-600">{formatPrice(sellingPrice(product.effectivePricing?.buyer, product.retailPrice))}</p><DiscountNote pricing={product.effectivePricing?.buyer} /></div><div className="border-l border-[#e7e7f0] pl-3"><p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">Wholesaler price</p><p className="mt-1 text-sm font-bold text-indigo-700">{formatPrice(sellingPrice(product.effectivePricing?.wholesaler, product.wholesalePrice))}</p><DiscountNote pricing={product.effectivePricing?.wholesaler} /></div></div><p className="mt-3 text-right text-[10px] text-slate-500">Stock <span className="font-semibold text-slate-800">{Number(product.stock || 0).toLocaleString("en-IN")}{product.priceUnit ? ` ${product.priceUnit}` : ""}</span></p></article>
}

export default function MemberCategoryProductsPage() {
  const params = useParams<{ categoryId: string | string[] }>()
  const categoryId = Array.isArray(params.categoryId) ? params.categoryId[0] : params.categoryId
  const [category, setCategory] = useState<Category | null>(null)
  const [products, setProducts] = useState<Product[]>([])
  const [searchQuery, setSearchQuery] = useState("")
  const [page, setPage] = useState(1)
  const [totalProducts, setTotalProducts] = useState(0)
  const [hasMore, setHasMore] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingMore, setIsLoadingMore] = useState(false)
  const [error, setError] = useState("")

  async function fetchProducts(pageNumber = 1, reset = false, searchOverride?: string) {
    if (!categoryId || !isObjectId(categoryId)) return
    if (reset) setIsLoading(true)
    else setIsLoadingMore(true)

    const search = typeof searchOverride === "string" ? searchOverride : searchQuery
    try {
      const query = new URLSearchParams({ categoryId, page: String(pageNumber), limit: "20" })
      if (search.trim()) query.set("search", search.trim())
      const response = await apiFetch(`/staff/products?${query.toString()}`)
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Failed to load category products")

      const items = data.data || []
      const pagination = data.pagination || {}
      setProducts((current) => reset || pageNumber === 1 ? items : [...current, ...items])
      setPage(pageNumber)
      setTotalProducts(pagination.total || items.length)
      setHasMore(Boolean(pagination.hasNext))
    } catch (fetchError: any) {
      toast.error(fetchError.message || "Failed to load category products")
    } finally {
      setIsLoading(false)
      setIsLoadingMore(false)
    }
  }

  const isValidCategory = isObjectId(categoryId)

  useEffect(() => {
    if (!isValidCategory) return

    let active = true
    async function load() {
      try {
        const response = await apiFetch(`/categories/${categoryId}`, { skipAuth: true })
        const data = await response.json()
        if (!response.ok) throw new Error(data.message || "Category not found")
        if (active) setCategory(data.data || null)
      } catch (loadError: any) {
        if (active) setError(loadError.message || "Category not found")
      }
    }

    void load()
    void fetchProducts(1, true, "")
    return () => { active = false }
    // The category ID is the route identity; fetch helpers intentionally use initial search state.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categoryId])

  function submitSearch(event: FormEvent) {
    event.preventDefault()
    void fetchProducts(1, true)
  }

  if (!isValidCategory || error) return <div className="flex min-h-[360px] flex-col items-center justify-center rounded-2xl border border-[#d5d6e8] bg-white p-6 text-center"><FolderTree className="mb-3 h-10 w-10 text-slate-300" /><h1 className="text-lg font-bold text-slate-800">Category unavailable</h1><p className="mt-1 text-sm text-slate-500">{!isValidCategory ? "The category URL is invalid." : error}</p><Link href="/member/products" className="mt-5"><Button variant="outline"><ArrowLeft className="mr-2 h-4 w-4" />Back to products</Button></Link></div>

  const company = typeof category?.company === "object" ? category.company?.name : category?.company
  return <div className="space-y-6"><nav className="flex items-center gap-2 text-xs text-slate-500"><Link href="/member/products" className="hover:text-indigo-700">Products</Link><span>/</span><span className="truncate text-slate-800">{category?.name || "Category"}</span></nav><section className="rounded-2xl border border-[#d5d6e8] bg-white p-5 shadow-sm"><div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"><div className="flex min-w-0 gap-4">{category?.image?.url ? <img src={category.image.url} alt={category.name} className="h-16 w-16 rounded-2xl object-cover" /> : <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-[#e8e8f5]"><FolderTree className="h-7 w-7 text-slate-500" /></div>}<div><h1 className="text-2xl font-bold text-slate-900">{category?.name || "Loading category..."}</h1>{category?.nameHindi && <p className="mt-0.5 text-sm text-indigo-700">{category.nameHindi}</p>}{company && <p className="mt-1 text-sm text-slate-500">{company}</p>}{category?.description && <p className="mt-2 max-w-2xl text-sm text-slate-500">{category.description}</p>}<p className="mt-3 text-sm text-slate-600"><span className="font-bold text-slate-900">{totalProducts}</span> product{totalProducts === 1 ? "" : "s"} in this category</p></div></div><Link href="/member/products"><Button variant="outline" className="border-[#cacbdf] bg-white"><ArrowLeft className="mr-2 h-4 w-4" />All categories</Button></Link></div></section><form onSubmit={submitSearch} className="flex flex-col gap-3 sm:flex-row sm:items-center"><div className="relative w-full sm:max-w-md"><Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" /><Input value={searchQuery} onChange={(event) => setSearchQuery(event.target.value)} placeholder="Search this category..." className="h-10 border-[#cacbdf] bg-white pl-10" /></div><Button type="submit" variant="outline" className="h-10 border-[#cacbdf] bg-white">Search</Button>{searchQuery && <Button type="button" variant="ghost" className="h-10 text-slate-500" onClick={() => { setSearchQuery(""); void fetchProducts(1, true, "") }}>Clear</Button>}</form>{isLoading ? <div className="flex min-h-72 items-center justify-center rounded-2xl border border-[#d5d6e8] bg-white"><Loader2 className="h-8 w-8 animate-spin text-indigo-600" /></div> : products.length === 0 ? <div className="flex min-h-72 flex-col items-center justify-center rounded-2xl border border-[#d5d6e8] bg-white text-slate-500"><Package className="mb-3 h-10 w-10 text-slate-300" /><p className="text-sm">No products found in this category</p></div> : <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">{products.map((product) => <ProductCard key={product._id} product={product} />)}</div>}{hasMore && <div className="flex justify-center"><Button variant="outline" className="border-[#cacbdf] bg-white" disabled={isLoadingMore} onClick={() => void fetchProducts(page + 1)}>{isLoadingMore && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Load more products</Button></div>}</div>
}
