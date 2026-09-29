"use client"

import { useCallback, useEffect, useRef, useState } from "react"
import { io, type Socket } from "socket.io-client"
import { toast } from "sonner"
import { apiFetch, getSocketUrl } from "@/lib/api"

const POLL_INTERVAL_MS = 45 * 1000

export interface AdminNotification {
    _id: string
    title: string
    body: string
    type: string
    severity: "info" | "warning" | "urgent"
    link?: string | null
    isRead: boolean
    createdAt: string
}

// Shared inbox state: socket realtime with polling fallback.
export function useAdminNotifications() {
    const [notifications, setNotifications] = useState<AdminNotification[]>([])
    const [unreadCount, setUnreadCount] = useState(0)
    const [isLoading, setIsLoading] = useState(true)
    const socketRef = useRef<Socket | null>(null)

    const fetchNotifications = useCallback(async (limit = 20) => {
        try {
            const res = await apiFetch(`/admin/notifications?limit=${limit}`)
            if (!res.ok) return
            const data = await res.json()
            setNotifications(Array.isArray(data.data) ? data.data : [])
            setUnreadCount(typeof data.unreadCount === "number" ? data.unreadCount : 0)
        } catch (error) {
            console.warn("Failed to fetch admin notifications:", error)
        } finally {
            setIsLoading(false)
        }
    }, [])

    const markAsRead = useCallback(async (id: string) => {
        setNotifications((prev) => prev.map((item) => (item._id === id ? { ...item, isRead: true } : item)))
        setUnreadCount((count) => Math.max(0, count - 1))
        try {
            const res = await apiFetch(`/admin/notifications/${id}/read`, { method: "POST" })
            if (res.ok) {
                const data = await res.json()
                if (typeof data.unreadCount === "number") setUnreadCount(data.unreadCount)
            }
        } catch (error) {
            console.warn("Failed to mark notification as read:", error)
        }
    }, [])

    const markAllAsRead = useCallback(async () => {
        setNotifications((prev) => prev.map((item) => ({ ...item, isRead: true })))
        setUnreadCount(0)
        try {
            await apiFetch("/admin/notifications/read-all", { method: "POST" })
        } catch (error) {
            console.warn("Failed to mark all notifications as read:", error)
        }
    }, [])

    useEffect(() => {
        const initial = window.setTimeout(() => fetchNotifications(), 0)
        const poll = window.setInterval(() => fetchNotifications(), POLL_INTERVAL_MS)

        // Realtime channel: authenticated join, server verifies the JWT.
        const token = localStorage.getItem("accessToken")
        if (token) {
            const socket = io(getSocketUrl(), {
                transports: ["websocket"],
                auth: (cb) => cb({ token: localStorage.getItem("accessToken") || token }),
                reconnection: true,
                reconnectionDelay: 2000,
                reconnectionDelayMax: 10000,
            })
            socketRef.current = socket
            socket.on("connect", () => {
                socket.emit("join-admin", { token })
            })
            socket.on("admin-notification", () => {
                fetchNotifications()
            })
            socket.on("admin-join-error", (data: { message?: string }) => {
                console.warn("Admin realtime channel unavailable:", data?.message)
            })
        }

        return () => {
            window.clearTimeout(initial)
            window.clearInterval(poll)
            socketRef.current?.emit("leave-admin")
            socketRef.current?.disconnect()
            socketRef.current = null
        }
    }, [fetchNotifications])

    return { notifications, unreadCount, isLoading, fetchNotifications, markAsRead, markAllAsRead }
}
