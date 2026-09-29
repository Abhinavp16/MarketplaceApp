"use client"

import { Suspense, useEffect, useRef, useState } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { apiFetch } from "@/lib/api"
import Image from "next/image"
import { Loader2 } from "@/components/hugeicons"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"

type VerifyStatus = "verifying" | "success" | "error"

function VerifyContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [status, setStatus] = useState<VerifyStatus>("verifying")
  const [errorMessage, setErrorMessage] = useState("")
  const attempted = useRef(false)

  useEffect(() => {
    if (attempted.current) return
    attempted.current = true

    const token = searchParams.get("token")

    if (!token) {
      setErrorMessage("Sign-in link is missing a token. Please request a new link.")
      setStatus("error")
      return
    }

    async function verify() {
      try {
        const res = await apiFetch("/auth/magic-link/verify", {
          method: "POST",
          skipAuth: true,
          body: JSON.stringify({ token }),
        })

        const data = await res.json()

        if (!res.ok) {
          throw new Error(data.message || "This link is invalid or has expired.")
        }

        if (data.data.user.role !== "admin") {
          throw new Error("Access denied. Admin only.")
        }

        localStorage.setItem("accessToken", data.data.accessToken)
        localStorage.setItem("refreshToken", data.data.refreshToken)
        localStorage.setItem("user", JSON.stringify(data.data.user))
        localStorage.setItem("loginAt", String(Date.now()))

        setStatus("success")
        toast.success("Welcome back!")
        router.push("/")
      } catch (error: any) {
        console.error(error)
        setErrorMessage(error.message || "This link is invalid or has expired.")
        setStatus("error")
      }
    }

    verify()
  }, [router, searchParams])

  return (
    <div className="flex min-h-screen items-center justify-center bg-transparent p-4">
      <Card className="w-full max-w-md border-[#d0d1e3] bg-white/92 shadow-[0_32px_90px_rgba(50,58,110,0.12)]">
        <CardHeader className="space-y-1">
          <div className="flex justify-center pb-2">
            <Image src="/icon.svg" alt="TradeHub Demo logo" width={56} height={56} className="h-14 w-14 rounded-xl object-cover" />
          </div>
          <CardTitle className="text-center text-2xl font-bold text-slate-900">TradeHub Demo Admin</CardTitle>
          <CardDescription className="text-center text-slate-500">
            {status === "verifying" && "Verifying your sign-in link..."}
            {status === "success" && "Signed in! Redirecting to dashboard..."}
            {status === "error" && "Sign-in failed"}
          </CardDescription>
        </CardHeader>
        <CardContent>
          {status === "verifying" && (
            <div className="flex items-center justify-center gap-2 py-4 text-slate-600">
              <Loader2 className="h-5 w-5 animate-spin" />
              <span className="text-sm">Please wait a moment</span>
            </div>
          )}
          {status === "error" && (
            <div className="space-y-3">
              <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
                {errorMessage} Links are valid for 5 minutes and can be used only once.
              </div>
              <Button
                type="button"
                onClick={() => router.push("/login")}
                className="w-full bg-[#818cf8] text-black hover:bg-[#7a7ddd]"
              >
                Request a new link
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export default function VerifyMagicLinkPage() {
  return (
    <Suspense>
      <VerifyContent />
    </Suspense>
  )
}
