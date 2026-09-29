"use client"

import { useMemo, useState } from "react"
import { useRouter } from "next/navigation"
import { CheckmarkBadge01Icon, Notification01Icon } from "@hugeicons/core-free-icons"
import { HugeiconsIcon } from "@hugeicons/react"
import { Button } from "@/components/ui/button"
import { useAdminNotifications, type AdminNotification } from "@/lib/hooks/useAdminNotifications"

const SEVERITY_STYLES: Record<AdminNotification["severity"], string> = {
    info: "bg-blue-500",
    warning: "bg-amber-500",
    urgent: "bg-red-500",
}

function timeAgo(iso: string): string {
    const seconds = Math.max(1, Math.floor((Date.now() - new Date(iso).getTime()) / 1000))
    if (seconds < 60) return `${seconds}s ago`
    const minutes = Math.floor(seconds / 60)
    if (minutes < 60) return `${minutes}m ago`
    const hours = Math.floor(minutes / 60)
    if (hours < 24) return `${hours}h ago`
    const days = Math.floor(hours / 24)
    return `${days}d ago`
}

function formatType(type: string): string {
    return type.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
}

export default function NotificationsPage() {
    const router = useRouter()
    const { notifications, unreadCount, isLoading, markAsRead, markAllAsRead } = useAdminNotifications()
    const [showUnreadOnly, setShowUnreadOnly] = useState(false)

    const visible = useMemo(
        () => (showUnreadOnly ? notifications.filter((item) => !item.isRead) : notifications),
        [notifications, showUnreadOnly],
    )

    function openNotification(item: AdminNotification) {
        if (!item.isRead) markAsRead(item._id)
        if (item.link) router.push(item.link)
    }

    return (
        <div className="space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                    <h1 className="text-2xl font-bold text-white sm:text-3xl">Notifications</h1>
                    <p className="text-sm text-gray-400">
                        {unreadCount > 0 ? `${unreadCount} unread alert${unreadCount === 1 ? "" : "s"}` : "You are all caught up"}
                    </p>
                </div>
                <div className="flex items-center gap-2">
                    <Button
                        type="button"
                        variant="outline"
                        onClick={() => setShowUnreadOnly((value) => !value)}
                        className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]"
                    >
                        {showUnreadOnly ? "Show all" : "Unread only"}
                    </Button>
                    <Button
                        type="button"
                        onClick={markAllAsRead}
                        disabled={unreadCount === 0}
                        className="bg-[#818cf8] text-black hover:bg-[#818cf8]/90 disabled:opacity-40"
                    >
                        Mark all read
                    </Button>
                </div>
            </div>

            {isLoading ? (
                <div className="flex h-48 items-center justify-center rounded-xl border border-[#333] bg-[#161616] text-gray-400">
                    Loading notifications...
                </div>
            ) : visible.length === 0 ? (
                <div className="flex h-48 flex-col items-center justify-center rounded-xl border border-[#333] bg-[#161616] text-gray-400">
                    <HugeiconsIcon icon={Notification01Icon} size={32} className="mb-3 opacity-50" />
                    <p>{showUnreadOnly ? "No unread notifications" : "No notifications yet"}</p>
                </div>
            ) : (
                <div className="overflow-hidden rounded-xl border border-[#333] bg-[#161616]">
                    {visible.map((item) => (
                        <button
                            key={item._id}
                            type="button"
                            onClick={() => openNotification(item)}
                            className={`flex w-full items-start gap-3 border-b border-[#333] p-4 text-left transition-colors last:border-b-0 hover:bg-[#1A1A1A] ${item.isRead ? "" : "bg-[#818cf8]/5"}`}
                        >
                            <span className={`mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full ${SEVERITY_STYLES[item.severity] || SEVERITY_STYLES.info}`} />
                            <span className="min-w-0 flex-1">
                                <span className="flex flex-wrap items-center gap-2">
                                    <span className="font-semibold text-white">{item.title}</span>
                                    {!item.isRead && (
                                        <span className="rounded-full bg-[#818cf8]/15 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-[#818cf8]">
                                            New
                                        </span>
                                    )}
                                </span>
                                <span className="mt-0.5 block text-sm text-gray-400">{item.body}</span>
                                <span className="mt-1.5 flex flex-wrap items-center gap-2 text-xs text-gray-500">
                                    <span className="rounded-full bg-[#0D0D0D] px-2 py-0.5">{formatType(item.type)}</span>
                                    <span>{timeAgo(item.createdAt)}</span>
                                </span>
                            </span>
                            {item.isRead && <HugeiconsIcon icon={CheckmarkBadge01Icon} size={16} className="mt-1 shrink-0 text-gray-600" />}
                        </button>
                    ))}
                </div>
            )}
        </div>
    )
}
