"use client"

import { useEffect, useState, useCallback, useRef } from "react"
import { useRouter } from "next/navigation"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Loader2, MessageSquare, Check, X, Send, Search, Package, CheckCircle2 } from "@/components/hugeicons"
import { toast } from "sonner"
import {
    Sheet,
    SheetContent,
    SheetDescription,
    SheetHeader,
    SheetTitle,
} from "@/components/ui/sheet"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Separator } from "@/components/ui/separator"
import { Textarea } from "@/components/ui/textarea"
import { apiFetch, getUser } from "@/lib/api"
import { isMemberRole } from "@/lib/role-labels"
import { useNegotiationSocket } from "@/lib/hooks/useNegotiationSocket"

interface HistoryActor {
    _id?: string
    name?: string
    username?: string
    email?: string
}

interface HistoryEntry {
    action: string
    by: 'wholesaler' | 'admin'
    pricePerUnit?: number
    totalPrice?: number
    message?: string
    timestamp: string
    actorId?: string | HistoryActor | null
    actorRole?: string | null
}

interface ApprovedBy {
    role: string
    userId: string | null
    name: string
}

interface NegotiationList {
    id: string
    negotiationNumber: string
    product: { name: string; price: number }
    wholesaler: { name: string }
    requestedQuantity: number
    requestedPricePerUnit: number
    status: string
    orderId?: string | null
    approvedBy?: ApprovedBy | null
}

interface NegotiationDetail {
    _id: string
    negotiationNumber: string
    productSnapshot: { name: string; sku: string; price: number; image?: string }
    wholesalerId: { _id: string; name: string; email?: string; phone?: string; address?: string; businessInfo?: { businessName?: string; businessAddress?: string } }
    requestedQuantity: number
    requestedPricePerUnit: number
    status: string
    currentOfferBy?: 'wholesaler' | 'admin'
    currentPricePerUnit?: number
    currentTotalPrice?: number
    finalPricePerUnit?: number
    finalTotalPrice?: number
    orderId?: { _id: string; orderNumber: string; status: string; total: number } | string | null
    approvedBy?: ApprovedBy | null
    lastOrderAddress?: ShippingAddress | null
    message: string
    history: HistoryEntry[]
    createdAt: string
}

interface ShippingAddress {
    fullName: string
    phone: string
    addressLine1: string
    addressLine2?: string
    city: string
    state: string
    pincode: string
}

const EMPTY_ADDRESS: ShippingAddress = {
    fullName: "",
    phone: "",
    addressLine1: "",
    addressLine2: "",
    city: "",
    state: "",
    pincode: "",
}

const REQUIRED_ADDRESS_FIELDS: (keyof ShippingAddress)[] = ['fullName', 'phone', 'addressLine1', 'city', 'state', 'pincode']

function isAddressComplete(address: ShippingAddress): boolean {
    return REQUIRED_ADDRESS_FIELDS.every((field) => String(address[field] || '').trim())
}

function statusLabel(status: string): string {
    if (status === 'accepted') return 'Accepted · Order Pending'
    if (status === 'converted') return 'Order Created'
    return status
}

const LEGACY_ACCEPTED_MESSAGE = /^accepted by\b/i

// Stored accept messages from before name attribution (e.g. the old
// hardcoded "Accepted by TradeHub Demo") carry no information beyond the
// structured card, so they are hidden instead of rendered.
function acceptNote(entry: HistoryEntry): string | null {
    const text = (entry.message || '').trim()
    if (!text || LEGACY_ACCEPTED_MESSAGE.test(text)) return null
    return text
}

