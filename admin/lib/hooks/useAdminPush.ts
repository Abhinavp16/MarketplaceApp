"use client"

// Browser push (Firebase Cloud Messaging) is intentionally removed in the
// demo build. This no-op hook keeps the Notifications page API stable:
// status is always "unsupported" and enable/disable do nothing.
export type AdminPushStatus = "unsupported" | "disabled" | "enabled" | "denied" | "loading"

export function useAdminPush(_onForegroundMessage?: () => void) {
    return {
        status: "unsupported" as AdminPushStatus,
        enable: async () => false,
        disable: async () => true,
    }
}
