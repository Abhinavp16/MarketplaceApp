import { DashboardMetrics } from "@/components/dashboard-metrics"
import { PerformanceChart } from "@/components/performance-chart"
import { RecentOrders } from "@/components/recent-orders"

export default function Dashboard() {
  return (
    <div className="mx-auto flex w-full max-w-[1600px] flex-col gap-6 pb-4 lg:gap-8">
      <header className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-blue-600 dark:text-blue-300">Command Center</p>
          <h1 className="mt-1 text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-3xl">Business overview</h1>
          <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">Monitor revenue, customer activity, and orders from one place.</p>
        </div>
        <div className="inline-flex w-fit items-center gap-2 rounded-full bg-blue-50 px-3 py-1.5 text-xs font-semibold text-blue-700 dark:bg-blue-500/15 dark:text-blue-200">
          <span className="h-2 w-2 rounded-full bg-blue-500 dark:bg-blue-400" />
          Dashboard live
        </div>
      </header>

      <DashboardMetrics />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.55fr)_minmax(360px,0.85fr)] xl:items-stretch xl:gap-8">
        <PerformanceChart />
        <RecentOrders />
      </div>
    </div>
  )
}
