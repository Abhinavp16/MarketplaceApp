"use client"

import { FormEvent, useState } from "react"
import { apiFetch } from "@/lib/api"
import Image from "next/image"
import { Loader2 } from "@/components/hugeicons"
import { toast } from "sonner"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"

type LoginMode = "admin" | "member"

const DEMO_ADMIN_EMAIL = "admin@tradehub.example"
const DEMO_ADMIN_PASSWORD = "Demo@12345"

export default function LoginPage() {
  const router = useRouter()
  const [mode, setMode] = useState<LoginMode>("admin")
  const [isLoading, setIsLoading] = useState(false)
  const [email, setEmail] = useState("")
  const [adminPassword, setAdminPassword] = useState("")
  const [username, setUsername] = useState("")
  const [password, setPassword] = useState("")

  // Password login for the admin (demo build). Stores the session exactly like
  // the magic-link verify flow (app/login/verify/page.tsx) does.
  async function submitAdminLogin(event: FormEvent) {
    event.preventDefault()
    setIsLoading(true)
    try {
      const res = await apiFetch("/auth/login", {
        method: "POST",
        skipAuth: true,
        body: JSON.stringify({ email: email.trim(), password: adminPassword }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || "Invalid email or password")

      if (data.data.user.role !== "admin") {
        throw new Error("Access denied. Admin only. Use Staff login for staff accounts.")
      }

      localStorage.setItem("accessToken", data.data.accessToken)
      localStorage.setItem("refreshToken", data.data.refreshToken)
      localStorage.setItem("user", JSON.stringify(data.data.user))
      localStorage.setItem("loginAt", String(Date.now()))
      localStorage.removeItem("sessionExpiresAt")

      toast.success("Welcome back!")
      router.push("/")
    } catch (error: any) {
      toast.error(error.message || "Invalid email or password")
    } finally {
      setIsLoading(false)
    }
  }

  async function submitMemberLogin(event: FormEvent) {
    event.preventDefault()
    setIsLoading(true)
    try {
      const res = await apiFetch("/auth/staff/login", {
        method: "POST",
        skipAuth: true,
        body: JSON.stringify({ username, password }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || "Invalid username or password")

      const { user, accessToken, refreshToken, sessionExpiresAt } = data.data
      localStorage.setItem("accessToken", accessToken)
      localStorage.setItem("refreshToken", refreshToken)
      localStorage.setItem("user", JSON.stringify(user))
      localStorage.setItem("sessionExpiresAt", sessionExpiresAt)
      localStorage.removeItem("loginAt")
      router.push("/member/orders")
    } catch (error: any) {
      toast.error(error.message || "Invalid username or password")
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-transparent p-4">
      <Card className="w-full max-w-md border-[#cacbdf] bg-white/92 shadow-[0_32px_90px_rgba(50,58,110,0.12)]">
        <CardHeader className="space-y-2">
          <div className="flex justify-center"><Image src="/icon.svg" alt="TradeHub Demo logo" width={56} height={56} className="h-14 w-14 rounded-xl object-cover" /></div>
          <CardTitle className="text-center text-2xl font-bold text-slate-900">TradeHub Demo</CardTitle>
          <CardDescription className="text-center text-slate-500">
            {mode === "member" ? "Staff login: use the username and password supplied by your administrator." : "Distribution made simple. Sign in with your admin email and password."}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {mode === "member" ? (
            <form className="space-y-4" onSubmit={submitMemberLogin}>
              <Input value={username} onChange={(event) => setUsername(event.target.value)} placeholder="Username" autoComplete="username" required />
              <Input value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Password" type="password" autoComplete="current-password" required />
              <Button type="submit" className="w-full bg-[#818cf8] text-black hover:bg-[#7a7ddd]" disabled={isLoading}>
                {isLoading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null} Sign in as staff
              </Button>
              <button type="button" onClick={() => setMode("admin")} className="block w-full text-center text-sm font-medium text-indigo-700 hover:underline">
                Admin login
              </button>
            </form>
          ) : (
            <form className="space-y-4" onSubmit={submitAdminLogin}>
              <Input name="email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="Email" autoComplete="username" required />
              <Input name="password" type="password" value={adminPassword} onChange={(event) => setAdminPassword(event.target.value)} placeholder="Password" autoComplete="current-password" required />
              <Button type="submit" className="w-full bg-[#818cf8] text-black hover:bg-[#7a7ddd]" disabled={isLoading}>
                {isLoading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null} Sign in
              </Button>
              <div className="rounded-lg border border-[#cacbdf] bg-[#f3f3fa] p-3 text-center text-xs text-slate-600">
                <div>Demo: {DEMO_ADMIN_EMAIL} / {DEMO_ADMIN_PASSWORD}</div>
                <button type="button" onClick={() => { setEmail(DEMO_ADMIN_EMAIL); setAdminPassword(DEMO_ADMIN_PASSWORD) }} className="mt-1 font-medium text-indigo-700 hover:underline">
                  Fill demo credentials
                </button>
              </div>
              <button type="button" onClick={() => setMode("member")} className="block w-full text-center text-sm font-medium text-indigo-700 hover:underline">
                Staff login
              </button>
            </form>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