function AcceptCard({ name, pricePerUnit, timestamp, note, orderCreated }: { name: string; pricePerUnit?: number | null; timestamp?: string; note?: string | null; orderCreated: boolean }) {
    return (
        <div className="flex justify-end">
            <div className="w-full max-w-[85%] rounded-2xl rounded-br-md border border-indigo-200 bg-indigo-50 px-4 py-3 shadow-sm">
                <div className="flex items-center gap-2">
                    <CheckCircle2 className="h-5 w-5 shrink-0 text-indigo-600" />
                    <span className="text-[11px] font-bold uppercase tracking-wide text-indigo-800">
                        Accepted by {name}
                    </span>
                    {pricePerUnit != null && (
                        <span className="ml-auto rounded-full bg-indigo-600 px-2 py-0.5 font-mono text-[11px] font-bold text-white">
                            ₹{pricePerUnit}
                        </span>
                    )}
                </div>
                <p className="mt-1 text-sm font-medium text-indigo-900">
                    {orderCreated ? 'Deal confirmed · order created.' : 'Deal accepted · order pending.'}
                </p>
                {note && <p className="mt-0.5 whitespace-pre-wrap text-sm text-indigo-800">{note}</p>}
                {timestamp && (
                    <span className="mt-1 block text-right text-[10px] text-indigo-700/70">
                        {new Date(timestamp).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                    </span>
                )}
            </div>
        </div>
    )
}

function actorDisplayName(entry: HistoryEntry, dealerFallback = 'Dealer'): string {
    if (typeof entry.actorId === 'object' && entry.actorId) {
        return entry.actorId.name || entry.actorId.username || entry.actorId.email || 'Member'
    }
    if (entry.by === 'wholesaler') return dealerFallback
    return isMemberRole(entry.actorRole) ? 'Member' : 'Admin'
}

export default function NegotiationsPage() {
    const [negotiations, setNegotiations] = useState<NegotiationList[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isLoadingMore, setIsLoadingMore] = useState(false)
    const [selectedId, setSelectedId] = useState<string | null>(null)
    const [isSheetOpen, setIsSheetOpen] = useState(false)

    // Search & Pagination state
    const [searchQuery, setSearchQuery] = useState("")
    const [page, setPage] = useState(1)
    const [totalPages, setTotalPages] = useState(1)
    const [totalNegotiations, setTotalNegotiations] = useState(0)
    const [hasMore, setHasMore] = useState(false)

    useEffect(() => {
        fetchNegotiations(1, true)
    }, [])

    async function fetchNegotiations(pageNum: number = 1, reset: boolean = false) {
        if (reset) {
            setIsLoading(true)
            setPage(1)
        } else {
            setIsLoadingMore(true)
        }

        try {
            const params = new URLSearchParams()
            params.append('page', pageNum.toString())
            params.append('limit', '20')
            if (searchQuery.trim()) {
                params.append('search', searchQuery.trim())
            }

            const res = await apiFetch(`/admin/negotiations?${params.toString()}`)
            const data = await res.json()
            if (res.ok) {
                const items = data.data || []
                const pagination = data.pagination || {}

                if (reset || pageNum === 1) {
                    setNegotiations(items)
                } else {
                    setNegotiations(prev => [...prev, ...items])
                }

                setTotalPages(pagination.totalPages || 1)
                setTotalNegotiations(pagination.total || items.length)
                setHasMore((pagination.page || 1) < (pagination.totalPages || 1))
            } else {
                toast.error("Failed to fetch requirements")
            }
        } catch (error) {
            console.error(error)
            toast.error("Error connecting to server")
        } finally {
            setIsLoading(false)
            setIsLoadingMore(false)
        }
    }

    const handleSearch = useCallback((e: React.FormEvent) => {
        e.preventDefault()
        fetchNegotiations(1, true)
    }, [searchQuery])

    const loadMore = useCallback(() => {
        if (hasMore && !isLoadingMore) {
            const nextPage = page + 1
            setPage(nextPage)
            fetchNegotiations(nextPage, false)
        }
    }, [hasMore, isLoadingMore, page])

    function openDetails(id: string) {
        setSelectedId(id)
        setIsSheetOpen(true)
    }

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'pending': return <Badge variant="outline" className="text-yellow-500 border-yellow-500">Requirement Sent</Badge>
            case 'accepted': return <Badge variant="outline" className="text-amber-400 border-amber-400">Accepted · Order Pending</Badge>
            case 'converted': return <Badge variant="outline" className="text-indigo-400 border-indigo-400">Order Created</Badge>
            case 'rejected': return <Badge variant="outline" className="text-red-500 border-red-500">Requirement Declined</Badge>
            case 'countered': return <Badge variant="outline" className="text-blue-500 border-blue-500">New Price Sent</Badge>
            case 'expired': return <Badge variant="outline" className="text-gray-500 border-gray-500">Requirement Expired</Badge>
            default: return <Badge variant="outline" className="text-gray-500 border-gray-500">{status}</Badge>
        }
    }

    return (
        <div className="flex flex-col gap-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-bold text-white">Deal Desk</h1>
                    <p className="text-gray-400 text-sm">{totalNegotiations > 0 && `(${totalNegotiations} requirements)`}</p>
                </div>
            </div>

            {/* Search Bar */}
            <form onSubmit={handleSearch} className="flex items-center gap-3">
                <div className="relative flex-1 max-w-md">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                    <Input
                        type="text"
                        placeholder="Search requirements..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="pl-10 bg-[#161616] border-[#333] text-white placeholder:text-gray-500 focus-visible:ring-[#818cf8]"
                    />
                </div>
                <Button
                    type="submit"
                    variant="outline"
                    className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]"
                >
                    Search
                </Button>
                {searchQuery && (
                    <Button
                        type="button"
                        variant="ghost"
                        onClick={() => {
                            setSearchQuery("")
                            fetchNegotiations(1, true)
                        }}
                        className="text-gray-400 hover:text-white"
                    >
                        Clear
                    </Button>
                )}
            </form>

            <Card className="bg-[#161616] border-[#333]">
                <CardHeader>
                    <CardTitle className="text-white">Active Requests</CardTitle>
                </CardHeader>
                <CardContent>
                    {isLoading ? (
                        <div className="flex justify-center p-8">
                            <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
                        </div>
                    ) : negotiations.length === 0 ? (
                        <div className="text-center text-gray-500 py-10">No requirements found</div>
                    ) : (
                        <Table>
                            <TableHeader>
                                <TableRow className="border-[#333] hover:bg-[#1A1A1A]">
                                    <TableHead className="text-gray-400">ID</TableHead>
                                    <TableHead className="text-gray-400">Wholesaler</TableHead>
                                    <TableHead className="text-gray-400">Product</TableHead>
                                    <TableHead className="text-gray-400 text-right">Qty</TableHead>
                                    <TableHead className="text-gray-400 text-right">Req. Price</TableHead>
                                    <TableHead className="text-gray-400 text-center">Status</TableHead>
                                    <TableHead className="text-gray-400">Approved By</TableHead>
                                    <TableHead className="text-gray-400 text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {negotiations.map((negotiation) => (
                                    <TableRow key={negotiation.id} className="border-[#333] hover:bg-[#1A1A1A]">
                                        <TableCell className="text-white font-medium">{negotiation.negotiationNumber}</TableCell>
                                        <TableCell className="text-white">{negotiation.wholesaler?.name || 'Unknown'}</TableCell>
                                        <TableCell className="text-gray-400">{negotiation.product?.name || 'Unknown'}</TableCell>
                                        <TableCell className="text-white text-right">{negotiation.requestedQuantity}</TableCell>
                                        <TableCell className="text-white text-right">₹{negotiation.requestedPricePerUnit.toLocaleString()}</TableCell>
                                        <TableCell className="text-center">
                                            {getStatusBadge(negotiation.status)}
                                        </TableCell>
                                        <TableCell className="text-gray-300 text-sm">
                                            {negotiation.approvedBy
                                                ? `${isMemberRole(negotiation.approvedBy.role) ? 'Member' : 'Admin'} · ${negotiation.approvedBy.name}`
                                                : <span className="text-gray-600">—</span>}
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                                                onClick={() => openDetails(negotiation.id)}
                                            >
                                                <MessageSquare className="h-4 w-4" />
                                            </Button>
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    )}
                </CardContent>
            </Card>

            <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
                <SheetContent className="bg-white text-slate-900 w-[500px] sm:w-[560px] sm:max-w-[560px] max-w-[95vw] flex flex-col overflow-y-auto border-l border-slate-200">
                    {selectedId && (
                        <NegotiationChatPanel
                            negotiationId={selectedId}
                            onChanged={() => fetchNegotiations(1, true)}
                        />
                    )}
                </SheetContent>
            </Sheet>

            {/* Load More Button */}
            {hasMore && negotiations.length > 0 && (
                <div className="flex justify-center pt-4">
                    <Button
                        onClick={loadMore}
                        disabled={isLoadingMore}
                        variant="outline"
                        className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] min-w-[200px]"
                    >
                        {isLoadingMore ? (
                            <>
                                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                Loading...
                            </>
                        ) : (
                            `Load More (${negotiations.length}/${totalNegotiations})`
                        )}
                    </Button>
                </div>
            )}
        </div>
    )
}

