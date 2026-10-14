"use client"

import { useCallback, useEffect, useState } from "react"
import { ArrowUpRight, CheckCircle2, Clock, Loader2 } from "@/components/hugeicons"
import Link from "next/link"
import { apiFetch } from "@/lib/api"

interface Order {
  _id: string
  orderNumber: string
  customerSnapshot: { name: string }
  total: number
  status: string
  createdAt: string
  payment?: { status: string }
}

export function RecentOrders() {
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchOrders = useCallback(async () => {
    setIsLoading(true)
    setError(null)

    try {
      const res = await apiFetch("/admin/orders?limit=6")
      const contentType = res.headers.get("content-type") || ""
      if (!contentType.includes("application/json")) {
        throw new Error(`Unexpected API response (${res.status})`)
      }

      const json = await res.json()
      if (!res.ok) {
        throw new Error(json?.message || `Failed to load recent orders (${res.status})`)
      }

      setOrders(Array.isArray(json.data) ? json.data.slice(0, 6) : [])
    } catch (error: unknown) {
      setOrders([])
      setError(error instanceof Error ? error.message : "Failed to load recent orders")
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    void fetchOrders()
  }, [fetchOrders])

  function formatDate(dateStr: string) {
    return new Date(dateStr).toLocaleDateString("en-IN", { month: "short", day: "numeric", year: "numeric" })
  }

  function getStatusStyle(status: string) {
    switch (status) {
      case "delivered":
      case "payment_verified":
        return "bg-green-500/10 text-green-600"
      case "processing":
      case "payment_uploaded":
        return "bg-blue-500/10 text-blue-600"
      case "shipped":
        return "bg-violet-500/10 text-violet-600"
      case "pending_payment":
        return "bg-amber-500/10 text-amber-600"
      case "cancelled":
        return "bg-red-500/10 text-red-500"
      default:
        return "bg-slate-500/10 text-slate-500"
    }
  }

  function formatStatus(status: string) {
    return status.replace(/_/g, " ").replace(/\b\w/g, (char) => char.toUpperCase())
  }

  function getPaymentStatus(order: Order) {
    if (!order.payment) return order.status === "pending_payment" ? "pending" : "unknown"
    return order.payment.status
  }

  return (
    <section className="dashboard-surface flex min-h-[470px] flex-col rounded-3xl border border-slate-200 bg-white p-5 shadow-[0_18px_45px_rgba(37,99,235,0.08)] dark:border-slate-800 dark:bg-slate-900 dark:shadow-[0_18px_45px_rgba(0,0,0,0.25)] sm:p-6">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Operations</p>
          <h2 className="mt-1 text-xl font-bold text-slate-900">Recent orders</h2>
        </div>
        <Link href="/orders" className="inline-flex items-center gap-1 text-sm font-semibold text-blue-600 hover:text-blue-700">
          View all <ArrowUpRight className="h-4 w-4" />
        </Link>
      </div>

      <div className="mt-6 flex-1">
        {isLoading ? (
          <div className="flex h-full min-h-72 items-center justify-center">
            <Loader2 className="h-6 w-6 animate-spin text-blue-600" />
          </div>
        ) : error ? (
          <div className="flex h-full min-h-72 flex-col items-center justify-center rounded-2xl dashboard-subtle-surface bg-slate-50 px-6 text-center">
            <p className="font-semibold text-slate-900">Recent orders are unavailable</p>
            <p className="mt-2 max-w-sm text-sm text-slate-500">{error}</p>
            <button
              type="button"
              onClick={() => void fetchOrders()}
              className="mt-4 rounded-lg bg-blue-600 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-700"
            >
              Try again
            </button>
          </div>
        ) : orders.length === 0 ? (
          <div className="flex h-full min-h-72 flex-col items-center justify-center rounded-2xl dashboard-subtle-surface bg-slate-50 px-6 text-center">
            <p className="font-semibold text-slate-900">No recent orders</p>
            <p className="mt-2 text-sm text-slate-500">New orders will appear here as they are placed.</p>
            <Link href="/orders" className="mt-4 text-sm font-semibold text-blue-600 hover:text-blue-700">Open orders</Link>
          </div>
        ) : (
          <>
            <div className="space-y-3 md:hidden">
              {orders.map((order) => {
                const payStatus = getPaymentStatus(order)
                return (
                  <div key={order._id} className="rounded-2xl dashboard-subtle-surface bg-slate-50 p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="text-sm font-semibold text-slate-900">{order.orderNumber}</div>
                        <div className="mt-1 text-xs text-slate-500">{formatDate(order.createdAt)}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-sm font-bold text-slate-900">Rs. {order.total.toLocaleString("en-IN")}</div>
                        <span className={`mt-2 inline-flex rounded-full px-3 py-1 text-xs font-medium ${getStatusStyle(order.status)}`}>
                          {formatStatus(order.status)}
                        </span>
                      </div>
                    </div>
                    <div className="mt-3 text-sm text-slate-700">{order.customerSnapshot?.name || "-"}</div>
                    <div className="mt-3 flex items-center justify-between text-xs">
                      {payStatus === "verified" ? (
                        <div className="flex items-center gap-1 text-emerald-600"><CheckCircle2 className="h-4 w-4" /> Verified</div>
                      ) : (
                        <div className="flex items-center gap-1 text-amber-600"><Clock className="h-4 w-4" /> {formatStatus(payStatus)}</div>
                      )}
                      <Link href="/orders" className="font-medium text-blue-600 hover:text-blue-700">Manage</Link>
                    </div>
                  </div>
                )
              })}
            </div>

            <div className="hidden h-full overflow-x-auto md:block">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 text-xs text-slate-500">
                    <th className="pb-3 text-left font-medium">Order</th>
                    <th className="pb-3 text-left font-medium">Customer</th>
                    <th className="pb-3 text-right font-medium">Amount</th>
                    <th className="pb-3 text-right font-medium">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((order) => (
                    <tr key={order._id} className="border-b border-slate-100 last:border-0">
                      <td className="py-4">
                        <p className="font-semibold text-slate-900">{order.orderNumber}</p>
                        <p className="mt-1 text-xs text-slate-500">{formatDate(order.createdAt)}</p>
                      </td>
                      <td className="py-4 text-slate-700">{order.customerSnapshot?.name || "-"}</td>
                      <td className="py-4 text-right font-semibold text-slate-900">Rs. {order.total.toLocaleString("en-IN")}</td>
                      <td className="py-4 text-right">
                        <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-medium ${getStatusStyle(order.status)}`}>
                          {formatStatus(order.status)}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>
    </section>
  )
}
