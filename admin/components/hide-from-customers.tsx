"use client"

import { EyeOff } from "@/components/hugeicons"
import { Switch } from "@/components/ui/switch"

const DESCRIPTION = {
    brand: "Only wholesalers will see this brand, its categories and products. Retail customers, people who aren't signed in and the website won't.",
    category: "Only wholesalers will see this category, its subcategories and products. Retail customers, people who aren't signed in and the website won't.",
}

// The "hide from customers" switch on the brand and top-level category forms.
export function HideFromCustomersSwitch({
    kind,
    checked,
    onCheckedChange,
}: {
    kind: "brand" | "category"
    checked: boolean
    onCheckedChange: (checked: boolean) => void
}) {
    const id = `hide-from-customers-${kind}`
    return (
        <div className="flex items-start justify-between gap-4 rounded-lg border border-[#333] bg-[#0D0D0D] p-3">
            <label htmlFor={id} className="cursor-pointer">
                <span className="flex items-center gap-2 text-sm font-medium text-white">
                    <EyeOff className="h-4 w-4 text-amber-300" />
                    Hide from customers and guests
                </span>
                <span className="mt-1 block text-xs text-gray-400">{DESCRIPTION[kind]}</span>
            </label>
            <Switch id={id} checked={checked} onCheckedChange={onCheckedChange} aria-label="Hide from customers and guests" />
        </div>
    )
}

export function HiddenFromCustomersBadge({ hidden, className = "" }: { hidden?: boolean; className?: string }) {
    if (!hidden) return null
    return (
        <span
            className={`inline-flex items-center gap-1 rounded-full border border-amber-500/40 bg-amber-500/10 px-2 py-0.5 text-[11px] font-semibold text-amber-300 ${className}`}
            title="Only wholesalers see this"
        >
            <EyeOff className="h-3 w-3" />
            Hidden from customers
        </span>
    )
}
