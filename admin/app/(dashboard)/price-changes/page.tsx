"use client"

import Link from "next/link"
import { Clock3, Loader2, RefreshCw, Search } from "@/components/hugeicons"
import { useCallback, useEffect, useState } from "react"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { toast } from "sonner"
import { apiFetch } from "@/lib/api"

type PriceChangeRow = {
  id: string
  productId: string
  productName: string
  productSku: string
  category: string
  oldRetailPrice: number
  newRetailPrice: number | null
  oldWholesalePrice: number
  newWholesalePrice: number | null
  scheduledAt: string | null
  effectiveAt: string | null
}

function formatPrice(value: number | null | undefined) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return "-"
  }

  return `₹${Number(value).toLocaleString("en-IN", { maximumFractionDigits: 0 })}`
}

function formatDateTime(value: string | null) {
  if (!value) return "-"

  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) return "-"

  return parsed.toLocaleString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })
}

function getTimeLeft(value: string | null) {
  if (!value) return "Ready soon"

  const effectiveAt = new Date(value)
  if (Number.isNaN(effectiveAt.getTime())) return "-"

  const diffMs = effectiveAt.getTime() - Date.now()
  if (diffMs <= 0) return "Due now"

  const totalMinutes = Math.floor(diffMs / (1000 * 60))
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60

  if (hours <= 0) return `${minutes}m left`
  return `${hours}h ${minutes.toString().padStart(2, "0")}m left`
}

