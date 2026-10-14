"use client"

import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"

export interface AcceptShippingAddress {
    fullName: string
    phone: string
    addressLine1: string
    addressLine2?: string
    city: string
    state: string
    pincode: string
}

export const EMPTY_ACCEPT_ADDRESS: AcceptShippingAddress = {
    fullName: "",
    phone: "",
    addressLine1: "",
    addressLine2: "",
    city: "",
    state: "",
    pincode: "",
}

const REQUIRED_FIELDS: (keyof AcceptShippingAddress)[] = ["fullName", "phone", "addressLine1", "city", "state", "pincode"]

export const isAcceptAddressComplete = (address: AcceptShippingAddress) =>
    REQUIRED_FIELDS.every((field) => String(address[field] || "").trim().length > 0)

// Delivery charge typed by the admin: "" = 0, otherwise a number >= 0.
// Returns null when the text isn't a valid amount.
export function parseDeliveryCharge(value: string): number | null {
    const text = value.trim()
    if (!text) return 0
    const amount = Number(text)
    if (!Number.isFinite(amount) || amount < 0 || amount > 10000000) return null
    return Math.round(amount * 100) / 100
}

export const formatRupees = (value: number) =>
    `₹${value.toLocaleString("en-IN", { maximumFractionDigits: 2 })}`

interface DeliveryChargeInputProps {
    value: string
    onChange: (value: string) => void
    subtotal: number
}

// Delivery charge field + "Subtotal + Delivery = Total" line.
export function DeliveryChargeInput({ value, onChange, subtotal }: DeliveryChargeInputProps) {
    const delivery = parseDeliveryCharge(value)
    return (
        <div className="space-y-2" data-testid="delivery-charge">
            <div>
                <Label htmlFor="delivery-charge-input" className="text-xs text-slate-500">Delivery charge (₹)</Label>
                <Input
                    id="delivery-charge-input"
                    type="number"
                    min={0}
                    step="any"
                    inputMode="decimal"
                    placeholder="0"
                    value={value}
                    onChange={(event) => onChange(event.target.value)}
                    className="border-slate-200 bg-white h-9 mt-1 text-slate-900"
                />
                {delivery === null && (
                    <p className="mt-1 text-xs text-red-600">Enter 0 or a positive amount.</p>
                )}
            </div>
            <div className="rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm" data-testid="order-total-line">
                <div className="flex justify-between text-slate-600"><span>Subtotal</span><span>{formatRupees(subtotal)}</span></div>
                <div className="flex justify-between text-slate-600"><span>Delivery</span><span>{formatRupees(delivery ?? 0)}</span></div>
                <div className="mt-1 flex justify-between border-t border-slate-200 pt-1 font-semibold text-slate-900">
                    <span>Total</span><span>{formatRupees(subtotal + (delivery ?? 0))}</span>
                </div>
            </div>
        </div>
    )
}

interface ShippingAddressFieldsProps {
    address: AcceptShippingAddress
    onChange: (address: AcceptShippingAddress) => void
    note: string
    onNoteChange: (note: string) => void
}

export function ShippingAddressFields({ address, onChange, note, onNoteChange }: ShippingAddressFieldsProps) {
    const field = (key: keyof AcceptShippingAddress, label: string, required: boolean, span = 1) => (
        <div className={span === 2 ? "col-span-2" : "col-span-1"}>
            <Label className="text-xs text-slate-500">{label}{required ? " *" : ""}</Label>
            <Input
                required={required}
                aria-label={label}
                className="border-slate-200 bg-white h-9 mt-1 text-slate-900"
                value={address[key] || ""}
                onChange={(event) => onChange({ ...address, [key]: event.target.value })}
            />
        </div>
    )
    return (
        <div className="grid grid-cols-2 gap-3">
            {field("fullName", "Full name", true)}
            {field("phone", "Phone", true)}
            {field("addressLine1", "Address line 1", true, 2)}
            {field("addressLine2", "Address line 2", false, 2)}
            {field("city", "City", true)}
            {field("state", "State", true)}
            {field("pincode", "Pincode", true)}
            <div className="col-span-1">
                <Label className="text-xs text-slate-500">Note for order</Label>
                <Input
                    aria-label="Note for order"
                    className="border-slate-200 bg-white h-9 mt-1 text-slate-900"
                    value={note}
                    onChange={(event) => onNoteChange(event.target.value)}
                />
            </div>
        </div>
    )
}
