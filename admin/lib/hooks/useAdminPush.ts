"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import { toast } from "sonner"
import { apiFetch, getUser } from "@/lib/api"
import { getFirebaseApp, getVapidKey, isAdminPushConfigured } from "@/lib/firebase-client"

// "not-configured": no Firebase web keys in this environment (the default).
// "unsupported": keys are set but this browser cannot do web push.
export type AdminPushStatus = "not-configured" | "unsupported" | "disabled" | "enabled" | "denied" | "loading"

// The FCM token of this browser, kept so it can be unregistered on turn-off / logout.
export const PUSH_TOKEN_KEY = "adminFcmToken"
// Remembers (per admin) that alerts were switched on in this browser, so they come
// back silently after the next sign-in. Cleared when the admin turns alerts off.
const wantedKey = (userId: string) => `adminPushWanted:${userId}`

function currentUserId(): string | null {
    try {
        const user = getUser()
        return user?._id || user?.id || null
    } catch {
        return null
    }
}

function browserSupportsPush(): boolean {
    return typeof window !== "undefined" && "Notification" in window && "serviceWorker" in navigator
}

async function getServiceWorkerRegistration(): Promise<ServiceWorkerRegistration | null> {
    if (!("serviceWorker" in navigator)) return null
    try {
        return (await navigator.serviceWorker.getRegistration("/")) || (await navigator.serviceWorker.register("/sw.js"))
    } catch {
        return null
    }
}

// Gets this browser's FCM token (permission must already be granted) and registers it
// with the backend for the signed-in admin. Returns the token, or null on any failure.
async function registerCurrentBrowser(): Promise<string | null> {
    const app = getFirebaseApp()
    const vapidKey = getVapidKey()
    if (!app || !vapidKey) return null
    const registration = await getServiceWorkerRegistration()
    if (!registration) return null
    const { getMessaging, getToken } = await import("firebase/messaging")
    const token = await getToken(getMessaging(app), { vapidKey, serviceWorkerRegistration: registration })
    if (!token) return null
    const res = await apiFetch("/notifications/register-token", {
        method: "POST",
        body: JSON.stringify({ fcmToken: token, platform: "web" }),
    })
    if (!res.ok) return null
    localStorage.setItem(PUSH_TOKEN_KEY, token)
    return token
}

// Called once after the dashboard confirms the admin is signed in. If this admin had
// alerts on in this browser, registers the browser again without prompting. Does nothing
// when push is not configured, alerts were never enabled, or permission is not granted.
export async function restoreAdminPush(): Promise<boolean> {
    try {
        if (!isAdminPushConfigured() || !browserSupportsPush()) return false
        const userId = currentUserId()
        if (!userId || localStorage.getItem(wantedKey(userId)) !== "1") return false
        if (Notification.permission !== "granted") return false
        return Boolean(await registerCurrentBrowser())
    } catch (error) {
        console.warn("Restoring browser alerts failed:", error)
        return false
    }
}

function resolveInitialPushStatus(): AdminPushStatus {
    if (typeof window === "undefined") return "disabled"
    if (!isAdminPushConfigured()) return "not-configured"
    if (!browserSupportsPush()) return "unsupported"
    if (Notification.permission === "denied") return "denied"
    try {
        return localStorage.getItem(PUSH_TOKEN_KEY) ? "enabled" : "disabled"
    } catch {
        return "disabled"
    }
}

// Enables/disables browser push for the signed-in admin and keeps the
// backend token registry in sync. Foreground messages refresh the inbox.
export function useAdminPush(onForegroundMessage?: () => void) {
    // Same value on the server and the first client render; the real state is read in an effect.
    const [status, setStatus] = useState<AdminPushStatus>(() => (isAdminPushConfigured() ? "disabled" : "not-configured"))
    const callbackRef = useRef(onForegroundMessage)

    useEffect(() => {
        callbackRef.current = onForegroundMessage
    }, [onForegroundMessage])

    useEffect(() => {
        setStatus(resolveInitialPushStatus())
    }, [])

    // Listen for foreground pushes while the panel is open.
    useEffect(() => {
        if (!isAdminPushConfigured()) return
        let unsubscribe: (() => void) | null = null
        let cancelled = false
        ;(async () => {
            try {
                const app = getFirebaseApp()
                if (!app) return
                const { getMessaging, onMessage } = await import("firebase/messaging")
                const messaging = getMessaging(app)
                unsubscribe = onMessage(messaging, (payload) => {
                    if (cancelled) return
                    callbackRef.current?.()
                    const title = payload.notification?.title || payload.data?.title || "New admin alert"
                    const body = payload.notification?.body || payload.data?.body || ""
                    toast.info(body ? `${title}: ${body}` : title)
                    window.dispatchEvent(new CustomEvent("admin-push-message", { detail: payload.data || {} }))
                })
            } catch (error) {
                console.warn("Foreground push listener failed:", error)
            }
        })()
        return () => {
            cancelled = true
            unsubscribe?.()
        }
    }, [])

    const enable = useCallback(async () => {
        if (!isAdminPushConfigured()) {
            setStatus("not-configured")
            return false
        }
        if (!browserSupportsPush()) {
            setStatus("unsupported")
            return false
        }
        setStatus("loading")
        try {
            const permission = await Notification.requestPermission()
            if (permission !== "granted") {
                setStatus("denied")
                toast.error("Browser notifications were blocked. Allow them in site settings to enable alerts.")
                return false
            }
            const token = await registerCurrentBrowser()
            if (!token) {
                setStatus("disabled")
                toast.error("Could not enable browser alerts. Check the Firebase settings and try again.")
                return false
            }
            const userId = currentUserId()
            if (userId) localStorage.setItem(wantedKey(userId), "1")
            setStatus("enabled")
            toast.success("Browser alerts enabled on this device.")
            return true
        } catch (error) {
            console.error("Enable push failed:", error)
            setStatus("disabled")
            toast.error("Could not enable browser alerts.")
            return false
        }
    }, [])

    const disable = useCallback(async () => {
        const token = localStorage.getItem(PUSH_TOKEN_KEY)
        localStorage.removeItem(PUSH_TOKEN_KEY)
        const userId = currentUserId()
        if (userId) localStorage.removeItem(wantedKey(userId))
        setStatus("disabled")
        if (!token) return true
        try {
            await apiFetch("/notifications/unregister-token", {
                method: "POST",
                body: JSON.stringify({ fcmToken: token }),
            })
        } catch (error) {
            console.warn("Push unregister failed:", error)
        }
        return true
    }, [])

    return { status, enable, disable }
}
