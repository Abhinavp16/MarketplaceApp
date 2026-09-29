"use client"

import { motion } from "framer-motion"
import { cn } from "@/lib/utils"

type SkeletonProps = React.ComponentProps<typeof motion.div>

export function Skeleton({ className, ...props }: SkeletonProps) {
  return (
    <motion.div
      data-slot="skeleton"
      className={cn("rounded-md bg-blue-100/90 dark:bg-blue-950/45", className)}
      animate={{ opacity: [0.55, 1, 0.55] }}
      transition={{ duration: 1.4, repeat: Infinity, ease: "easeInOut" }}
      {...props}
    />
  )
}

export function DashboardPageSkeleton() {
  return (
    <div className="space-y-6" aria-label="Loading dashboard content" aria-busy="true">
      <div className="flex items-center justify-between gap-4">
        <div className="space-y-2"><Skeleton className="h-8 w-44" /><Skeleton className="h-4 w-64" /></div>
        <Skeleton className="h-9 w-28" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }).map((_, index) => <Skeleton className="h-28" key={index} />)}
      </div>
      <div className="grid gap-6 xl:grid-cols-[1.5fr_1fr]">
        <Skeleton className="h-80" />
        <Skeleton className="h-80" />
      </div>
    </div>
  )
}

export function TableSkeleton({ rows = 5, columns = 4 }: { rows?: number; columns?: number }) {
  return (
    <div className="space-y-3" aria-label="Loading table" aria-busy="true">
      {Array.from({ length: rows }).map((_, rowIndex) => (
        <div className="grid gap-3" style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }} key={rowIndex}>
          {Array.from({ length: columns }).map((__, columnIndex) => <Skeleton className="h-10" key={columnIndex} />)}
        </div>
      ))}
    </div>
  )
}

export function ChartSkeleton({ className }: { className?: string }) {
  return (
    <div className={cn("relative h-full min-h-64 overflow-hidden rounded-xl border border-blue-100 bg-white/80 p-5 dark:border-blue-950/50 dark:bg-slate-950/30", className)} aria-label="Loading chart" aria-busy="true">
      <div className="flex h-full items-end gap-3">
        {[45, 72, 56, 85, 63, 92, 76, 100].map((height, index) => <Skeleton className="flex-1" style={{ height: `${height}%` }} key={index} />)}
      </div>
    </div>
  )
}

export function MapSkeleton() {
  return (
    <div className="relative h-[42vh] overflow-hidden rounded-xl border border-blue-100 bg-blue-50/70 dark:border-blue-950/50 dark:bg-slate-950/30 sm:h-[50vh] lg:h-[65vh]" aria-label="Loading map" aria-busy="true">
      <Skeleton className="absolute left-[18%] top-[22%] h-4 w-4 rounded-full" />
      <Skeleton className="absolute left-[62%] top-[38%] h-4 w-4 rounded-full" />
      <Skeleton className="absolute left-[40%] top-[66%] h-4 w-4 rounded-full" />
      <Skeleton className="absolute bottom-6 left-6 h-16 w-40" />
    </div>
  )
}

export function FormSkeleton() {
  return (
    <div className="space-y-6" aria-label="Loading form" aria-busy="true">
      {Array.from({ length: 4 }).map((_, index) => (
        <div className="space-y-3 rounded-xl border border-blue-100 bg-white/80 p-6 dark:border-blue-950/50 dark:bg-slate-950/30" key={index}>
          <Skeleton className="h-5 w-40" />
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
        </div>
      ))}
    </div>
  )
}
