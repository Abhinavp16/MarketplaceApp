"use client"

import { useEffect, useState } from "react"
import { toast } from "sonner"
import { Check, Loader2, Package, X } from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import { SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { formatRupees } from "@/components/accept-order-fields"
import { ReceiptMenu } from "@/components/receipt-menu"
import { apiFetch } from "@/lib/api"
import { quantityWithPacks } from "@/lib/pack-size"

interface GroupItem {
    id: string
    negotiationNumber: string
    product: { name: string; priceUnit?: string; packing?: string }
    requestedQuantity: number
    pricePerUnit: number
    totalPrice: number
    status: string
    isExpired: boolean
    order: { id: string; orderNumber: string } | null
    canAccept: boolean
}

interface GroupDetail {
    requestGroup: { id: string; number: string }
    wholesaler: { name?: string; phone?: string; businessInfo?: { businessName?: string } }
    items: GroupItem[]
}

interface RequirementGroupPanelProps {
    groupId: string
    // Bumped by the page after an accept / decline so the panel reloads.
    refreshKey: number
    onAccept: (groupId: string) => void
    onDecline: (target: { id: string; summary: string }) => void
}

const STATUS: Record<string, { label: string; className: string }> = {
    pending: { label: "Requirement Sent", className: "border-amber-200 bg-amber-50 text-amber-700" },
    countered: { label: "New Price Sent", className: "border-blue-200 bg-blue-50 text-blue-700" },
    accepted: { label: "Accepted", className: "border-emerald-200 bg-emerald-50 text-emerald-700" },
    converted: { label: "Order Created", className: "border-indigo-200 bg-indigo-50 text-indigo-700" },
    rejected: { label: "Declined", className: "border-red-200 bg-red-50 text-red-700" },
    expired: { label: "Expired", className: "border-slate-200 bg-slate-50 text-slate-500" },
}

// Side panel for products a wholesaler sent together (REQ-…): review every
// product, then accept them into one order or decline the requirement.
export function RequirementGroupPanel({ groupId, refreshKey, onAccept, onDecline }: RequirementGroupPanelProps) {
    const [detail, setDetail] = useState<GroupDetail | null>(null)
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        let cancelled = false
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setLoading(true)
        apiFetch(`/admin/negotiations/groups/${encodeURIComponent(groupId)}`)
            .then(async (res) => {
                const data = await res.json().catch(() => ({}))
                if (cancelled) return
                if (!res.ok) throw new Error(data?.message || "Failed to load requirement")
                setDetail(data.data as GroupDetail)
            })
            .catch((error) => !cancelled && toast.error(error instanceof Error ? error.message : "Failed to load requirement"))
            .finally(() => !cancelled && setLoading(false))
        return () => { cancelled = true }
    }, [groupId, refreshKey])

    if (loading && !detail) {
        return <div className="flex flex-1 items-center justify-center"><SheetTitle className="sr-only">Requirement</SheetTitle><Loader2 className="h-6 w-6 animate-spin text-slate-400" /></div>
    }
    if (!detail) return <SheetTitle className="sr-only">Requirement</SheetTitle>

    const dealer = detail.wholesaler?.businessInfo?.businessName || detail.wholesaler?.name || "Wholesaler"
    const open = detail.items.filter((item) => ["pending", "countered"].includes(item.status) && !item.isExpired)
    const total = detail.items.reduce((sum, item) => sum + Number(item.totalPrice || 0), 0)
    const openTotal = open.reduce((sum, item) => sum + Number(item.totalPrice || 0), 0)
    const orderId = detail.items.find((item) => item.order)?.order?.id

    return (
        <div className="flex min-h-0 flex-1 flex-col gap-4" data-testid="requirement-group-panel">
            <SheetHeader className="space-y-1">
                <SheetTitle className="text-slate-900">Requirement {detail.requestGroup.number}</SheetTitle>
                <SheetDescription className="text-slate-500">
                    {dealer}{detail.wholesaler?.phone ? ` · ${detail.wholesaler.phone}` : ""} · {detail.items.length} products · {formatRupees(total)}
                </SheetDescription>
            </SheetHeader>

            <div className="space-y-2.5 px-1">
                {detail.items.map((item) => {
                    const status = STATUS[item.status] || { label: item.status, className: "border-slate-200 bg-slate-50 text-slate-600" }
                    return (
                        <div key={item.id} className="rounded-xl border border-slate-200 bg-white p-3" data-testid="group-panel-item">
                            <div className="flex items-start justify-between gap-3">
                                <div className="min-w-0">
                                    <p className="flex items-center gap-2 rounded-lg bg-blue-50 px-2.5 py-1.5 text-[15px] font-semibold leading-snug text-blue-900">
                                        <Package className="h-4 w-4 shrink-0 text-blue-600" />
                                        <span className="min-w-0 break-words">{item.product?.name || "Product"}</span>
                                    </p>
                                    <p className="mt-1.5 text-xs text-slate-500">{item.negotiationNumber}</p>
                                </div>
                                <span className={`shrink-0 rounded-full border px-2 py-0.5 text-[11px] font-medium ${status.className}`}>
                                    {item.isExpired && item.status !== "rejected" ? "Expired" : status.label}
                                </span>
                            </div>
                            <div className="mt-2 flex items-center justify-between text-sm">
                                <span className="text-slate-600">{quantityWithPacks(item.product, item.requestedQuantity)} × ₹{Number(item.pricePerUnit).toLocaleString("en-IN")}</span>
                                <span className="font-semibold text-slate-900">{formatRupees(item.totalPrice)}</span>
                            </div>
                            {item.order && <p className="mt-1 text-xs text-indigo-600">In order {item.order.orderNumber}</p>}
                        </div>
                    )
                })}
            </div>

            <div className="mt-auto space-y-2 border-t border-slate-200 px-1 pt-4">
                {open.length > 0 ? (
                    <>
                        <p className="text-xs text-slate-500">{open.length} open {open.length === 1 ? "product" : "products"} · {formatRupees(openTotal)}</p>
                        <Button className="w-full bg-blue-600 font-semibold text-white hover:bg-blue-700" onClick={() => onAccept(groupId)}>
                            <Check className="mr-2 h-4 w-4" /> Accept & Create Order
                        </Button>
                        <Button
                            variant="outline"
                            className="w-full border-red-200 bg-white text-red-600 hover:bg-red-50 hover:text-red-700"
                            onClick={() => onDecline({
                                id: groupId,
                                summary: `${detail.requestGroup.number} · ${open.length} open ${open.length === 1 ? "product" : "products"} · ${formatRupees(openTotal)}`,
                            })}
                        >
                            <X className="mr-2 h-4 w-4" /> Decline requirement
                        </Button>
                    </>
                ) : (
                    <p className="rounded-lg bg-slate-50 p-3 text-center text-sm text-slate-500">No open products left in this requirement.</p>
                )}
                {orderId && (
                    <div className="flex items-center justify-between rounded-lg border border-slate-200 px-3 py-2">
                        <span className="text-xs font-medium text-slate-600">Order receipt (PDF)</span>
                        <ReceiptMenu apiBase="/admin" orderId={orderId} />
                    </div>
                )}
            </div>
        </div>
    )
}
