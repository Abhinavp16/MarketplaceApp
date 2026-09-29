"use client"

import { MobileAdminNav, Sidebar } from "@/components/sidebar"
import { DemoBanner } from "@/components/demo-banner"
import { PageTransition } from "@/components/motion/page-transition"
import { useEffect, useState } from "react"
import { usePathname, useRouter } from "next/navigation"
import { apiFetch, isSessionExpired, logout } from "@/lib/api"
import { toast } from "sonner"

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const router = useRouter()
  const pathname = usePathname()
  const [isAuthorized, setIsAuthorized] = useState(false)

  useEffect(() => {
    const verifyAuth = async () => {
      const token = localStorage.getItem("accessToken")
      if (!token) {
        router.push("/login")
        return
      }

      // 4-hour session lifetime check
      if (isSessionExpired()) {
        toast.info("Session expired after 4 hours. Please sign in again.")
        logout()
        return
      }

      try {
        const res = await apiFetch("/auth/me")
        if (!res.ok) {
          logout()
          return
        }

        const data = await res.json()
        if (data.data.role !== "admin") {
          logout()
          return
        }

        setIsAuthorized(true)
      } catch {
        logout()
      }
    }

    verifyAuth()

    // Periodically enforce the 4-hour session limit mid-session
    const sessionCheck = setInterval(() => {
      if (isSessionExpired()) {
        toast.info("Session expired after 4 hours. Please sign in again.")
        logout()
      }
    }, 60 * 1000)

    return () => clearInterval(sessionCheck)
  }, [router])

  if (!isAuthorized) {
    return null
  }

  return (
    <div className="relative flex min-h-screen w-full flex-col overflow-x-hidden bg-background text-foreground md:h-screen md:overflow-hidden">
      <DemoBanner />
      <main className="flex min-h-0 flex-1">
        <Sidebar />
        <div className="min-w-0 flex-1 overflow-y-auto no-scrollbar">
          <div className="flex min-h-full flex-col gap-4 p-4 sm:p-5 md:gap-6 md:p-6">
            {pathname !== "/login" ? <MobileAdminNav /> : null}
            <PageTransition routeKey={pathname}>{children}</PageTransition>
          </div>
        </div>
      </main>
    </div>
  )
}