function NegotiationChatPanel({ negotiationId, onChanged }: { negotiationId: string; onChanged: () => void }) {
    const router = useRouter()
    const [detail, setDetail] = useState<NegotiationDetail | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [isSubmitting, setIsSubmitting] = useState(false)

    // Chat message input
    const [chatMessage, setChatMessage] = useState("")
    const [isSendingMessage, setIsSendingMessage] = useState(false)

    // Counter offer state
    const [counterPrice, setCounterPrice] = useState("")
    const [counterMessage, setCounterMessage] = useState("")

    // Reject dialog
    const [isRejectOpen, setIsRejectOpen] = useState(false)
    const [rejectReason, setRejectReason] = useState("")

    // Accept (confirm order) dialog + address form
    const [isAcceptOpen, setIsAcceptOpen] = useState(false)
    const [address, setAddress] = useState<ShippingAddress>(EMPTY_ADDRESS)
    const [customerNote, setCustomerNote] = useState("")
    const [addressTouched, setAddressTouched] = useState(false)

    const bottomRef = useRef<HTMLDivElement | null>(null)
    const detailRequestSequence = useRef(0)
    const handledSocketRevision = useRef({ negotiationId, message: 0, reconnect: 0 })
    const handledActionAt = useRef(0)

    const currentUser = (typeof window !== 'undefined' ? getUser() : null) as { _id?: string; id?: string; name?: string } | null
    const socketUserId = currentUser?._id || currentUser?.id || ""
    const socketUsername = currentUser?.name || "Admin"

    const { isConnected, messageRevision, reconnectRevision, typingUsers, lastAction, emitTyping, emitStopTyping } = useNegotiationSocket(
        negotiationId,
        socketUserId,
        socketUsername
    )

    const fetchDetail = useCallback(async (silent = false) => {
        const requestSequence = ++detailRequestSequence.current
        try {
            const res = await apiFetch(`/admin/negotiations/${negotiationId}`)
            const data = await res.json()
            if (requestSequence !== detailRequestSequence.current) return
            if (res.ok) {
                setDetail(data.data)
            } else if (!silent) {
                toast.error(data?.message || "Failed to load details")
            }
        } catch {
            if (requestSequence === detailRequestSequence.current && !silent) {
                toast.error("Failed to load details")
            }
        } finally {
            if (requestSequence === detailRequestSequence.current) setIsLoading(false)
        }
    }, [negotiationId])

    useEffect(() => {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setIsLoading(true)
        setDetail(null)
        setAddress(EMPTY_ADDRESS)
        setAddressTouched(false)
        setCustomerNote("")
        setCounterPrice("")
        setCounterMessage("")
        setChatMessage("")
        fetchDetail(false)
    }, [negotiationId, fetchDetail])

    useEffect(() => {
        const handled = handledSocketRevision.current
        if (handled.negotiationId !== negotiationId) {
            handledSocketRevision.current = {
                negotiationId,
                message: messageRevision,
                reconnect: reconnectRevision,
            }
            return
        }
        if (handled.message === messageRevision && handled.reconnect === reconnectRevision) return
        if (!detail) return
        handledSocketRevision.current = {
            negotiationId,
            message: messageRevision,
            reconnect: reconnectRevision,
        }
        // eslint-disable-next-line react-hooks/set-state-in-effect
        fetchDetail(true)
    }, [negotiationId, messageRevision, reconnectRevision, detail, fetchDetail])

    // Live updates from wholesaler / member actions
    useEffect(() => {
        if (!lastAction || !detail || handledActionAt.current === lastAction.at) return
        const actionNegotiationId = (lastAction.payload as { negotiationId?: string })?.negotiationId
        if (actionNegotiationId && String(actionNegotiationId) !== negotiationId) {
            handledActionAt.current = lastAction.at
            return
        }
        handledActionAt.current = lastAction.at
        if (lastAction.kind === 'negotiation-accepted') {
            toast.success("Deal accepted — order created")
        }
        // eslint-disable-next-line react-hooks/set-state-in-effect
        fetchDetail(true)
    }, [lastAction, detail, negotiationId, fetchDetail])

    // Prefill address form once detail loads
    useEffect(() => {
        if (!detail || addressTouched) return
        const w = detail.wholesalerId
        const base = detail.lastOrderAddress
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setAddress({
            fullName: base?.fullName || w?.name || "",
            phone: base?.phone || w?.phone || "",
            addressLine1: base?.addressLine1 || w?.address || w?.businessInfo?.businessAddress || "",
            addressLine2: base?.addressLine2 || w?.businessInfo?.businessName || "",
            city: base?.city || "",
            state: base?.state || "",
            pincode: base?.pincode || "",
        })
    }, [detail, addressTouched])

    // Auto-scroll chat to bottom on new entries
    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' })
    }, [detail?.history?.length])

    // Polling fallback while the realtime socket is disconnected.
    useEffect(() => {
        if (isConnected) return
        const timer = window.setInterval(() => {
            fetchDetail(true)
        }, 15000)
        return () => window.clearInterval(timer)
    }, [isConnected, fetchDetail])

    async function sendChatMessage() {
        const text = chatMessage.trim()
        if (!text || isSendingMessage) return
        setIsSendingMessage(true)
        emitStopTyping()
        try {
            const res = await apiFetch(`/admin/negotiations/${negotiationId}/message`, {
                method: 'POST',
                body: JSON.stringify({ message: text }),
            })
            const data = await res.json().catch(() => ({}))
            if (res.ok) {
                setChatMessage("")
                await fetchDetail()
            } else {
                toast.error(data?.message || "Failed to send message")
            }
        } catch {
            toast.error("Error sending message")
        } finally {
            setIsSendingMessage(false)
        }
    }

    async function sendCounter() {
        const price = Number(counterPrice)
        if (!price || price <= 0) {
            toast.error("Enter a valid unit price")
            return
        }
        setIsSubmitting(true)
        try {
            const res = await apiFetch(`/admin/negotiations/${negotiationId}/counter`, {
                method: 'PUT',
                body: JSON.stringify({ pricePerUnit: price, message: counterMessage || undefined }),
            })
            const data = await res.json().catch(() => ({}))
            if (res.ok) {
                toast.success("Counter price sent")
                setCounterPrice("")
                setCounterMessage("")
                await fetchDetail()
                onChanged()
            } else {
                toast.error(data?.message || "Counter failed")
            }
        } catch {
            toast.error("Error processing request")
        } finally {
            setIsSubmitting(false)
        }
    }

    async function confirmAccept() {
        if (!isAddressComplete(address)) {
            toast.error("Enter the full shipping address before creating the order")
            return
        }
        setIsSubmitting(true)
        try {
            const res = await apiFetch(`/admin/negotiations/${negotiationId}/accept`, {
                method: 'PUT',
                body: JSON.stringify({
                    message: `Accepted by ${currentUser?.name || 'TradeHub Demo'}`,
                    shippingAddress: address,
                    customerNote: customerNote || undefined,
                }),
            })
            const data = await res.json().catch(() => ({}))
            if (res.ok && (!data?.data?.orderId || !data?.data?.orderNumber)) {
                toast.error("The request completed, but no valid order reference was returned. Refresh and verify the order before retrying.")
                await fetchDetail()
                onChanged()
            } else if (res.ok) {
                toast.success(`Deal accepted. Order ${data.data.orderNumber} was created and the dealer was notified.`)
                setIsAcceptOpen(false)
                await fetchDetail()
                onChanged()
            } else {
                toast.error(data?.message || "Accept failed")
            }
        } catch {
            toast.error("Error processing request")
        } finally {
            setIsSubmitting(false)
        }
    }

    async function confirmReject() {
        setIsSubmitting(true)
        try {
            const res = await apiFetch(`/admin/negotiations/${negotiationId}/reject`, {
                method: 'PUT',
                body: JSON.stringify({ reason: rejectReason || undefined }),
            })
            const data = await res.json().catch(() => ({}))
            if (res.ok) {
                toast.success("Requirement declined")
                setIsRejectOpen(false)
                setRejectReason("")
                await fetchDetail()
                onChanged()
            } else {
                toast.error(data?.message || "Reject failed")
            }
        } catch {
            toast.error("Error processing request")
        } finally {
            setIsSubmitting(false)
        }
    }

    if (isLoading || !detail) {
        return (
            <div className="flex flex-1 items-center justify-center">
                <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
            </div>
        )
    }

    const canAdminRespond =
        (detail.status === 'pending' || detail.status === 'countered') &&
        !detail.orderId
    const canCreateMissingOrder = detail.status === 'accepted' && !detail.orderId
    const canAccept = canAdminRespond || canCreateMissingOrder
    const canReject = detail.status === 'pending' || detail.status === 'countered'
    const canChat = !['rejected', 'expired'].includes(detail.status)
    const orderObj = (detail.orderId && typeof detail.orderId === 'object' ? detail.orderId : null) as { _id: string; orderNumber: string; status: string; total: number; trackingNumber?: string; courierName?: string } | null
    const orderReference = orderObj?._id || (typeof detail.orderId === 'string' ? detail.orderId : null)
    const orderTotal = detail.finalTotalPrice ?? detail.currentTotalPrice ?? 0
    const livePrice = detail.currentPricePerUnit ?? detail.requestedPricePerUnit ?? 0
    const liveTotal = detail.currentTotalPrice ?? (detail.requestedQuantity * (detail.requestedPricePerUnit ?? 0))
    const liveByLabel = detail.currentOfferBy === 'admin' ? 'TradeHub Demo' : 'Dealer'
    const dealerDisplayName = detail.wholesalerId?.businessInfo?.businessName || detail.wholesalerId?.name || 'Dealer'

    return (
        <>
            <SheetHeader>
                <SheetTitle className="text-slate-900">Requirement Details</SheetTitle>
                <SheetDescription className="text-slate-500">
                    {detail.negotiationNumber} · {detail.productSnapshot?.name}
                </SheetDescription>
                <SheetDescription className="text-slate-500">
                    {detail.wholesalerId?.businessInfo?.businessName || detail.wholesalerId?.name || 'Wholesaler'}
                    {detail.wholesalerId?.phone ? ` · ${detail.wholesalerId.phone}` : ''} · Qty {detail.requestedQuantity}
                </SheetDescription>
                <div className="flex items-center gap-2 pt-2 text-xs">
                    <span className={`inline-flex items-center rounded-full border px-2.5 py-0.5 font-medium capitalize ${statusColor(detail.status)}`}>
                        {statusLabel(detail.status)}
                    </span>
                    {detail.approvedBy && (
                        <span className="text-slate-500">
                            Accepted by {detail.approvedBy.name}
                        </span>
                    )}
                    <span className={`ml-auto inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 font-medium ${isConnected ? 'bg-indigo-50 text-indigo-700' : 'bg-slate-100 text-slate-500'}`}>
                        <span className={`h-1.5 w-1.5 rounded-full ${isConnected ? 'bg-indigo-500' : 'bg-slate-400'}`} />
                        {isConnected ? 'Live' : 'Offline'}
                    </span>
                </div>
            </SheetHeader>

            <div className="flex flex-1 flex-col gap-4 mt-4 overflow-hidden">
                {/* Summary Card */}
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-4">
                    <div className="grid grid-cols-2 gap-x-4 gap-y-3">
                        <div>
                            <span className="text-[11px] font-medium uppercase tracking-wide text-slate-500">Original Price</span>
                            <p className="font-mono text-lg text-slate-900">₹{detail.productSnapshot?.price}</p>
                        </div>
                        <div className="text-right">
                            <span className="text-[11px] font-medium uppercase tracking-wide text-slate-500">Requested Qty</span>
                            <p className="font-mono text-lg text-slate-900">{detail.requestedQuantity}</p>
                        </div>
                        <div>
                            <span className="text-[11px] font-medium uppercase tracking-wide text-slate-500">Requested Price</span>
                            <p className="font-mono text-lg text-slate-900">₹{detail.requestedPricePerUnit}</p>
                        </div>
                        <div className="text-right">
                            <span className="text-[11px] font-medium uppercase tracking-wide text-slate-500">Requested Total</span>
                            <p className="font-mono text-lg text-slate-900">₹{(detail.requestedQuantity * detail.requestedPricePerUnit).toLocaleString()}</p>
                        </div>
                    </div>
                    <div className="mt-3 flex items-center justify-between rounded-lg bg-blue-50 px-3 py-2">
                        <span className="text-xs font-medium text-blue-700">Current offer · {liveByLabel}</span>
                        <span className="font-mono text-base font-bold text-blue-700">₹{livePrice.toLocaleString()} <span className="text-xs font-medium text-blue-500">/unit · ₹{liveTotal.toLocaleString()}</span></span>
                    </div>
                </div>

                {/* Order Created chip + tracking mirror */}
                {orderReference && (
                    <button
                        type="button"
                        onClick={() => router.push(`/orders?orderId=${encodeURIComponent(orderReference)}`)}
                        className="flex items-center gap-3 rounded-lg border border-indigo-200 bg-indigo-50 p-3 text-left transition-colors hover:bg-indigo-100"
                    >
                        <Package className="h-5 w-5 shrink-0 text-indigo-600" />
                        <span>
                            <span className="block text-sm font-semibold text-indigo-800">Order Created{orderObj?.orderNumber ? ` · ${orderObj.orderNumber}` : ''}</span>
                            {orderObj ? <span className="block text-xs text-indigo-700 capitalize">
                                {(orderObj.status ?? 'pending_payment')?.replace(/_/g, ' ')} · ₹{(orderObj.total ?? orderTotal).toLocaleString()} · {(orderObj.trackingNumber ?? '') ? `LR ${orderObj.trackingNumber}${orderObj.courierName ? ` · ${orderObj.courierName}` : ''} · ` : ''}tap to open order
                            </span> : <span className="block text-xs text-indigo-700">Tap to open order</span>}
                        </span>
                    </button>
                )}

                <Separator className="bg-slate-200" />

                {/* Live chat */}
                <div className="flex min-h-0 flex-1 flex-col">
                    <h3 className="mb-2 text-sm font-semibold text-slate-900">Chat</h3>
                    <ScrollArea className="min-h-0 flex-1 rounded-xl border border-slate-200 bg-slate-100/70 p-3 pr-4">
                        <div className="space-y-3">
                            {detail.history.map((entry, idx) => {
                                if (entry.action === 'accepted') {
                                    return (
                                        <AcceptCard
                                            key={idx}
                                            name={actorDisplayName(entry, dealerDisplayName)}
                                            pricePerUnit={entry.pricePerUnit}
                                            timestamp={entry.timestamp}
                                            note={acceptNote(entry)}
                                            orderCreated={detail.status === 'converted' && Boolean(detail.orderId)}
                                        />
                                    )
                                }
                                const isAdmin = entry.by === 'admin'
                                const actionLabel = entry.action === 'message'
                                    ? actorDisplayName(entry, dealerDisplayName)
                                    : entry.action === 'requested' ? 'Requirement Sent'
                                    : entry.action === 'countered' ? `New Price · ${actorDisplayName(entry, dealerDisplayName)}`
                                    : entry.action === 'rejected' ? `Declined · ${actorDisplayName(entry, dealerDisplayName)}`
                                    : entry.action
                                return (
                                <div key={idx} className={`flex flex-col gap-0.5 ${isAdmin ? 'items-end' : 'items-start'}`}>
                                    <div className={`max-w-[85%] px-3 py-2 shadow-sm ${isAdmin ? 'rounded-2xl rounded-br-md bg-indigo-600 text-white' : 'rounded-2xl rounded-bl-md border border-slate-200 bg-white text-slate-800'}`}>
                                        <div className="mb-0.5 flex items-center justify-between gap-3">
                                            <span className={`text-[11px] font-bold uppercase tracking-wide ${isAdmin ? 'text-indigo-100' : 'text-blue-600'}`}>
                                                {actionLabel}
                                            </span>
                                            {entry.pricePerUnit != null && <span className={`rounded-full px-2 py-0.5 font-mono text-[11px] font-bold ${isAdmin ? 'bg-white/20 text-white' : 'bg-blue-50 text-blue-700'}`}>₹{entry.pricePerUnit}</span>}
                                        </div>
                                        {entry.message && <p className="whitespace-pre-wrap text-sm leading-snug">{entry.message}</p>}
                                        <span className={`mt-1 block text-right text-[10px] ${isAdmin ? 'text-indigo-100/70' : 'text-slate-400'}`}>
                                            {entry.timestamp ? new Date(entry.timestamp).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : ''}
                                        </span>
                                    </div>
                                </div>
                                )
                            })}
                            <div ref={bottomRef} />
                        </div>
                    </ScrollArea>
                    {typingUsers.length > 0 && (
                        <p className="pt-1 text-xs italic text-slate-500">Wholesaler is typing…</p>
                    )}

                    {/* Message composer */}
                    {canChat ? (
                        <div className="flex gap-2 pt-2">
                            <Input
                                placeholder="Type a message… (max 280)"
                                maxLength={280}
                                className="h-10 flex-1 border-slate-200 bg-white text-slate-900"
                                value={chatMessage}
                                onChange={(e) => {
                                    setChatMessage(e.target.value)
                                    if (e.target.value.trim()) emitTyping()
                                    else emitStopTyping()
                                }}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter' && !e.shiftKey) {
                                        e.preventDefault()
                                        sendChatMessage()
                                    }
                                }}
                            />
                            <Button
                                size="sm"
                                className="bg-blue-600 hover:bg-blue-700 text-white h-10 px-4"
                                disabled={!chatMessage.trim() || isSendingMessage}
                                onClick={sendChatMessage}
                            >
                                {isSendingMessage ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                            </Button>
                        </div>
                    ) : (
                        <p className="pt-2 text-center text-xs text-slate-400">This requirement is closed.</p>
                    )}
                </div>

                {/* Actions */}
                <div className="space-y-3 border-t border-slate-200 pt-3">
                    {canAdminRespond && (
                        <div className="space-y-2 rounded-xl border border-slate-200 bg-slate-50 p-3">
                            <Label className="text-[11px] font-medium uppercase tracking-wide text-slate-500">Send Counter Price</Label>
                            <div className="flex gap-2">
                                <Input
                                    type="number"
                                    placeholder="₹ per unit"
                                    className="h-9 w-32 border-slate-200 bg-white text-slate-900"
                                    value={counterPrice}
                                    onChange={(e) => setCounterPrice(e.target.value)}
                                />
                                <Input
                                    placeholder="Message (optional)"
                                    className="h-9 flex-1 border-slate-200 bg-white text-slate-900"
                                    value={counterMessage}
                                    onChange={(e) => setCounterMessage(e.target.value)}
                                />
                                <Button
                                    size="sm"
                                    className="bg-blue-600 hover:bg-blue-700 text-white"
                                    disabled={!counterPrice || isSubmitting}
                                    onClick={sendCounter}
                                >
                                    <Send className="h-4 w-4" />
                                </Button>
                            </div>
                        </div>
                    )}

                    {canAccept && (
                        <Button
                            className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold"
                            disabled={isSubmitting}
                            onClick={() => setIsAcceptOpen(true)}
                        >
                            <Check className="mr-2 h-4 w-4" />
                            {canCreateMissingOrder ? 'Create Missing Order' : `Accept Deal & Create Order · ₹${liveTotal.toLocaleString()}`}
                        </Button>
                    )}

                    {canReject && (
                        <Button
                            variant="outline"
                            className="w-full border-slate-200 bg-transparent text-slate-500 hover:bg-red-50 hover:text-red-600 hover:border-red-200"
                            disabled={isSubmitting}
                            onClick={() => setIsRejectOpen(true)}
                        >
                            <X className="mr-2 h-4 w-4" /> Reject
                        </Button>
                    )}
                </div>
            </div>

            {/* Reject dialog */}
            <Dialog open={isRejectOpen} onOpenChange={setIsRejectOpen}>
                <DialogContent className="border-slate-200 bg-white text-slate-900">
                    <DialogHeader>
                        <DialogTitle>Reject requirement?</DialogTitle>
                        <DialogDescription className="text-slate-500">
                            The dealer will be notified with your reason.
                        </DialogDescription>
                    </DialogHeader>
                    <Textarea
                        placeholder="Rejection reason (optional)"
                        className="border-slate-200 bg-white text-slate-900"
                        value={rejectReason}
                        onChange={(e) => setRejectReason(e.target.value)}
                    />
                    <DialogFooter>
                        <Button variant="ghost" className="text-slate-600" onClick={() => setIsRejectOpen(false)}>Cancel</Button>
                        <Button className="bg-red-600 hover:bg-red-700" disabled={isSubmitting} onClick={confirmReject}>
                            {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Reject'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Accept / confirm-order dialog with address */}
            <Dialog open={isAcceptOpen} onOpenChange={setIsAcceptOpen}>
                <DialogContent className="border-slate-200 bg-white text-slate-900 max-w-lg">
                    <DialogHeader>
                        <DialogTitle>{canCreateMissingOrder ? 'Create Missing Order' : 'Accept Deal & Create Order'}</DialogTitle>
                        <DialogDescription className="text-slate-500">
                            {detail.requestedQuantity} × ₹{(detail.currentPricePerUnit ?? 0).toLocaleString()} = ₹{orderTotal.toLocaleString()}.
                            This will create a pending-payment order using the terms shown. The dealer cannot accept or create the order.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="grid grid-cols-2 gap-3">
                        <div className="col-span-1">
                            <Label className="text-xs text-slate-500">Full name *</Label>
                            <Input required className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.fullName} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, fullName: e.target.value }) }} />
                        </div>
                        <div className="col-span-1">
                            <Label className="text-xs text-slate-500">Phone *</Label>
                            <Input required className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.phone} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, phone: e.target.value }) }} />
                        </div>
                        <div className="col-span-2">
                            <Label className="text-xs text-slate-500">Address line 1 *</Label>
                            <Input required className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.addressLine1} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, addressLine1: e.target.value }) }} />
                        </div>
                        <div className="col-span-2">
                            <Label className="text-xs text-slate-500">Address line 2</Label>
                            <Input className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.addressLine2 || ''} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, addressLine2: e.target.value }) }} />
                        </div>
                        <div className="col-span-1">
                            <Label className="text-xs text-slate-500">City *</Label>
                            <Input required className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.city} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, city: e.target.value }) }} />
                        </div>
                        <div className="col-span-1">
                            <Label className="text-xs text-slate-500">State *</Label>
                            <Input required className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.state} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, state: e.target.value }) }} />
                        </div>
                        <div className="col-span-1">
                            <Label className="text-xs text-slate-500">Pincode *</Label>
                            <Input required className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={address.pincode} onChange={(e) => { setAddressTouched(true); setAddress({ ...address, pincode: e.target.value }) }} />
                        </div>
                        <div className="col-span-1">
                            <Label className="text-xs text-slate-500">Note for order</Label>
                            <Input className="border-slate-200 bg-white h-9 mt-1 text-slate-900" value={customerNote} onChange={(e) => setCustomerNote(e.target.value)} />
                        </div>
                    </div>
                    <DialogFooter>
                        <Button variant="ghost" className="text-slate-600" onClick={() => setIsAcceptOpen(false)}>Cancel</Button>
                        <Button className="bg-blue-600 hover:bg-blue-700 text-white" disabled={isSubmitting || !isAddressComplete(address)} onClick={confirmAccept}>
                            {isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : canCreateMissingOrder ? 'Create Order' : `Accept · ₹${orderTotal.toLocaleString()}`}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    )
}

function statusColor(status: string): string {
    switch (status) {
        case 'pending': return 'bg-amber-50 text-amber-700 border-amber-200'
        case 'accepted': return 'bg-indigo-50 text-indigo-700 border-indigo-200'
        case 'converted': return 'bg-indigo-50 text-indigo-700 border-indigo-200'
        case 'rejected': return 'bg-red-50 text-red-700 border-red-200'
        case 'countered': return 'bg-blue-50 text-blue-700 border-blue-200'
        case 'expired': return 'bg-slate-100 text-slate-500 border-slate-200'
        default: return 'bg-slate-100 text-slate-500 border-slate-200'
    }
}
