"use client"

import { useDemoInfo } from "@/lib/demo"

// Persistent strip shown above the dashboard and staff panel. If /demo/info is
// unreachable the static text is still shown.
export function DemoBanner() {
  const { info } = useDemoInfo()
  const seeded = info?.seededAt ? new Date(info.seededAt) : null
  const seededLabel = seeded && !Number.isNaN(seeded.getTime()) ? ` (data seeded ${seeded.toLocaleString()})` : ""

  return (
    <div role="status" className="shrink-0 bg-indigo-700 px-4 py-1.5 text-center text-xs font-semibold tracking-wide text-white">
      Demonstration Environment — synthetic data{seededLabel}
    </div>
  )
}
