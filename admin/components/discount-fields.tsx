"use client"

import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from "@/components/ui/input-group"
import type { DiscountFormValues } from "@/lib/discount"

interface DiscountFieldsProps {
    value: DiscountFormValues
    onChange: (value: DiscountFormValues) => void
    helperText?: string
    // Per-role note, e.g. when the brand's discount overrides this category's.
    customerNote?: string | null
    wholesalerNote?: string | null
    disabled?: boolean
    // Saved values couldn't be loaded; inputs are locked and not submitted.
    unavailable?: boolean
}

const FIELDS = [
    { key: "customerDiscountPercent", label: "Customer discount", noteKey: "customerNote" },
    { key: "wholesalerDiscountPercent", label: "Wholesaler discount", noteKey: "wholesalerNote" },
] as const

export function DiscountFields({ value, onChange, helperText, customerNote, wholesalerNote, disabled, unavailable }: DiscountFieldsProps) {
    const notes = { customerNote, wholesalerNote }

    return (
        <div className="rounded-lg border border-[#333] bg-[#0D0D0D] p-3">
            <p className="text-sm font-medium text-white">Discount (% off MRP)</p>
            <p className="mb-3 mt-0.5 text-xs text-gray-500">
                {helperText ?? "Leave empty for no discount. A brand discount overrides category discounts."}
            </p>
            {unavailable && (
                <p className="mb-3 rounded-md border border-amber-500/40 bg-amber-500/10 px-2 py-1.5 text-xs text-amber-300">
                    Couldn&apos;t load the saved discounts. Reload the page to edit them — other changes will save without touching discounts.
                </p>
            )}
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                {FIELDS.map((field) => (
                    <div key={field.key}>
                        <label htmlFor={field.key} className="mb-1.5 block text-xs font-medium text-gray-300">
                            {field.label}
                        </label>
                        <InputGroup className="border-[#333] bg-[#161616]">
                            <InputGroupInput
                                id={field.key}
                                type="text"
                                inputMode="decimal"
                                placeholder="0"
                                value={value[field.key]}
                                disabled={disabled || unavailable}
                                onChange={(event) => {
                                    const next = event.target.value.replace(/[^0-9.]/g, "")
                                    onChange({ ...value, [field.key]: next })
                                }}
                                className="text-white"
                            />
                            <InputGroupAddon align="inline-end">
                                <InputGroupText>%</InputGroupText>
                            </InputGroupAddon>
                        </InputGroup>
                        {notes[field.noteKey] && (
                            <p className="mt-1 text-[11px] text-amber-400">{notes[field.noteKey]}</p>
                        )}
                    </div>
                ))}
            </div>
        </div>
    )
}

export function DiscountBadge({ summary, className = "" }: { summary: string | null; className?: string }) {
    if (!summary) return null
    return (
        <span className={`inline-flex items-center rounded-full border border-amber-500/40 bg-amber-500/10 px-2 py-0.5 text-[11px] font-semibold text-amber-300 ${className}`}>
            {summary} off
        </span>
    )
}