export default function PriceChangesPage() {
  const [rows, setRows] = useState<PriceChangeRow[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const [appliedSearchQuery, setAppliedSearchQuery] = useState("")

  const fetchPriceChanges = useCallback(async (showRefreshState = false) => {
    if (showRefreshState) {
      setIsRefreshing(true)
    } else {
      setIsLoading(true)
    }

    try {
      const params = new URLSearchParams()
      params.set("page", "1")
      params.set("limit", "200")
      if (appliedSearchQuery.trim()) {
        params.set("search", appliedSearchQuery.trim())
      }

      const response = await apiFetch(`/admin/price-changes?${params.toString()}`)
      const data = await response.json()

      if (!response.ok) {
        throw new Error(data?.message || "Failed to fetch price changes")
      }

      setRows(Array.isArray(data.data) ? data.data : [])
    } catch (error: any) {
      console.error(error)
      toast.error(error?.message || "Unable to load scheduled price changes")
    } finally {
      setIsLoading(false)
      setIsRefreshing(false)
    }
  }, [appliedSearchQuery])

  useEffect(() => {
    fetchPriceChanges()
  }, [fetchPriceChanges])

  const totalRows = rows.length
  const pendingProducts = rows.length

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Price Changes</h1>
          <p className="text-slate-500">
            Review scheduled product price updates before they go live.
          </p>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center">
          <div className="rounded-2xl border border-[#d8dfca] bg-white px-4 py-3 text-sm text-slate-600 shadow-sm">
            {pendingProducts} products | {totalRows} pending changes
          </div>
          <Button
            type="button"
            variant="outline"
            onClick={() => fetchPriceChanges(true)}
            disabled={isRefreshing}
            className="border-[#d8dfca] bg-white text-slate-700 hover:bg-[#f6f8ef] hover:text-slate-900"
          >
            {isRefreshing ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <RefreshCw className="mr-2 h-4 w-4" />
            )}
            Refresh
          </Button>
        </div>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative w-full sm:max-w-md">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <Input
            value={searchQuery}
          onChange={(event) => setSearchQuery(event.target.value)}
          placeholder="Search by product, SKU, category"
          className="border-[#d8dfca] bg-white pl-9 text-slate-900 placeholder:text-slate-400"
        />
      </div>
      <Button
        type="button"
        onClick={() => {
          if (searchQuery === appliedSearchQuery) {
            fetchPriceChanges(true)
            return
          }
          setAppliedSearchQuery(searchQuery)
        }}
        className="bg-[#86efac] text-slate-900 hover:bg-[#73e39c]"
      >
        Search
      </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <div className="rounded-[24px] border border-[#dde3d0] bg-white px-5 py-4 shadow-[0_20px_45px_rgba(60,80,40,0.06)]">
          <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">Pending Rows</div>
          <div className="mt-2 text-3xl font-bold text-slate-900">{totalRows}</div>
        </div>
        <div className="rounded-[24px] border border-[#dde3d0] bg-white px-5 py-4 shadow-[0_20px_45px_rgba(60,80,40,0.06)]">
          <div className="text-xs font-semibold uppercase tracking-[0.22em] text-slate-500">Products</div>
          <div className="mt-2 text-3xl font-bold text-slate-900">{pendingProducts}</div>
        </div>
      </div>

      <div className="rounded-[28px] border border-[#dde3d0] bg-white shadow-[0_24px_60px_rgba(60,80,40,0.08)]">
        <div className="flex items-center justify-between border-b border-[#eef2e2] px-5 py-4">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">Scheduled Price Updates</h2>
            <p className="text-sm text-slate-500">
              Live price stays active until the scheduled go-live time.
            </p>
          </div>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center px-6 py-16 text-slate-500">
            <Loader2 className="mr-3 h-5 w-5 animate-spin" />
            Loading scheduled price changes...
          </div>
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-3 px-6 py-16 text-center">
            <div className="rounded-full bg-[#f6f8ef] p-4 text-slate-500">
              <Clock3 className="h-7 w-7" />
            </div>
            <div className="text-lg font-semibold text-slate-900">No pending price changes</div>
            <p className="max-w-md text-sm text-slate-500">
              Once an admin saves a product using the 24-hour schedule mode, it will show up here with the old and upcoming prices.
            </p>
          </div>
        ) : (
          <>
            <div className="hidden overflow-x-auto lg:block">
              <Table>
                <TableHeader>
                  <TableRow className="border-[#eef2e2]">
                    <TableHead>Product</TableHead>
                    <TableHead>Old Customer</TableHead>
                    <TableHead>New Customer</TableHead>
                    <TableHead>Old Wholesale</TableHead>
                    <TableHead>New Wholesale</TableHead>
                    <TableHead>Scheduled On</TableHead>
                    <TableHead>Goes Live</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((row) => (
                    <TableRow key={row.id} className="border-[#eef2e2]">
                      <TableCell>
                        <div className="min-w-[220px]">
                          <div className="font-semibold text-slate-900">{row.productName}</div>
                          <div className="mt-1 text-xs text-slate-500">
                            {row.category || row.productSku || "Base product"}
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>{formatPrice(row.oldRetailPrice)}</TableCell>
                      <TableCell className="font-semibold text-emerald-700">{formatPrice(row.newRetailPrice)}</TableCell>
                      <TableCell>{formatPrice(row.oldWholesalePrice)}</TableCell>
                      <TableCell className="font-semibold text-emerald-700">{formatPrice(row.newWholesalePrice)}</TableCell>
                      <TableCell>{formatDateTime(row.scheduledAt)}</TableCell>
                      <TableCell>
                        <div className="font-medium text-slate-900">{formatDateTime(row.effectiveAt)}</div>
                        <div className="text-xs text-slate-500">{getTimeLeft(row.effectiveAt)}</div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            <div className="grid gap-4 p-4 lg:hidden">
              {rows.map((row) => (
                <div
                  key={row.id}
                  className="rounded-[24px] border border-[#e6ebd8] bg-[#fbfcf7] p-4 shadow-sm"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="font-semibold text-slate-900">{row.productName}</div>
                      <div className="mt-1 text-sm text-slate-500">
                        {row.category || row.productSku || "Base product"}
                      </div>
                    </div>
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-3 text-sm">
                    <div className="rounded-2xl border border-[#e6ebd8] bg-white px-3 py-3">
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Old Customer</div>
                      <div className="mt-1 font-semibold text-slate-900">{formatPrice(row.oldRetailPrice)}</div>
                    </div>
                    <div className="rounded-2xl border border-[#d9f3dd] bg-[#f2fcf4] px-3 py-3">
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-emerald-600">New Customer</div>
                      <div className="mt-1 font-semibold text-emerald-700">{formatPrice(row.newRetailPrice)}</div>
                    </div>
                    <div className="rounded-2xl border border-[#e6ebd8] bg-white px-3 py-3">
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">Old Wholesale</div>
                      <div className="mt-1 font-semibold text-slate-900">{formatPrice(row.oldWholesalePrice)}</div>
                    </div>
                    <div className="rounded-2xl border border-[#d9f3dd] bg-[#f2fcf4] px-3 py-3">
                      <div className="text-xs font-semibold uppercase tracking-[0.18em] text-emerald-600">New Wholesale</div>
                      <div className="mt-1 font-semibold text-emerald-700">{formatPrice(row.newWholesalePrice)}</div>
                    </div>
                  </div>

                  <div className="mt-4 rounded-2xl border border-[#e6ebd8] bg-white px-3 py-3 text-sm">
                    <div className="flex items-center justify-between gap-3">
                      <span className="text-slate-500">Scheduled On</span>
                      <span className="font-medium text-slate-900">{formatDateTime(row.scheduledAt)}</span>
                    </div>
                    <div className="mt-2 flex items-center justify-between gap-3">
                      <span className="text-slate-500">Goes Live</span>
                      <div className="text-right">
                        <div className="font-medium text-slate-900">{formatDateTime(row.effectiveAt)}</div>
                        <div className="text-xs text-slate-500">{getTimeLeft(row.effectiveAt)}</div>
                      </div>
                    </div>
                  </div>

                  <div className="mt-4">
                    <Link
                      href={`/products/add?edit=${row.productId}`}
                      className="inline-flex items-center justify-center rounded-xl border border-[#d8dfca] bg-white px-4 py-2 text-sm font-medium text-slate-700 transition hover:bg-[#f6f8ef]"
                    >
                      Open Product
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  )
}
