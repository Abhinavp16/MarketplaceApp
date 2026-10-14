"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { Loader2 } from "@/components/hugeicons"

export default function LabelsRedirectPage() {
    const router = useRouter()

    useEffect(() => {
        router.replace("/manage-website?tab=labels")
    }, [router])

    return (
        <div className="flex justify-center items-center h-[400px]">
            <Loader2 className="h-8 w-8 animate-spin text-[#86efac]" />
        </div>
    )
}
