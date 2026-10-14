import { useCallback, useEffect, useRef } from "react"
import { apiFetch } from "@/lib/api"

// After an immediate price change, the backend waits until the admin has
// stopped saving for 100 seconds, then tells app users once. This nudges it
// just after that quiet period while the page is open (the API also sends it
// on its own with the next request it receives).
const QUIET_MS = 100_000
const NUDGE_AFTER_MS = QUIET_MS + 5_000

export function usePriceUpdateNudge() {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => () => {
    if (timer.current) clearTimeout(timer.current)
  }, [])

  return useCallback(() => {
    if (timer.current) clearTimeout(timer.current)
    timer.current = setTimeout(() => {
      timer.current = null
      apiFetch("/admin/price-updates/flush", { method: "POST" }).catch(() => {})
    }, NUDGE_AFTER_MS)
  }, [])
}
