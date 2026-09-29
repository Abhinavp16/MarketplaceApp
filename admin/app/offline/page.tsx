"use client"

import Image from "next/image"
import { useRouter } from "next/navigation"

export default function OfflinePage() {
    const router = useRouter()

    return (
        <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-white p-6 text-center">
            <Image src="/icon-192.png" alt="TradeHub Demo Admin" width={72} height={72} className="rounded-2xl" />
            <h1 className="text-xl font-bold text-slate-900">You are offline</h1>
            <p className="max-w-sm text-sm text-slate-500">
                The admin panel needs an internet connection. Check your connection and try again.
            </p>
            <button
                type="button"
                onClick={() => router.refresh()}
                className="rounded-lg bg-[#1a1e7b] px-5 py-2.5 text-sm font-semibold text-white hover:bg-[#1a1c61]"
            >
                Retry
            </button>
        </div>
    )
}
