"use client"

import { useEffect, useMemo, useState } from "react"
import { Loader2 } from "@/components/hugeicons"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { apiFetch } from "@/lib/api"
import { quantityWithPacks } from "@/lib/pack-size"
import {
    DeliveryChargeInput,
    EMPTY_ACCEPT_ADDRESS,
    ShippingAddressFields,
    formatRupees,
    isAcceptAddressComplete,
    parseDeliveryCharge,
    type AcceptShippingAddress,
} from "@/components/accept-order-fields"

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
    wholesaler: {
        name?: string
        phone?: string
        address?: string
        businessInfo?: { businessName?: string; businessAddress?: string }
    }
    lastOrderAddress: AcceptShippingAddress | null
    items: GroupItem[]
}

interface RequirementGroupAcceptDialogProps {
    groupId: string | null
    onClose: () => void
    onAccepted: () => void
}

const itemNote = (item: GroupItem) => {
    if (item.order) return `In order ${item.order.orderNumber}`
    if (item.isExpired) return "Expired"
    if (!item.canAccept) return item.status
    return null
}

// Accept the products a wholesaler sent together into ONE order and bill,
// with one delivery charge.
export function RequirementGroupAcceptDialog({ groupId, onClose, onAccepted }: RequirementGroupAcceptDialogProps) {
    const [detail, setDetail] = useState<GroupDetail | null>(null)
    const [isLoading, setIsLoading] = useState(false)
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [selected, setSelected] = useState<Set<string>>(new Set())
    const [address, setAddress] = useState<AcceptShippingAddress>(EMPTY_ACCEPT_ADDRESS)
    const [note, setNote] = useState("")
    const [delivery, setDelivery] = useState("")

    useEffect(() => {
        if (!groupId) return
        let cancelled = false
        // Reset the form for the requirement being opened.
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setIsLoading(true)
        setDetail(null)
        setDelivery("")
        setNote("")
        apiFetch(`/admin/negotiations/groups/${groupId}`)
            .then(async (res) => {
                const data = await res.json().catch(() => ({}))
                if (cancelled) return
                if (!res.ok) {
                    toast.error(data?.message || "Failed to load requirement")
                    onClose()
                    return
                }
                const group: GroupDetail = data.data
                setDetail(group)
                setSelected(new Set(group.items.filter((item) => item.canAccept).map((item) => item.id)))
                const base = group.lastOrderAddress
                const w = group.wholesaler
                setAddress({
                    fullName: base?.fullName || w?.name || "",
                    phone: base?.phone || w?.phone || "",
                    addressLine1: base?.addressLine1 || w?.address || w?.businessInfo?.businessAddress || "",
                    addressLine2: base?.addressLine2 || w?.businessInfo?.businessName || "",
                    city: base?.city || "",
                    state: base?.state || "",
                    pincode: base?.pincode || "",
                })
            })
            .catch(() => {
                if (!cancelled) toast.error("Failed to load requirement")
            })
            .finally(() => {
                if (!cancelled) setIsLoading(false)
            })
        return () => {
            cancelled = true
        }
    }, [groupId, onClose])

    const chosen = useMemo(
        () => (detail?.items || []).filter((item) => item.canAccept && selected.has(item.id)),
        [detail, selected],
    )
    const subtotal = chosen.reduce((sum, item) => sum + Number(item.totalPrice || 0), 0)
    const deliveryAmount = parseDeliveryCharge(delivery)
    const total = subtotal + (deliveryAmount ?? 0)
    const canSubmit = chosen.length > 0 && deliveryAmount !== null && isAcceptAddressComplete(address) && !isSubmitting

    function toggle(id: string, checked: boolean) {
        setSelected((current) => {
            const next = new Set(current)
            if (checked) next.add(id)
            else next.delete(id)
            return next
        })
    }

    async function submit() {
        if (!detail || !canSubmit) return
        setIsSubmitting(true)
        try {
            const res = await apiFetch(`/admin/negotiations/groups/${detail.requestGroup.id}/accept`, {
                method: "PUT",
                body: JSON.stringify({
                    negotiationIds: chosen.map((item) => item.id),
                    shippingAddress: address,
                    customerNote: note || undefined,
                    deliveryCharge: deliveryAmount ?? 0,
                }),
            })
            const data = await res.json().catch(() => ({}))
            if (res.ok && data?.data?.orderNumber) {
                toast.success(`Order ${data.data.orderNumber} created for ${chosen.length} products · ${formatRupees(data.data.total)}. The dealer was notified.`)
                onAccepted()
                onClose()
            } else {
                toast.error(data?.message || "Accept failed")
            }
        } catch {
            toast.error("Error processing request")
        } finally {
            setIsSubmitting(false)
        }
    }

    return (
        <Dialog open={Boolean(groupId)} onOpenChange={(open) => { if (!open) onClose() }}>
            <DialogContent className="border-slate-200 bg-white text-slate-900 max-w-2xl max-h-[90dvh] overflow-y-auto" data-testid="group-accept-dialog">
                <DialogHeader>
                    <DialogTitle>Accept Requirement & Create One Order</DialogTitle>
                    <DialogDescription className="text-slate-500">
                        {detail
                            ? `${detail.requestGroup.number} · ${detail.wholesaler?.name || "Dealer"} · ${detail.items.length} products. Ticked products go into one pending-payment order and one bill.`
                            : "Loading requirement…"}
                    </DialogDescription>
                </DialogHeader>

                {isLoading || !detail ? (
                    <div className="flex justify-center py-8"><Loader2 className="h-6 w-6 animate-spin text-blue-600" /></div>
                ) : (
                    <div className="space-y-4">
                        <div className="divide-y divide-slate-100 rounded-md border border-slate-200">
                            {detail.items.map((item) => {
                                const blocked = itemNote(item)
                                return (
                                    <label
                                        key={item.id}
                                        className={`flex items-center gap-3 px-3 py-2 text-sm ${blocked ? "opacity-60" : "cursor-pointer"}`}
                                        data-testid="group-item"
                                    >
                                        <Checkbox
                                            checked={item.canAccept && selected.has(item.id)}
                                            disabled={!item.canAccept}
                                            onCheckedChange={(checked) => toggle(item.id, checked === true)}
                                            aria-label={`Include ${item.product.name}`}
                                        />
                                        <div className="min-w-0 flex-1">
                                            <p className="truncate font-medium text-slate-900">{item.product.name}</p>
                                            <p className="text-xs text-slate-500">
                                                {quantityWithPacks(item.product, item.requestedQuantity)} × ₹{Number(item.pricePerUnit || 0).toLocaleString("en-IN")}
                                                {blocked ? ` · ${blocked}` : ""}
                                            </p>
                                        </div>
                                        <span className="font-semibold text-slate-900">{formatRupees(Number(item.totalPrice || 0))}</span>
                                    </label>
                                )
                            })}
                        </div>

                        <ShippingAddressFields address={address} onChange={setAddress} note={note} onNoteChange={setNote} />
                        <DeliveryChargeInput value={delivery} onChange={setDelivery} subtotal={subtotal} />
                    </div>
                )}

                <DialogFooter>
                    <Button variant="ghost" className="text-slate-600" onClick={onClose}>Cancel</Button>
                    <Button className="bg-blue-600 hover:bg-blue-700 text-white" disabled={!canSubmit} onClick={submit}>
                        {isSubmitting
                            ? <Loader2 className="h-4 w-4 animate-spin" />
                            : `Accept ${chosen.length} ${chosen.length === 1 ? "product" : "products"} · ${formatRupees(total)}`}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}
