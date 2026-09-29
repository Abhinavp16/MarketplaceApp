"use client"

import { useCallback, useEffect, useState } from "react"
import { ChartSkeleton } from "@/components/ui/skeleton"
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts"
import { apiFetch } from "@/lib/api"

type PeriodKey = "7d" | "30d" | "90d" | "1y"

const periodMap: { label: string; value: PeriodKey; groupBy: string }[] = [
  { label: "7D", value: "7d", groupBy: "day" },
  { label: "1M", value: "30d", groupBy: "day" },
  { label: "3M", value: "90d", groupBy: "week" },
  { label: "1Y", value: "1y", groupBy: "month" },
]

interface ChartPoint {
  date: string
  revenue: number
  orders: number
}

export function PerformanceChart() {
  const [data, setData] = useState<ChartPoint[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [activePeriod, setActivePeriod] = useState<PeriodKey>("30d")
  const [error, setError] = useState<string | null>(null)

  const fetchSales = useCallback(async (periodValue: PeriodKey) => {
    const period = periodMap.find((entry) => entry.value === periodValue)
    if (!period) return

    setIsLoading(true)
    setError(null)

    try {
      const res = await apiFetch(`/admin/analytics/sales?period=${period.value}&groupBy=${period.groupBy}`)
      const contentType = res.headers.get("content-type") || ""

      if (!contentType.includes("application/json")) {
        throw new Error(`Unexpected API response (${res.status})`)
      }

      const json = await res.json()
      if (!res.ok || !json.success) {
        throw new Error(json?.message || `Failed to load sales data (${res.status})`)
      }

      const timeline = Array.isArray(json?.data?.timeline) ? json.data.timeline : []
      setData(
        timeline.map((point: ChartPoint) => ({
          date: point.date,
          revenue: Number(point.revenue) || 0,
          orders: Number(point.orders) || 0,
        })),
      )
    } catch (error: unknown) {
      setData([])
      setError(error instanceof Error ? error.message : "Failed to load sales data")
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    void fetchSales(activePeriod)
  }, [activePeriod, fetchSales])

  function formatCurrency(value: number) {
    if (value >= 100000) return `Rs. ${(value / 100000).toFixed(1)}L`
    if (value >= 1000) return `Rs. ${(value / 1000).toFixed(1)}K`
    return `Rs. ${value}`
  }

  const maxRevenue = data.length > 0 ? Math.max(...data.map((point) => point.revenue)) : 0
  const yMax = Math.ceil((maxRevenue * 1.2) / 100) * 100 || 1000

  return (
    <section className="dashboard-surface flex min-h-[470px] flex-col rounded-3xl border border-slate-200 bg-white p-5 shadow-[0_18px_45px_rgba(37,99,235,0.08)] dark:border-slate-800 dark:bg-slate-900 dark:shadow-[0_18px_45px_rgba(0,0,0,0.25)] sm:p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Performance</p>
          <h2 className="mt-1 text-xl font-bold text-slate-900">Sales overview</h2>
        </div>

        <div className="dashboard-period-selector flex w-fit items-center rounded-xl bg-slate-100 p-1">
          {periodMap.map((period) => (
            <button
              key={period.value}
              type="button"
              onClick={() => setActivePeriod(period.value)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors sm:text-sm ${
                activePeriod === period.value
                  ? "bg-white text-slate-900 shadow-sm"
                  : "text-slate-500 hover:text-slate-900"
              }`}
            >
              {period.label}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-6 h-[330px] w-full sm:h-[360px]">
        {isLoading ? (
          <ChartSkeleton className="h-full min-h-0" />
        ) : error ? (
          <div className="flex h-full flex-col items-center justify-center rounded-2xl dashboard-subtle-surface bg-slate-50 px-6 text-center">
            <p className="font-semibold text-slate-900">Sales data is unavailable</p>
            <p className="mt-2 max-w-sm text-sm text-slate-500">{error}</p>
            <button
              type="button"
              onClick={() => void fetchSales(activePeriod)}
              className="mt-4 rounded-lg bg-blue-600 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-700"
            >
              Try again
            </button>
          </div>
        ) : data.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center rounded-2xl dashboard-subtle-surface bg-slate-50 px-6 text-center">
            <p className="font-semibold text-slate-900">No sales data for this period</p>
            <p className="mt-2 text-sm text-slate-500">Completed orders will appear here once sales activity is recorded.</p>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 8, right: 8, left: -12, bottom: 0 }}>
              <defs>
                <linearGradient id="dashboardRevenueGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#2563eb" stopOpacity={0.28} />
                  <stop offset="95%" stopColor="#2563eb" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" vertical={false} />
              <XAxis
                dataKey="date"
                tick={{ fill: "#64748b", fontSize: 11 }}
                axisLine={false}
                tickLine={false}
                interval="preserveStartEnd"
              />
              <YAxis
                domain={[0, yMax]}
                tick={{ fill: "#64748b", fontSize: 11 }}
                axisLine={false}
                tickLine={false}
                tickFormatter={formatCurrency}
              />
              <Tooltip
                content={({ active, payload }) => {
                  if (!active || !payload?.length) return null
                  const point = payload[0].payload as ChartPoint
                  return (
                    <div className="rounded-xl bg-white p-3 shadow-xl ring-1 ring-slate-200">
                      <p className="font-semibold text-slate-900">Rs. {point.revenue.toLocaleString("en-IN")}</p>
                      <p className="mt-1 text-xs text-slate-500">{point.orders} orders · {point.date}</p>
                    </div>
                  )
                }}
              />
              <Area
                type="monotone"
                dataKey="revenue"
                stroke="#2563eb"
                strokeWidth={2.5}
                fillOpacity={1}
                fill="url(#dashboardRevenueGradient)"
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
    </section>
  )
}
