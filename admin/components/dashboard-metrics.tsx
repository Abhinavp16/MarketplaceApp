"use client"

import { useCallback, useEffect, useState } from "react"
import { Handshake, Loader2, ShoppingCart, Users, Wallet } from "@/components/hugeicons"
import { toast } from "sonner"
import { apiFetch } from "@/lib/api"

interface DashboardData {
  overview: {
    totalOrders: number
    pendingPayments: number
    totalRevenue: number
    activeNegotiations: number
    totalProducts: number
    totalCustomers: number
  }
  today: { orders: number; revenue: number }
  thisMonth: { orders: number; revenue: number }
}

export function DashboardMetrics() {
  const [data, setData] = useState<DashboardData | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchStats = useCallback(async () => {
    setIsLoading(true)
    setError(null)

    try {
      const res = await apiFetch("/admin/analytics/dashboard")
      const contentType = res.headers.get("content-type") || ""

      if (!contentType.includes("application/json")) {
        throw new Error(`Unexpected API response (${res.status})`)
      }

      const json = await res.json()
      if (!res.ok || !json.success) {
        throw new Error(json?.message || `Failed to load dashboard stats (${res.status})`)
      }

      setData(json.data)
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Failed to load dashboard stats"
      setData(null)
      setError(message)
      toast.error(message)
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    void fetchStats()
  }, [fetchStats])

  function formatCurrency(amount: number) {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      maximumFractionDigits: 0,
    }).format(amount)
  }

  if (isLoading) {
    return (
      <section className="flex min-h-48 items-center justify-center rounded-3xl border border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900 p-6 shadow-[0_18px_45px_rgba(37,99,235,0.08)]">
        <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
      </section>
    )
  }

  if (error) {
    return (
      <section className="flex min-h-48 flex-col items-center justify-center gap-3 rounded-3xl border border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900 p-6 text-center shadow-[0_18px_45px_rgba(37,99,235,0.08)]">
        <p className="font-semibold text-slate-900">Dashboard metrics are unavailable</p>
        <p className="max-w-md text-sm text-slate-500">{error}</p>
        <button
          type="button"
          onClick={() => void fetchStats()}
          className="rounded-lg bg-blue-600 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-700"
        >
          Try again
        </button>
      </section>
    )
  }

  const overview = data?.overview
  const today = data?.today
  const metricTiles = [
    {
      label: "Total orders",
      value: (overview?.totalOrders ?? 0).toLocaleString(),
      detail: today && today.orders > 0 ? `+${today.orders} today` : "All time",
      Icon: ShoppingCart,
      valueClass: "text-slate-900",
      iconClass: "bg-blue-50 text-blue-600",
    },
    {
      label: "Customers",
      value: (overview?.totalCustomers ?? 0).toLocaleString(),
      detail: "Registered buyers",
      Icon: Users,
      valueClass: "text-blue-600",
      iconClass: "bg-sky-50 text-sky-600",
    },
    {
      label: "Open Requirements",
      value: (overview?.activeNegotiations ?? 0).toLocaleString(),
      detail: "Active requirements",
      Icon: Handshake,
      valueClass: "text-amber-600",
      iconClass: "bg-amber-50 text-amber-600",
    },
    {
      label: "Pending payments",
      value: (overview?.pendingPayments ?? 0).toLocaleString(),
      detail: "Need attention",
      Icon: Wallet,
      valueClass: "text-orange-600",
      iconClass: "bg-orange-50 text-orange-600",
    },
  ]

  return (
    <section className="dashboard-surface rounded-3xl border border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900 p-5 shadow-[0_18px_45px_rgba(37,99,235,0.08)] sm:p-6">
      <div className="flex flex-col gap-6 xl:flex-row xl:items-center xl:justify-between">
        <div className="min-w-0 xl:max-w-sm">
          <div className="flex items-center gap-2 text-sm font-medium text-slate-500">
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-50 text-blue-600">
              <Wallet className="h-4 w-4" />
            </span>
            Total revenue
          </div>
          <p className="mt-3 text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
            {formatCurrency(overview?.totalRevenue ?? 0)}
          </p>
          <p className="mt-2 text-sm text-slate-500">
            {today && today.revenue > 0 ? `+${formatCurrency(today.revenue)} collected today` : "No revenue collected today"}
          </p>
        </div>

        <div className="grid w-full grid-cols-2 gap-3 sm:grid-cols-4 xl:max-w-3xl">
          {metricTiles.map(({ label, value, detail, Icon, valueClass, iconClass }) => (
            <div key={label} className="dashboard-metric-tile min-w-0 rounded-2xl bg-slate-50/80 p-4">
              <span className={`flex h-8 w-8 items-center justify-center rounded-lg ${iconClass}`}>
                <Icon className="h-4 w-4" />
              </span>
              <p className="mt-4 truncate text-xs font-medium text-slate-500">{label}</p>
              <p className={`mt-1 text-xl font-bold ${valueClass}`}>{value}</p>
              <p className="mt-1 truncate text-xs text-slate-400">{detail}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
