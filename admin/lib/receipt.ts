import { apiFetch } from "@/lib/api"

export type ReceiptApiBase = "/admin" | "/staff"

// Order receipt PDF as a File named "<Shop or customer>-<Order number>.pdf".
export async function fetchReceipt(apiBase: ReceiptApiBase, orderId: string): Promise<File> {
    const res = await apiFetch(`${apiBase}/orders/${encodeURIComponent(orderId)}/receipt`)
    if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        throw new Error(data?.message || "Could not load the receipt")
    }
    const blob = await res.blob()
    const headerName = res.headers.get("X-Receipt-Filename")
    const name = headerName ? decodeURIComponent(headerName) : `Receipt-${orderId}.pdf`
    return new File([blob], name, { type: "application/pdf" })
}

export function downloadReceipt(file: File) {
    const url = URL.createObjectURL(file)
    const link = document.createElement("a")
    link.href = url
    link.download = file.name
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.setTimeout(() => URL.revokeObjectURL(url), 30_000)
}

// Opens the device / browser share sheet with the PDF attached. Returns
// "downloaded" when this browser can't share files (the PDF is saved instead).
export async function shareReceipt(file: File): Promise<"shared" | "cancelled" | "downloaded"> {
    const data: ShareData = { files: [file], title: file.name.replace(/\.pdf$/i, "") }
    if (typeof navigator !== "undefined" && navigator.canShare?.(data) && navigator.share) {
        try {
            await navigator.share(data)
            return "shared"
        } catch (error) {
            if (error instanceof DOMException && error.name === "AbortError") return "cancelled"
        }
    }
    downloadReceipt(file)
    return "downloaded"
}

// Prints the PDF through a hidden frame; opens it in a new tab if the
// browser won't print from a frame.
export function printReceipt(file: File) {
    const url = URL.createObjectURL(file)
    const frame = document.createElement("iframe")
    frame.style.position = "fixed"
    frame.style.width = "0"
    frame.style.height = "0"
    frame.style.border = "0"
    frame.style.right = "0"
    frame.style.bottom = "0"
    frame.setAttribute("aria-hidden", "true")
    frame.src = url
    frame.onload = () => {
        try {
            frame.contentWindow?.focus()
            frame.contentWindow?.print()
        } catch {
            window.open(url, "_blank", "noopener")
        }
    }
    document.body.appendChild(frame)
    window.setTimeout(() => {
        frame.remove()
        URL.revokeObjectURL(url)
    }, 120_000)
}
