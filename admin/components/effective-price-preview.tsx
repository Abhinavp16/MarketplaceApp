"use client"

import {
    applyMrpDiscount,
    resolveDiscountPreview,
    type DiscountCategory,
    type DiscountEntity,
    type DiscountRole,
} from "@/lib/discount"

interface EffectivePricePreviewProps {
    mrp: string | number | undefined
    retailPrice: string | number | undefined
    wholesalePrice: string | number | undefined
    brand?: DiscountEntity | null
    categoryId?: string | null
    categories: DiscountCategory[]
}

const formatINR = (value: number) =>
    new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 2 }).format(value)

const toNumber = (value: string | number | undefined) => {
    const number = Number(value)
    return Number.isFinite(number) && number > 0 ? number : 0
}

// Live preview of what customers/wholesalers will pay once brand/category
// discounts (% off MRP) are applied. The backend computes the real price.
export function EffectivePricePreview({ mrp, retailPrice, wholesalePrice, brand, categoryId, categories }: EffectivePricePreviewProps) {
    const mrpValue = toNumber(mrp)
    const rows: { role: DiscountRole; label: string; base: number }[] = [
        { role: "buyer", label: "Customer pays", base: toNumber(retailPrice) },
        { role: "wholesaler", label: "Wholesaler pays", base: toNumber(wholesalePrice) },
    ]
    const resolved = rows.map((row) => ({
        ...row,
        discount: resolveDiscountPreview({ role: row.role, brand, categoryId, categories }),
    }))

    if (resolved.every((row) => !row.discount)) return null

    return (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/5 p-3" data-testid="effective-price-preview">
            <p className="text-sm font-medium text-white">Effective price after brand/category discount</p>
            {mrpValue <= 0 && (
                <p className="mt-1 text-xs text-amber-400">
                    Enter an MRP — discounts are % off MRP, so they can&apos;t apply without it.
                </p>
            )}
            <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2">
                {resolved.map((row) => {
                    const discounted = row.discount && mrpValue > 0 ? applyMrpDiscount(mrpValue, row.discount.percent) : null
                    return (
                        <div key={row.role} className="rounded-md border border-[#333] bg-[#0D0D0D] p-2">
                            <p className="text-xs text-gray-400">{row.label}</p>
                            <p className="text-base font-semibold text-white">
                                {formatINR(discounted ?? row.base)}
                            </p>
                            <p className="text-[11px] text-gray-500">
                                {row.discount
                                    ? `${row.discount.source === "brand" ? "Brand" : "Category"} ${row.discount.sourceName}: ${row.discount.percent}% off MRP${discounted !== null ? " (replaces the price above)" : ""}`
                                    : "No discount — uses the price above"}
                            </p>
                        </div>
                    )
                })}
            </div>
        </div>
    )
}
