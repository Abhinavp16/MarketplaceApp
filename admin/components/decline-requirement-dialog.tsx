"use client"

import { useState } from "react"
import { toast } from "sonner"
import { Loader2 } from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { apiFetch } from "@/lib/api"

export interface DeclineTarget {
    // A single requirement, or a whole cart requirement (all its open products).
    kind: "negotiation" | "group"
    id: string
    // "4.0 sqmm Metro black" or "REQ-2026-81581241 · 2 products · ₹38,100"
    summary: string
}

interface DeclineRequirementDialogProps {
    // "/admin" for the admin panel, "/staff" for the member panel.
    apiBase: "/admin" | "/staff"
    target: DeclineTarget | null
    onClose: () => void
    onDeclined: () => void
}

// Decline a requirement (or every open product of a cart requirement) with an
// optional reason that the wholesaler sees. Render with key={target?.id}.
export function DeclineRequirementDialog({ apiBase, target, onClose, onDeclined }: DeclineRequirementDialogProps) {
    const [reason, setReason] = useState("")
    const [busy, setBusy] = useState(false)
    const isGroup = target?.kind === "group"

    async function decline() {
        if (!target) return
        setBusy(true)
        try {
            const path = isGroup
                ? `${apiBase}/negotiations/groups/${encodeURIComponent(target.id)}/reject`
                : `${apiBase}/negotiations/${encodeURIComponent(target.id)}/reject`
            const res = await apiFetch(path, { method: "PUT", body: JSON.stringify({ reason: reason.trim() || undefined }) })
            const data = await res.json().catch(() => ({}))
            if (!res.ok) throw new Error(data?.message || "Could not decline the requirement")
            toast.success(data?.message || "Requirement declined")
            onDeclined()
            onClose()
        } catch (error) {
            toast.error(error instanceof Error ? error.message : "Could not decline the requirement")
        } finally {
            setBusy(false)
        }
    }

    return (
        <Dialog open={Boolean(target)} onOpenChange={(open) => { if (!open && !busy) onClose() }}>
            <DialogContent className="border-slate-200 bg-white text-slate-900 sm:max-w-md" data-testid="decline-requirement-dialog">
                <DialogHeader>
                    <DialogTitle>{isGroup ? "Decline this requirement?" : "Decline requirement?"}</DialogTitle>
                    <DialogDescription className="text-slate-500">
                        {isGroup
                            ? "Every open product in this requirement will be declined. The dealer gets one notification with your reason."
                            : "The dealer will be notified with your reason."}
                    </DialogDescription>
                </DialogHeader>
                {target && (
                    <p className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-medium text-slate-700">{target.summary}</p>
                )}
                <Textarea
                    aria-label="Reason for declining"
                    placeholder="Reason (optional), e.g. out of stock, price changed"
                    maxLength={500}
                    className="border-slate-200 bg-white text-slate-900"
                    value={reason}
                    disabled={busy}
                    onChange={(event) => setReason(event.target.value)}
                />
                <DialogFooter>
                    <Button variant="ghost" className="text-slate-600" disabled={busy} onClick={onClose}>Cancel</Button>
                    <Button className="bg-red-600 text-white hover:bg-red-700" disabled={busy} onClick={() => void decline()}>
                        {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : isGroup ? "Decline requirement" : "Decline"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}
