"use client"

import { useEffect } from "react"
import { useParams, useRouter } from "next/navigation"
import { Loader2 } from "@/components/hugeicons"

// This page redirects to the unified add/edit page
export default function EditProductRedirect() {
    const params = useParams()
    const router = useRouter()
    const productId = params.id as string

    useEffect(() => {
        // Redirect to the add page with edit query param
        router.replace(`/products/add?edit=${productId}`)
    }, [productId, router])

    return (
        <div className="flex justify-center items-center h-[400px]">
            <Loader2 className="h-8 w-8 animate-spin text-[#86efac]" />
        </div>
    )
}
