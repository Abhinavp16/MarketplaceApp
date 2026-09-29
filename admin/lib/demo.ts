"use client"

import { useEffect, useState } from "react"
import { apiFetch } from "@/lib/api"

export interface DemoInfo {
  demoMode: boolean
  brand?: string
  version?: string
  seededAt?: string
}

// GET /demo/info (public). Resolves to null when the endpoint is unreachable.
export async function fetchDemoInfo(): Promise<DemoInfo | null> {
  try {
    const res = await apiFetch("/demo/info", { skipAuth: true })
    if (!res.ok) return null
    const body = await res.json()
    const info = body?.data ?? body
    if (info && typeof info.demoMode === "boolean") return info as DemoInfo
    return null
  } catch {
    return null
  }
}

// `loaded` is false until the first request settles; `info` is null if unreachable.
export function useDemoInfo() {
  const [state, setState] = useState<{ loaded: boolean; info: DemoInfo | null }>({ loaded: false, info: null })

  useEffect(() => {
    let cancelled = false
    fetchDemoInfo().then((info) => {
      if (!cancelled) setState({ loaded: true, info })
    })
    return () => {
      cancelled = true
    }
  }, [])

  return state
}
