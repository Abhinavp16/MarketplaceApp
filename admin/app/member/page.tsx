"use client"
import { useEffect } from "react"
import { useRouter } from "next/navigation"
export default function MemberHomePage() { const router = useRouter(); useEffect(() => { router.replace("/member/orders") }, [router]); return null }
