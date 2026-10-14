"use client"

import { useState } from "react"
import { Loader2 } from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { formatRupees, parseDeliveryCharge } from "@/components/accept-order-fields"

export interface AcceptableOrder {
    _id: string
    orderNumber: string
    subtotal?: number
    deliveryFee?: number
    discount?: number
    total: number
}

interface CustomerOrderAcceptDialogProps {
    order: AcceptableOrder | null
    busy: boolean
    // Dashboard is dark, member panel is light.
    theme?: "dark" | "light"
    onCancel: () => void
    onConfirm: (deliveryCharge: number) => void
}

const subtotalOf = (order: AcceptableOrder) =>
    order.subtotal ?? order.total - (order.deliveryFee || 0) + (order.discount || 0)

// Customer orders: the admin adds the delivery charge when accepting,
// before the customer pays. Render with key={order._id} so the field resets.
export function CustomerOrderAcceptDialog({ order, busy, theme = "dark", onCancel, onConfirm }: CustomerOrderAcceptDialogProps) {
    // Orders placed before this change already carry ₹50; start from that.
    const [value, setValue] = useState(order?.deliveryFee ? String(order.deliveryFee) : "")
    const dark = theme === "dark"
    const delivery = parseDeliveryCharge(value)
    const subtotal = order ? subtotalOf(order) : 0
    const discount = order?.discount || 0
    const total = Math.max(subtotal + (delivery ?? 0) - discount, 0)
    const muted = dark ? "text-gray-400" : "text-slate-600"

    return (
        <Dialog open={Boolean(order)} onOpenChange={(open) => { if (!open && !busy) onCancel() }}>
            <DialogContent
                data-testid="customer-accept-dialog"
                className={dark ? "max-w-[95vw] border-[#333] bg-[#161616] text-white sm:max-w-md" : "max-w-[95vw] sm:max-w-md"}
            >
                <DialogHeader>
                    <DialogTitle>Accept Order</DialogTitle>
                    <DialogDescription>
                        Add the delivery charge for {order?.orderNumber}. The customer pays the total after you accept; it can&apos;t be changed later.
                    </DialogDescription>
                </DialogHeader>
                <div className="space-y-3">
                    <div>
                        <Label htmlFor="customer-delivery-charge" className={`text-xs ${muted}`}>Delivery charge (₹)</Label>
                        <Input
                            id="customer-delivery-charge"
                            type="number"
                            min={0}
                            step="any"
                            inputMode="decimal"
                            placeholder="0"
                            value={value}
                            disabled={busy}
                            onChange={(event) => setValue(event.target.value)}
                            className={dark ? "mt-1 h-9 border-[#333] bg-[#0D0D0D] text-white" : "mt-1 h-9 border-slate-200 bg-white text-slate-900"}
                        />
                        {delivery === null && <p className="mt-1 text-xs text-red-500">Enter 0 or a positive amount.</p>}
                    </div>
                    <div
                        data-testid="order-total-line"
                        className={`rounded-md border px-3 py-2 text-sm ${dark ? "border-[#333] bg-[#0D0D0D]" : "border-slate-200 bg-slate-50"}`}
                    >
                        <div className={`flex justify-between ${muted}`}><span>Subtotal</span><span>{formatRupees(subtotal)}</span></div>
                        {discount > 0 && <div className={`flex justify-between ${muted}`}><span>Discount</span><span>-{formatRupees(discount)}</span></div>}
                        <div className={`flex justify-between ${muted}`}><span>Delivery</span><span>{formatRupees(delivery ?? 0)}</span></div>
                        <div className={`mt-1 flex justify-between border-t pt-1 font-semibold ${dark ? "border-[#333]" : "border-slate-200 text-slate-900"}`}>
                            <span>Total</span><span>{formatRupees(total)}</span>
                        </div>
                    </div>
                </div>
                <DialogFooter>
                    <Button
                        variant="outline"
                        className={dark ? "border-[#333] bg-transparent text-white hover:bg-[#1A1A1A]" : undefined}
                        disabled={busy}
                        onClick={onCancel}
                    >
                        Cancel
                    </Button>
                    <Button
                        className="bg-green-600 text-white hover:bg-green-700"
                        disabled={busy || delivery === null}
                        onClick={() => delivery !== null && onConfirm(delivery)}
                    >
                        {busy && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                        Accept · {formatRupees(total)}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}
