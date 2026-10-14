"use client"

import { useRef, useState } from "react"
import { HugeiconsIcon } from "@hugeicons/react"
import { ArrowDown01Icon, Download04Icon, Invoice03Icon, PrinterIcon, Share08Icon } from "@hugeicons/core-free-icons"
import { toast } from "sonner"
import { Loader2 } from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { downloadReceipt, fetchReceipt, printReceipt, shareReceipt, type ReceiptApiBase } from "@/lib/receipt"

interface ReceiptMenuProps {
    apiBase: ReceiptApiBase
    orderId: string
    orderNumber?: string | null
    size?: "sm" | "md"
}

type Action = "download" | "share" | "print"

// "Receipt ▾" → Download / Share / Print the order receipt PDF.
export function ReceiptMenu({ apiBase, orderId, orderNumber, size = "sm" }: ReceiptMenuProps) {
    const [busy, setBusy] = useState<Action | null>(null)
    const [open, setOpen] = useState(false)
    const cached = useRef<File | null>(null)

    async function run(action: Action) {
        setBusy(action)
        try {
            const file = cached.current || await fetchReceipt(apiBase, orderId)
            cached.current = file
            if (action === "download") {
                downloadReceipt(file)
                toast.success(`Downloaded ${file.name}`)
            } else if (action === "print") {
                printReceipt(file)
            } else {
                const result = await shareReceipt(file)
                if (result === "downloaded") {
                    toast.info("This browser can't share files, so the PDF was downloaded. Attach it in WhatsApp or email.")
                }
            }
        } catch (error) {
            toast.error(error instanceof Error ? error.message : "Could not load the receipt")
        } finally {
            setBusy(null)
            // Stays open while the PDF loads (spinner), closes when done.
            setOpen(false)
        }
    }

    const item = (action: Action, label: string, icon: typeof Download04Icon) => (
        <DropdownMenuItem
            onSelect={(event) => {
                event.preventDefault()
                if (!busy) void run(action)
            }}
            className="gap-2.5 py-2 text-sm"
        >
            {busy === action ? <Loader2 className="h-4 w-4 animate-spin" /> : <HugeiconsIcon icon={icon} size={17} color="currentColor" />}
            {label}
        </DropdownMenuItem>
    )

    return (
        <DropdownMenu open={open} onOpenChange={(next) => !busy && setOpen(next)}>
            <DropdownMenuTrigger asChild>
                <Button
                    variant="outline"
                    size="sm"
                    aria-label={`Receipt${orderNumber ? ` for ${orderNumber}` : ""}`}
                    className={`gap-1.5 rounded-full border-[#cfe0bf] bg-[#f1f7ea] font-semibold text-[#17351d] hover:bg-[#e3efd6] ${size === "sm" ? "h-8 px-3 text-xs" : "h-9 px-4 text-sm"}`}
                >
                    {busy ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <HugeiconsIcon icon={Invoice03Icon} size={15} color="currentColor" />}
                    Receipt
                    <HugeiconsIcon icon={ArrowDown01Icon} size={13} color="currentColor" />
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48">
                {orderNumber && <DropdownMenuLabel className="text-[11px] font-semibold text-slate-500">{orderNumber}</DropdownMenuLabel>}
                {orderNumber && <DropdownMenuSeparator />}
                {item("download", "Download PDF", Download04Icon)}
                {item("share", "Share", Share08Icon)}
                {item("print", "Print", PrinterIcon)}
            </DropdownMenuContent>
        </DropdownMenu>
    )
}
