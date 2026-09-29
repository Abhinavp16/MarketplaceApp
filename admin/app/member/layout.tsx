"use client"

import { MobileMemberNav, MemberSidebar } from "@/components/sidebar"
import { isMemberRole } from "@/lib/role-labels"
import { DemoBanner } from "@/components/demo-banner"
import { PageTransition } from "@/components/motion/page-transition"
import { useEffect, useState } from "react"
import { usePathname } from "next/navigation"
import { apiFetch, isSessionExpired, logout } from "@/lib/api"

export default function MemberLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const [isAuthorized, setIsAuthorized] = useState(false)

  useEffect(() => {
    async function verifyMemberAccess() {
      if (!localStorage.getItem("accessToken") || isSessionExpired()) return logout()

      const response = await apiFetch("/auth/me")
      if (!response.ok) return logout()

      const data = await response.json()
      if (!isMemberRole(data.data.role)) return logout()
      setIsAuthorized(true)
    }

    verifyMemberAccess().catch(logout)
    const sessionCheck = window.setInterval(() => { if (isSessionExpired()) logout() }, 60_000)
    return () => window.clearInterval(sessionCheck)
  }, [])

  if (!isAuthorized) return null

  return (
    <div className="relative flex min-h-screen w-full flex-col overflow-x-hidden bg-background text-foreground md:h-screen md:overflow-hidden">
      <DemoBanner />
      <main className="flex min-h-0 flex-1">
        <MemberSidebar />
        <div className="min-w-0 flex-1 overflow-y-auto no-scrollbar">
          <div className="flex min-h-full flex-col gap-4 p-4 sm:p-5 md:gap-6 md:p-6">
            <MobileMemberNav />
            <PageTransition routeKey={pathname}>{children}</PageTransition>
          </div>
        </div>
      </main>
    </div>
  )
}
