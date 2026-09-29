"use client"

import { useEffect } from "react"
import { toast } from "sonner"

// Registers the PWA service worker (production builds only, so dev hot reload is never cached) and surfaces update prompts.
export function PwaRegister() {
    useEffect(() => {
        if (process.env.NODE_ENV !== "production") return
        if (typeof window === "undefined" || !("serviceWorker" in navigator)) return

        let cancelled = false

        navigator.serviceWorker.register("/sw.js").then((registration) => {
            if (cancelled) return
            const waiting = registration.waiting
            if (waiting) {
                promptUpdate(waiting)
                return
            }
            registration.addEventListener("updatefound", () => {
                const worker = registration.installing
                if (!worker) return
                worker.addEventListener("statechange", () => {
                    if (worker.state === "installed" && navigator.serviceWorker.controller) {
                        promptUpdate(worker)
                    }
                })
            })
        }).catch((error) => {
            console.warn("Service worker registration failed:", error)
        })

        return () => {
            cancelled = true
        }
    }, [])

    return null
}

function promptUpdate(worker: ServiceWorker) {
    toast.info("A new version of the admin panel is available.", {
        action: {
            label: "Refresh",
            onClick: () => {
                worker.postMessage({ type: "SKIP_WAITING" })
                window.location.reload()
            },
        },
        duration: 10000,
    })
}
