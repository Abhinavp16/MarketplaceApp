"use client"

import { Input } from "@/components/ui/input"
import {
    contentLabel,
    contentsText,
    formatPackNumber,
    getPackInfo,
    isBundleUnit,
    isCoilUnit,
    isPacketUnit,
    packLabel,
    packQuantityText,
    type PackInfo,
} from "@/lib/pack-size"

const toNumber = (value: string | number | undefined | null) => {
    const number = Number(value)
    return Number.isFinite(number) && number > 0 ? number : 0
}

const formatINR = (value: number) =>
    new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(value)

// Help text under Packing, depending on the Price Unit.
export function packingHint(priceUnit?: string, packing?: string) {
    const info = getPackInfo(priceUnit, packing)
    const text = String(packing ?? "").trim()
    if (isPacketUnit(priceUnit)) {
        if (info.packUnit) return { text: `1 packet = ${info.size} pieces. Prices, stock and customer minimum are per piece.`, warn: false }
        return { text: "Type only the pieces in one packet, e.g. 15. Otherwise the product is priced per packet.", warn: Boolean(text) }
    }
    if (isCoilUnit(priceUnit) || isBundleUnit(priceUnit)) {
        const name = isCoilUnit(priceUnit) ? "coil" : "bundle"
        if (info.packUnit) return { text: `1 ${name} = ${info.size} m. Prices, stock and customer minimum are per meter.`, warn: false }
        if (/^\d+$/.test(text)) return { text: `Add "m" (e.g. ${text} m) if this ${name} is priced per meter. As typed, the product is priced per ${name}.`, warn: true }
        return { text: `For cables / roll pipes type the length in meters, e.g. 500 m. Otherwise the product is priced per ${name}.`, warn: false }
    }
    return { text: "Packaging or pack size shown to customers.", warn: false }
}

// "Stock (meters)" etc. for pack products.
export const baseUnitSuffix = (info: PackInfo) =>
    info.contentUnit ? ` (${contentLabel(info.contentUnit).toLowerCase()}s)` : ""

interface StockInPacksProps {
    info: PackInfo
    stock: string
    onStockChange: (value: string) => void
}

// Lets the admin type stock in coils / bundles / packets; stores meters / pieces.
export function StockInPacks({ info, stock, onStockChange }: StockInPacksProps) {
    if (!info.packUnit || !info.contentUnit) return null
    const packs = toNumber(stock) / info.size
    const unit = packLabel(info.packUnit, 2).toLowerCase()
    return (
        <div className="mt-2 space-y-1" data-testid="stock-in-packs">
            <div className="flex items-center gap-2">
                <span className="text-xs text-gray-400">or in {unit}:</span>
                <Input
                    type="number"
                    min={0}
                    step="any"
                    aria-label={`Stock in ${unit}`}
                    value={stock === "" ? "" : String(Math.round(packs * 100) / 100)}
                    onChange={(event) => {
                        const value = event.target.value
                        onStockChange(value === "" ? "" : String(Math.round(Number(value) * info.size)))
                    }}
                    className="h-8 w-28 bg-[#0D0D0D] border-[#333] text-white"
                />
            </div>
            <p className="text-[11px] text-gray-500">
                {contentsText(info.contentUnit, toNumber(stock))} = {formatPackNumber(packs)} {unit}
            </p>
        </div>
    )
}

interface PackPreviewProps {
    priceUnit?: string
    packing?: string
    retailPrice?: string
    wholesalePrice?: string
    stock?: string
    minWholesaleQuantity?: string
    minCustomerQuantity?: string
}

// How the app will show a pack product (before brand/category discounts).
export function PackPreview(props: PackPreviewProps) {
    const info = getPackInfo(props.priceUnit, props.packing)
    if (!info.packUnit || !info.contentUnit) return null
    const unit = contentLabel(info.contentUnit)
    const wholesale = toNumber(props.wholesalePrice)
    const retail = toNumber(props.retailPrice)
    const minPacks = Math.max(1, toNumber(props.minWholesaleQuantity) || 1)
    const minCustomer = Math.max(1, toNumber(props.minCustomerQuantity) || 1)
    const stock = toNumber(props.stock)
    const onePack = packQuantityText(info, info.size)
    const rows = [
        {
            label: "Wholesaler sees",
            value: `${formatINR(wholesale)}/${unit} · ${onePack} = ${formatINR(wholesale * info.size)}`,
            note: `Buys whole ${packLabel(info.packUnit, 2).toLowerCase()} only · minimum ${packQuantityText(info, minPacks * info.size)}`,
        },
        {
            label: "Customer sees",
            value: `${formatINR(retail)}/${unit}`,
            note: `Buys ${info.contentUnit === "meter" ? "cut lengths" : "loose pieces"} · minimum ${contentsText(info.contentUnit, minCustomer)}`,
        },
    ]
    return (
        <div className="rounded-lg border border-sky-500/30 bg-sky-500/5 p-3" data-testid="pack-preview">
            <p className="text-sm font-medium text-white">
                Sold by the {packLabel(info.packUnit).toLowerCase()} · priced per {unit.toLowerCase()}
            </p>
            <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2">
                {rows.map((row) => (
                    <div key={row.label} className="rounded-md border border-[#333] bg-[#0D0D0D] p-2">
                        <p className="text-xs text-gray-400">{row.label}</p>
                        <p className="text-sm font-semibold text-white">{row.value}</p>
                        <p className="text-[11px] text-gray-500">{row.note}</p>
                    </div>
                ))}
            </div>
            <p className="mt-2 text-[11px] text-gray-500">
                Stock: {contentsText(info.contentUnit, stock)} = {formatPackNumber(stock / info.size)}{" "}
                {packLabel(info.packUnit, 2).toLowerCase()}. Brand/category discounts can replace these prices.
            </p>
        </div>
    )
}
