"use client"

import { useState } from "react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Languages, Loader2 } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"

// Hindi names are filled automatically by the backend a few seconds after an
// item is saved, and re-checked every 30 minutes. These buttons run it now.
export const HINDI_AUTO_NOTE = "Hindi names fill automatically within a few seconds of saving, and are checked again every 30 minutes."

type BatchMode = "missing" | "repair"

interface HindiNameBatchButtonsProps {
    endpoint: string
    entityLabel: string
    onDone?: () => void
    buttonClassName?: string
}

export function HindiNameBatchButtons({ endpoint, entityLabel, onDone, buttonClassName = "" }: HindiNameBatchButtonsProps) {
    const [running, setRunning] = useState<BatchMode | null>(null)

    async function run(mode: BatchMode) {
        const question = mode === "repair"
            ? `Fix ${entityLabel} whose Hindi name is broken (e.g. shows "नुम_प्लेसहोल्डर") and fill any missing ones?`
            : `Fill Hindi names now for all ${entityLabel} that don't have one yet?`
        if (!window.confirm(question)) return

        setRunning(mode)
        try {
            const res = await apiFetch(endpoint, { method: "POST", body: JSON.stringify({ mode }) })
            const data = await res.json().catch(() => ({}))
            if (!res.ok || data?.success === false) {
                toast.error(data?.message || "Failed to convert Hindi names")
                return
            }
            const stats = data.data || {}
            const failed = stats.failed ? `, ${stats.failed} could not be converted (will retry automatically)` : ""
            toast.success(`Hindi names: ${stats.updated ?? 0} updated out of ${stats.processed ?? 0}${failed}.`)
            onDone?.()
        } catch (error) {
            console.error(error)
            toast.error("Error converting Hindi names")
        } finally {
            setRunning(null)
        }
    }

    return (
        <>
            <Button type="button" variant="outline" onClick={() => run("missing")} disabled={running !== null} className={buttonClassName} title={HINDI_AUTO_NOTE}>
                {running === "missing" ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Languages className="mr-2 h-4 w-4" />}
                Convert Hindi Names Now
            </Button>
            <Button type="button" variant="outline" onClick={() => run("repair")} disabled={running !== null} className={buttonClassName} title={HINDI_AUTO_NOTE}>
                {running === "repair" ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Languages className="mr-2 h-4 w-4" />}
                Fix Broken Hindi Names Now
            </Button>
        </>
    )
}

interface SuggestHindiButtonProps {
    text: string
    onSuggest: (hindi: string) => void
    className?: string
}

// Fills the Hindi name field with a suggestion for the admin to review.
export function SuggestHindiButton({ text, onSuggest, className = "" }: SuggestHindiButtonProps) {
    const [loading, setLoading] = useState(false)

    async function suggest() {
        const english = text.trim()
        if (!english) {
            toast.error("Enter the English name first")
            return
        }
        setLoading(true)
        try {
            const res = await apiFetch("/admin/hindi-name/suggest", { method: "POST", body: JSON.stringify({ text: english }) })
            const data = await res.json().catch(() => ({}))
            if (!res.ok || !data?.data?.suggestion) {
                toast.error(data?.message || "Could not suggest a Hindi name")
                return
            }
            onSuggest(data.data.suggestion)
            toast.success("Hindi name suggested — please check it before saving")
        } catch (error) {
            console.error(error)
            toast.error("Could not suggest a Hindi name")
        } finally {
            setLoading(false)
        }
    }

    return (
        <Button type="button" variant="outline" size="sm" onClick={suggest} disabled={loading} className={className}>
            {loading ? <Loader2 className="mr-1 h-3.5 w-3.5 animate-spin" /> : <Languages className="mr-1 h-3.5 w-3.5" />}
            Suggest Hindi
        </Button>
    )
}
