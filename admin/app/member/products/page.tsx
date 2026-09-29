"use client"
/* eslint-disable @next/next/no-img-element */

import Link from "next/link"
import { FormEvent, useEffect, useState } from "react"
import { apiFetch } from "@/lib/api"
import { type EffectivePricing, type EffectiveRolePricing } from "@/lib/discount"
import { toast } from "sonner"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { FolderTree, Loader2, Package, Search } from "@/components/hugeicons"

type Category = {
  _id: string
  name: string
  nameHindi?: string
  slug: string
  description?: string
  image?: { url?: string }
  company?: { name?: string } | string | null
  productCount?: number
  isActive?: boolean
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

function categoryCompany(category: Category) {
  return typeof category.company === "object" ? category.company?.name : category.company
}

function ProductCard({ product }: { product: Product }) {
  const image = productImage(product)
  const stock = Number(product.stock || 0)

  return <article className="catalog-card-borderless flex min-h-[280px] flex-col rounded-[22px] bg-white p-4 shadow-[0_12px_32px_rgba(50,58,110,0.07)]"><div className="mb-4 flex items-start justify-between gap-3">{image ? <img src={image} alt={product.name} className="h-12 w-12 rounded-xl object-cover" /> : <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-[#e8e8f5]"><Package className="h-5 w-5 text-slate-500" /></div>}<Badge variant="outline" className={`capitalize ${product.status === "active" ? "border-indigo-200 bg-indigo-50 text-indigo-700" : "border-slate-200 bg-slate-100 text-slate-600"}`}>{product.status}</Badge></div><h2 className="line-clamp-2 text-sm font-bold leading-5 text-slate-900">{product.name}</h2>{product.nameHindi && <p className="mt-1 line-clamp-1 text-xs text-slate-500">{product.nameHindi}</p>}<p className="mt-1.5 truncate text-[10px] text-slate-500">SKU: {product.sku || "—"}</p><div className="mt-3 flex flex-wrap gap-1.5"><span className="max-w-full truncate rounded-full border border-[#dce7ef] bg-[#f4f9fc] px-2 py-0.5 text-[10px] text-slate-600">{product.category || "Uncategorized"}</span>{product.packing && <span className="rounded-full border border-[#d8d9ea] bg-[#f0f0f9] px-2 py-0.5 text-[10px] text-slate-600">{product.packing}</span>}</div><div className="mt-auto grid grid-cols-2 gap-3 border-t border-[#e7e7f0] pt-4"><div><p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">Customer price</p><p className="mt-1 text-sm font-bold text-blue-600">{formatPrice(sellingPrice(product.effectivePricing?.buyer, product.retailPrice))}</p><DiscountNote pricing={product.effectivePricing?.buyer} /></div><div className="border-l border-[#e7e7f0] pl-3"><p className="text-[10px] font-semibold uppercase tracking-wide text-slate-400">Wholesaler price</p><p className="mt-1 text-sm font-bold text-indigo-700">{formatPrice(sellingPrice(product.effectivePricing?.wholesaler, product.wholesalePrice))}</p><DiscountNote pricing={product.effectivePricing?.wholesaler} /></div></div><p className="mt-3 text-right text-[10px] text-slate-500">Stock <span className="font-semibold text-slate-800">{stock.toLocaleString("en-IN")}{product.priceUnit ? ` ${product.priceUnit}` : ""}</span></p></article>
}

export default function MemberProductsPage() {
  const [categories, setCategories] = useState<Category[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingMore, setIsLoadingMore] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const [page, setPage] = useState(1)
  const [totalProducts, setTotalProducts] = useState(0)
  const [hasMore, setHasMore] = useState(false)

  async function fetchProducts(pageNumber = 1, reset = false, searchOverride?: string) {
    if (reset) setIsLoading(true)
    else setIsLoadingMore(true)

    const search = typeof searchOverride === "string" ? searchOverride : searchQuery
    try {
      const params = new URLSearchParams({ page: String(pageNumber), limit: "20" })
      if (search.trim()) params.set("search", search.trim())

      const response = await apiFetch(`/staff/products?${params.toString()}`)
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Failed to fetch products")

      const items = data.data || []
      const pagination = data.pagination || {}
      setProducts((previous) => reset || pageNumber === 1 ? items : [...previous, ...items])
      setPage(pageNumber)
      setTotalProducts(pagination.total || items.length)
      setHasMore(Boolean(pagination.hasNext))
    } catch (error: any) {
      toast.error(error.message || "Failed to fetch products")
    } finally {
      setIsLoading(false)
      setIsLoadingMore(false)
    }
  }

  async function fetchCategories() {
    try {
      const response = await apiFetch("/categories?page=1&limit=200", { skipAuth: true })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Failed to load categories")
      setCategories(data.data || [])
    } catch (error: any) {
      toast.error(error.message || "Failed to load categories")
    }
  }

  // The initial requests intentionally use the initial search state only.
  // eslint-disable-next-line react-hooks/set-state-in-effect, react-hooks/exhaustive-deps
  useEffect(() => { void Promise.all([fetchProducts(1, true), fetchCategories()]) }, [])

  function submitSearch(event: FormEvent) {
    event.preventDefault()
    void fetchProducts(1, true)
  }

  return <div className="space-y-8"><div><h1 className="text-3xl font-bold tracking-tight text-slate-900">Products</h1><p className="mt-1 text-sm text-slate-500">View the product catalog, customer prices, and wholesaler prices.{totalProducts > 0 ? ` (${totalProducts} products)` : ""}</p></div><form onSubmit={submitSearch} className="flex flex-col gap-3 sm:flex-row sm:items-center"><div className="relative w-full sm:max-w-md"><Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" /><Input value={searchQuery} onChange={(event) => setSearchQuery(event.target.value)} placeholder="Search products by name or SKU..." className="h-10 border-[#cacbdf] bg-white pl-10 text-slate-800 placeholder:text-slate-400 focus-visible:ring-[#818cf8]" /></div><Button type="submit" variant="outline" className="h-10 border-[#cacbdf] bg-white text-slate-700 hover:bg-[#ececf8]">Search</Button>{searchQuery && <Button type="button" variant="ghost" className="h-10 text-slate-500" onClick={() => { setSearchQuery(""); void fetchProducts(1, true, "") }}>Clear</Button>}</form><section><div className="mb-3 flex items-center justify-between"><div><h2 className="text-base font-bold text-slate-800">Browse by category</h2><p className="text-xs text-slate-500">Choose a category to view its product list.</p></div></div>{categories.length === 0 ? <div className="flex h-24 items-center justify-center rounded-2xl border border-dashed border-[#cacbdf] text-sm text-slate-500">Categories are loading or unavailable.</div> : <div className="flex gap-3 overflow-x-auto pb-1">{categories.map((category) => <Link key={category._id} href={`/member/products/${category._id}`} className={`group w-36 shrink-0 rounded-2xl border bg-white p-3 shadow-sm transition hover:-translate-y-0.5 hover:border-indigo-300 hover:shadow-md ${category.isActive === false ? "opacity-60" : "border-[#d5d6e8]"}`}><div className="flex items-start justify-between gap-2">{category.image?.url ? <img src={category.image.url} alt="" className="h-10 w-10 rounded-xl object-cover" /> : <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-[#e8e8f5]"><FolderTree className="h-5 w-5 text-slate-500" /></div>}<span className="text-[10px] font-semibold text-slate-400">{category.productCount || 0}</span></div><p className="mt-3 line-clamp-1 text-xs font-bold text-slate-800 group-hover:text-indigo-700">{category.name}</p>{category.nameHindi && <p className="mt-0.5 line-clamp-1 text-[10px] text-slate-500">{category.nameHindi}</p>}<p className="mt-1 line-clamp-1 text-[10px] text-slate-400">{categoryCompany(category) || "Category"}</p></Link>)}</div>}</section><section><div className="mb-3 flex items-center justify-between"><div><h2 className="text-base font-bold text-slate-800">All Products</h2><p className="text-xs text-slate-500">Read-only catalog view.</p></div></div>{isLoading ? <div className="flex min-h-72 items-center justify-center rounded-2xl border border-[#d5d6e8] bg-white"><Loader2 className="h-8 w-8 animate-spin text-indigo-600" /></div> : products.length === 0 ? <div className="flex min-h-72 flex-col items-center justify-center rounded-2xl border border-[#d5d6e8] bg-white text-slate-500"><Package className="mb-3 h-10 w-10 text-slate-300" /><p className="text-sm">No products found</p></div> : <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">{products.map((product) => <ProductCard key={product._id} product={product} />)}</div>}</section>{hasMore && <div className="flex justify-center"><Button variant="outline" className="border-[#cacbdf] bg-white" disabled={isLoadingMore} onClick={() => void fetchProducts(page + 1)}>{isLoadingMore && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Load more products</Button></div>}</div>
}
