"use client"

import { useEffect, useRef, useState } from "react"
import { apiFetch } from "@/lib/api"
import { displayActivityText } from "@/lib/role-labels"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { CheckCircle2, Eye, Loader2, MapPin, Package, Search, Truck } from "@/components/hugeicons"

type OrderItem = {
  productSnapshot?: { name?: string }
  quantity: number
  pricePerUnit: number
}

type Order = {
  _id: string
  orderNumber: string
  items: OrderItem[]
  customerSnapshot: { name: string; email?: string; phone: string }
  total: number
  status: string
  orderType?: string
  acceptanceStatus?: "pending" | "accepted" | "rejected" | null
  acceptedAt?: string
  acceptedBy?: string | { name?: string; email?: string }
  rejectedAt?: string
  rejectedBy?: string | { name?: string; email?: string }
  rejectionReason?: string
  inventoryCommittedAt?: string
  inventoryReleasedAt?: string
  createdAt: string
  trackingNumber?: string
  courierName?: string
  shippingAddress?: {
    fullName?: string
    phone?: string
    addressLine1?: string
    addressLine2?: string
    city?: string
    state?: string
    pincode?: string
  }
  statusHistory?: { status: string; note?: string; timestamp: string }[]
  payment?: {
    _id: string
    amount: number
    method?: string
    upiId?: string
    screenshotUrl?: string
    status: string
    holdReason?: string
  } | null
}

function formatStatusLabel(status: string) {
  return status.replace(/_/g, " ").replace(/\b\w/g, (character) => character.toUpperCase())
}

function getStatusColor(status: string) {
  switch (status) {
    case "delivered":
    case "payment_verified":
      return "bg-indigo-50 text-indigo-700"
    case "payment_uploaded":
    case "processing":
      return "bg-blue-50 text-blue-700"
    case "shipped":
      return "bg-violet-50 text-violet-700"
    case "pending_payment":
      return "bg-amber-50 text-amber-700"
    default:
      return "bg-slate-100 text-slate-600"
  }
}

function formatActor(actor?: Order["acceptedBy"]) {
  if (!actor) return "Unknown"
  if (typeof actor === "string") return actor
  return actor.name || actor.email || "Unknown"
}

function canCompletePayment(order: Order) {
  return order.acceptanceStatus == null || order.acceptanceStatus === "accepted"
}

export default function MemberOrdersPage() {
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingMore, setIsLoadingMore] = useState(false)
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null)
  const [isDetailsOpen, setIsDetailsOpen] = useState(false)
  const [isShipDialogOpen, setIsShipDialogOpen] = useState(false)
  const [isShipping, setIsShipping] = useState(false)
  const [isApproving, setIsApproving] = useState(false)
  const [isHolding, setIsHolding] = useState(false)
  const [isMarkingPayment, setIsMarkingPayment] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const [page, setPage] = useState(1)
  const [totalOrders, setTotalOrders] = useState(0)
  const [hasMore, setHasMore] = useState(false)
  const [courierName, setCourierName] = useState("")
  const [trackingNumber, setTrackingNumber] = useState("")
  const [holdReason, setHoldReason] = useState("")
  const [acceptanceFilter, setAcceptanceFilter] = useState<"all" | "pending">("all")
  const [pendingApprovalCount, setPendingApprovalCount] = useState(0)
  const [acceptanceAction, setAcceptanceAction] = useState<{ orderId: string; type: "accept" | "reject" } | null>(null)
  const acceptanceActionLock = useRef(false)
  const [rejectOrder, setRejectOrder] = useState<Order | null>(null)
  const [rejectionReason, setRejectionReason] = useState("")

  async function fetchOrders(pageNumber = 1, reset = false, searchOverride?: string, acceptanceOverride?: "all" | "pending") {
    if (reset) {
      setIsLoading(true)
      setPage(1)
    } else {
      setIsLoadingMore(true)
    }

    try {
      const params = new URLSearchParams({ page: String(pageNumber), limit: "20" })
      const search = typeof searchOverride === "string" ? searchOverride : searchQuery
      if (search.trim()) params.set("search", search.trim())
      const effectiveAcceptance = acceptanceOverride ?? acceptanceFilter
      if (effectiveAcceptance === "pending") params.set("acceptanceStatus", "pending")

      const response = await apiFetch(`/staff/orders?${params.toString()}`)
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Failed to fetch orders")

      const items = data.data || []
      const pagination = data.pagination || {}
      setOrders((previous) => reset || pageNumber === 1 ? items : [...previous, ...items])
      setTotalOrders(pagination.total || items.length)
      setPendingApprovalCount(data.approvalCounts?.pending || 0)
      setHasMore((pagination.page || 1) < (pagination.totalPages || 1))
    } catch (error: any) {
      toast.error(error.message || "Failed to fetch orders")
    } finally {
      setIsLoading(false)
      setIsLoadingMore(false)
    }
  }

  useEffect(() => {
    void fetchOrders(1, true, "")
  }, [])

  async function openOrderDetails(orderId: string) {
    try {
      const response = await apiFetch(`/staff/orders/${orderId}`)
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Failed to load order details")
      setSelectedOrder(data.data)
      setIsDetailsOpen(true)
    } catch (error: any) {
      toast.error(error.message || "Failed to load order details")
    }
  }

  async function approvePayment(paymentId: string) {
    if (!window.confirm("Approve this payment and move the order to processing?")) return
    setIsApproving(true)
    try {
      const response = await apiFetch(`/staff/payments/${paymentId}/approve`, { method: "PUT" })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Unable to approve payment")
      toast.success("Payment approved and order moved to processing")
      setIsDetailsOpen(false)
      await fetchOrders(1, true)
    } catch (error: any) {
      toast.error(error.message || "Unable to approve payment")
    } finally {
      setIsApproving(false)
    }
  }

  async function holdPayment(paymentId: string) {
    if (!holdReason.trim()) {
      toast.error("Enter a reason before holding this payment")
      return
    }
    setIsHolding(true)
    try {
      const response = await apiFetch(`/staff/payments/${paymentId}/hold`, {
        method: "PUT",
        body: JSON.stringify({ reason: holdReason.trim() }),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Unable to hold payment")
      toast.success("Payment was held for full-admin review")
      setHoldReason("")
      setIsDetailsOpen(false)
      await fetchOrders(1, true)
    } catch (error: any) {
      toast.error(error.message || "Unable to hold payment")
    } finally {
      setIsHolding(false)
    }
  }

  async function markPaymentCompleted() {
    if (!selectedOrder || !window.confirm("Mark this order payment as completed in office?")) return
    setIsMarkingPayment(true)
    try {
      const response = await apiFetch(`/staff/orders/${selectedOrder._id}/mark-payment-complete`, { method: "PUT" })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Unable to mark payment complete")
      toast.success("Payment marked as completed")
      await fetchOrders(1, true)
      await openOrderDetails(selectedOrder._id)
    } catch (error: any) {
      toast.error(error.message || "Unable to mark payment complete")
    } finally {
      setIsMarkingPayment(false)
    }
  }

  async function updateAcceptance(order: Order, action: "accept" | "reject", reason?: string) {
    if (acceptanceActionLock.current) return
    if (action === "reject" && !reason?.trim()) {
      toast.error("A rejection reason is required")
      return
    }

    acceptanceActionLock.current = true
    setAcceptanceAction({ orderId: order._id, type: action })
    try {
      const response = await apiFetch(`/staff/orders/${order._id}/${action}`, {
        method: "PUT",
        ...(action === "reject" ? { body: JSON.stringify({ reason: reason!.trim() }) } : {}),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || `Unable to ${action} order`)

      toast.success(action === "accept" ? "Order accepted" : "Order rejected")
      setRejectOrder(null)
      setRejectionReason("")
      await fetchOrders(1, true)
      if (isDetailsOpen && selectedOrder?._id === order._id) await openOrderDetails(order._id)
    } catch (error: any) {
      toast.error(error.message || `Unable to ${action} order`)
    } finally {
      acceptanceActionLock.current = false
      setAcceptanceAction(null)
    }
  }

  async function shipOrder() {
    if (!selectedOrder || !courierName.trim() || !trackingNumber.trim()) {
      toast.error("Enter courier name and tracking number")
      return
    }

    setIsShipping(true)
    try {
      const response = await apiFetch(`/staff/orders/${selectedOrder._id}/ship`, {
        method: "PUT",
        body: JSON.stringify({ courierName: courierName.trim(), trackingNumber: trackingNumber.trim() }),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || "Unable to ship order")
      toast.success("Order marked as shipped")
      setIsShipDialogOpen(false)
      setIsDetailsOpen(false)
      setCourierName("")
      setTrackingNumber("")
      await fetchOrders(1, true)
    } catch (error: any) {
      toast.error(error.message || "Unable to ship order")
    } finally {
      setIsShipping(false)
    }
  }

  const displayedOrders = orders

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900">Orders</h2>
        <p className="text-xs text-slate-500">{totalOrders > 0 ? `(${totalOrders} orders)` : "All customer orders"}</p>
      </div>

      <form
        onSubmit={(event) => { event.preventDefault(); void fetchOrders(1, true) }}
        className="flex flex-col gap-3 sm:flex-row sm:items-center"
      >
        <div className="relative w-full sm:max-w-md">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <Input
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
            placeholder="Search by order number, customer name, phone..."
            className="h-10 border-[#cacbdf] bg-white pl-10 text-slate-800 placeholder:text-slate-400 focus-visible:ring-[#818cf8]"
          />
        </div>
        <Button type="submit" variant="outline" className="h-10 border-[#cacbdf] bg-white text-slate-700 hover:bg-[#ececf8]">Search</Button>
        {searchQuery && <Button type="button" variant="ghost" className="h-10 text-slate-500" onClick={() => { setSearchQuery(""); void fetchOrders(1, true, "") }}>Clear</Button>}
      </form>

      <div className="flex flex-wrap gap-2" aria-label="Order approval filters">
        <Button type="button" size="sm" variant={acceptanceFilter === "all" ? "default" : "outline"} className={acceptanceFilter === "all" ? "bg-indigo-600 text-white hover:bg-indigo-700" : "border-[#cacbdf] bg-white text-slate-700"} onClick={() => { setAcceptanceFilter("all"); void fetchOrders(1, true, searchQuery, "all") }}>All Orders</Button>
        <Button type="button" size="sm" variant={acceptanceFilter === "pending" ? "default" : "outline"} className={acceptanceFilter === "pending" ? "bg-amber-500 text-white hover:bg-amber-600" : "border-[#cacbdf] bg-white text-slate-700"} onClick={() => { setAcceptanceFilter("pending"); void fetchOrders(1, true, searchQuery, "pending") }}>Awaiting Approval ({pendingApprovalCount})</Button>
      </div>

      <Card className="overflow-hidden border-[#d5d6e8] bg-white shadow-sm">
        <CardHeader className="border-b border-[#e7e7f0] px-5 py-4">
          <CardTitle className="text-sm font-bold text-slate-800">All Orders</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex justify-center p-12"><Loader2 className="h-7 w-7 animate-spin text-indigo-600" /></div>
          ) : displayedOrders.length === 0 ? (
            <div className="p-12 text-center text-sm text-slate-500">No orders found</div>
          ) : (
            <>
              <div className="space-y-3 p-4 md:hidden">
                {displayedOrders.map((order) => {
                  const totalItems = order.items.reduce((sum, item) => sum + item.quantity, 0)
                  return <article key={order._id} className="rounded-xl border border-[#d5d6e8] bg-[#f9f9fd] p-4">
                    <div className="flex items-start justify-between gap-3"><div><p className="font-semibold text-slate-800">{order.orderNumber}</p><p className="mt-1 text-xs text-slate-500">{order.customerSnapshot?.name} · {order.customerSnapshot?.phone}</p></div><span className={`rounded-full px-2.5 py-1 text-[10px] font-bold uppercase ${getStatusColor(order.status)}`}>{formatStatusLabel(order.status)}</span></div>
                    {order.acceptanceStatus === "pending" && <span className="mt-3 inline-flex rounded-full bg-amber-100 px-2.5 py-1 text-[10px] font-bold uppercase text-amber-800">Awaiting Approval</span>}
                    <div className="mt-3 flex items-end justify-between"><p className="text-xs text-slate-500">{totalItems} items · {order.items[0]?.productSnapshot?.name || "Product"}</p><div className="text-right"><p className="font-bold text-slate-900">Rs {order.total.toLocaleString("en-IN")}</p><div className="mt-1 flex gap-1">{order.acceptanceStatus === "pending" && <Button size="sm" className="h-8 bg-indigo-600 text-white hover:bg-indigo-700" disabled={acceptanceAction?.orderId === order._id} onClick={() => void updateAcceptance(order, "accept")}>{acceptanceAction?.orderId === order._id && acceptanceAction.type === "accept" ? <Loader2 className="h-4 w-4 animate-spin" /> : "Accept"}</Button>}<Button variant="ghost" size="sm" className="h-8 px-2 text-slate-600" aria-label={`View order ${order.orderNumber}`} onClick={() => void openOrderDetails(order._id)}><Eye className="mr-1 h-4 w-4" /> View</Button></div></div></div>
                  </article>
                })}
              </div>
              <div className="hidden overflow-x-auto md:block">
                <Table>
                  <TableHeader><TableRow className="border-[#e7e7f0] hover:bg-transparent"><TableHead className="px-5 text-[11px] font-semibold text-slate-500">Order #</TableHead><TableHead className="text-[11px] font-semibold text-slate-500">Customer</TableHead><TableHead className="text-[11px] font-semibold text-slate-500">Items</TableHead><TableHead className="text-right text-[11px] font-semibold text-slate-500">Total</TableHead><TableHead className="text-center text-[11px] font-semibold text-slate-500">Status</TableHead><TableHead className="px-5 text-right text-[11px] font-semibold text-slate-500">Actions</TableHead></TableRow></TableHeader>
                  <TableBody>{displayedOrders.map((order) => <TableRow key={order._id} className="border-[#e7e7f0] hover:bg-[#f1f1f9]"><TableCell className="px-5 py-3 text-xs font-semibold text-slate-800">{order.orderNumber}</TableCell><TableCell className="py-3 text-xs font-medium text-slate-700">{order.customerSnapshot?.name}</TableCell><TableCell className="py-3 text-[10px] text-slate-500">{order.items.length} items ({order.items[0]?.productSnapshot?.name || "Product"}...)</TableCell><TableCell className="py-3 text-right text-xs font-bold text-slate-800">Rs {order.total.toLocaleString("en-IN")}</TableCell><TableCell className="py-3 text-center">{order.acceptanceStatus === "pending" && <span className="mr-1 rounded-full bg-amber-100 px-2 py-1 text-[9px] font-bold uppercase text-amber-800">Awaiting Approval</span>}<span className={`rounded-full px-2 py-1 text-[9px] font-bold uppercase ${getStatusColor(order.status)}`}>{formatStatusLabel(order.status)}</span></TableCell><TableCell className="px-5 py-3 text-right"><div className="flex justify-end gap-1">{order.acceptanceStatus === "pending" && <Button size="sm" className="h-7 bg-indigo-600 px-2 text-[10px] text-white hover:bg-indigo-700" disabled={acceptanceAction?.orderId === order._id} onClick={() => void updateAcceptance(order, "accept")}>{acceptanceAction?.orderId === order._id && acceptanceAction.type === "accept" ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : "Accept"}</Button>}<Button variant="ghost" size="sm" className="h-7 w-7 rounded-full p-0 text-slate-600 hover:bg-[#e5e5f2]" aria-label={`View order ${order.orderNumber}`} onClick={() => void openOrderDetails(order._id)}><Eye className="h-3.5 w-3.5" /></Button></div></TableCell></TableRow>)}</TableBody>
                </Table>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      {hasMore && <div className="flex justify-center"><Button variant="outline" className="border-[#cacbdf] bg-white" disabled={isLoadingMore} onClick={() => { const nextPage = page + 1; setPage(nextPage); void fetchOrders(nextPage) }}>{isLoadingMore ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}Load more orders</Button></div>}

      <Dialog open={isDetailsOpen} onOpenChange={setIsDetailsOpen}>
        <DialogContent className="max-h-[90dvh] max-w-[95vw] overflow-y-auto overscroll-contain border-[#d1d2e6] bg-white text-slate-800 sm:max-w-2xl">
          <DialogHeader><DialogTitle>Order Details: {selectedOrder?.orderNumber}</DialogTitle><DialogDescription>Customer: {selectedOrder?.customerSnapshot?.name} | {selectedOrder?.customerSnapshot?.phone}</DialogDescription></DialogHeader>
          {selectedOrder && <div className="space-y-5">
            {(selectedOrder.inventoryCommittedAt || selectedOrder.inventoryReleasedAt) && <section className="rounded-lg border border-[#d8d9e9] bg-[#f9f9fd] p-4 text-sm"><h3 className="mb-3 font-semibold">Inventory</h3><div className="space-y-1 text-slate-600">{selectedOrder.inventoryCommittedAt && <p>Committed: {new Date(selectedOrder.inventoryCommittedAt).toLocaleString("en-IN")}</p>}{selectedOrder.inventoryReleasedAt && <p>Released: {new Date(selectedOrder.inventoryReleasedAt).toLocaleString("en-IN")}</p>}</div></section>}
            {selectedOrder.acceptanceStatus != null && <section className="rounded-lg border border-[#d8d9e9] bg-[#f9f9fd] p-4"><div className="flex flex-wrap items-center justify-between gap-3"><h3 className="text-sm font-semibold">Order Approval</h3><span className={`rounded-full px-3 py-1 text-[10px] font-bold uppercase ${selectedOrder.acceptanceStatus === "accepted" ? "bg-indigo-100 text-indigo-800" : selectedOrder.acceptanceStatus === "rejected" ? "bg-red-100 text-red-800" : "bg-amber-100 text-amber-800"}`}>{selectedOrder.acceptanceStatus === "pending" ? "Awaiting Approval" : selectedOrder.acceptanceStatus}</span></div>{selectedOrder.acceptanceStatus === "accepted" && <p className="mt-3 text-sm text-slate-600">Accepted by {formatActor(selectedOrder.acceptedBy)}{selectedOrder.acceptedAt ? ` on ${new Date(selectedOrder.acceptedAt).toLocaleString("en-IN")}` : ""}</p>}{selectedOrder.acceptanceStatus === "rejected" && <div className="mt-3 space-y-1 text-sm text-slate-600"><p>Rejected by {formatActor(selectedOrder.rejectedBy)}{selectedOrder.rejectedAt ? ` on ${new Date(selectedOrder.rejectedAt).toLocaleString("en-IN")}` : ""}</p><p><span className="text-slate-500">Reason:</span> {selectedOrder.rejectionReason || "Not recorded"}</p></div>}{selectedOrder.acceptanceStatus === "pending" && <div className="mt-4 flex flex-col gap-2 sm:flex-row"><Button className="bg-indigo-600 text-white hover:bg-indigo-700" disabled={acceptanceAction?.orderId === selectedOrder._id} onClick={() => void updateAcceptance(selectedOrder, "accept")}>{acceptanceAction?.orderId === selectedOrder._id && acceptanceAction.type === "accept" && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Accept Order</Button><Button variant="destructive" disabled={acceptanceAction?.orderId === selectedOrder._id} onClick={() => setRejectOrder(selectedOrder)}>Reject Order</Button></div>}</section>}
            <section className="rounded-lg border border-[#d8d9e9] bg-[#f9f9fd] p-4"><h3 className="mb-3 text-sm font-semibold">Payment Information</h3>{selectedOrder.payment ? <div className="space-y-3"><div className="grid gap-3 text-sm sm:grid-cols-2"><div><span className="block text-xs text-slate-500">Amount</span><span className="font-medium">Rs {selectedOrder.payment.amount.toLocaleString("en-IN")}</span></div><div><span className="block text-xs text-slate-500">Status</span><span className="font-medium capitalize">{selectedOrder.payment.status}</span></div></div>{selectedOrder.payment.screenshotUrl && <a href={selectedOrder.payment.screenshotUrl} target="_blank" className="inline-block text-sm font-semibold text-indigo-700 underline">Open payment proof</a>}{selectedOrder.payment.status === "held" && <p className="rounded bg-amber-50 p-2 text-xs text-amber-800">Held for full-admin review: {selectedOrder.payment.holdReason || "No reason recorded"}</p>}{selectedOrder.status === "payment_uploaded" && selectedOrder.payment.status === "pending" && <div className="space-y-3 border-t border-[#d8d9e9] pt-3"><div className="flex flex-col gap-2 sm:flex-row"><Button className="bg-indigo-600 text-white hover:bg-indigo-700" onClick={() => void approvePayment(selectedOrder.payment!._id)} disabled={isApproving}>{isApproving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Approve Payment</Button><Button variant="outline" className="border-amber-300 text-amber-800 hover:bg-amber-50" onClick={() => setHoldReason("Review needed")}>Hold for Admin</Button></div>{holdReason && <div className="flex flex-col gap-2 sm:flex-row"><Input value={holdReason} onChange={(event) => setHoldReason(event.target.value)} placeholder="Required reason for hold" /><Button className="bg-amber-600 text-white hover:bg-amber-700" onClick={() => void holdPayment(selectedOrder.payment!._id)} disabled={isHolding}>{isHolding && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Submit Hold</Button></div>}</div>}</div> : <p className="text-sm text-amber-700">No payment proof uploaded yet.</p>}{selectedOrder.status === "pending_payment" && canCompletePayment(selectedOrder) && <Button className="mt-3 w-full bg-[#2f63e8] text-white hover:bg-[#2557d8]" onClick={() => void markPaymentCompleted()} disabled={isMarkingPayment}>{isMarkingPayment ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <CheckCircle2 className="mr-2 h-4 w-4" />}Mark Payment Completed</Button>}</section>
            {selectedOrder.shippingAddress && <section className="rounded-lg border border-[#d8d9e9] bg-[#f9f9fd] p-4"><h3 className="mb-3 flex items-center gap-2 text-sm font-semibold"><MapPin className="h-4 w-4 text-indigo-600" />Shipping Address</h3><div className="grid gap-3 text-sm sm:grid-cols-2"><div><span className="block text-xs text-slate-500">Address</span><span>{selectedOrder.shippingAddress.addressLine1}{selectedOrder.shippingAddress.addressLine2 ? `, ${selectedOrder.shippingAddress.addressLine2}` : ""}</span></div><div><span className="block text-xs text-slate-500">City</span><span>{selectedOrder.shippingAddress.city}</span></div><div><span className="block text-xs text-slate-500">State</span><span>{selectedOrder.shippingAddress.state}</span></div><div><span className="block text-xs text-slate-500">Pincode</span><span>{selectedOrder.shippingAddress.pincode}</span></div></div></section>}
            <section className="rounded-lg border border-[#d8d9e9] bg-[#f9f9fd] p-4"><h3 className="mb-3 flex items-center gap-2 text-sm font-semibold"><Package className="h-4 w-4 text-indigo-600" />Ordered Items</h3><div className="space-y-3">{selectedOrder.items.map((item, index) => <div key={index} className="flex items-start justify-between border-b border-[#dfdfec] pb-3 last:border-0 last:pb-0"><div><p className="text-sm font-medium">{item.productSnapshot?.name || "Product"}</p><p className="text-xs text-slate-500">Qty: {item.quantity}</p></div><p className="text-sm font-semibold">Rs {(item.pricePerUnit * item.quantity).toLocaleString("en-IN")}</p></div>)}</div><div className="mt-4 flex justify-between border-t border-[#dfdfec] pt-3"><span className="text-sm text-slate-500">Grand Total</span><span className="font-bold">Rs {selectedOrder.total.toLocaleString("en-IN")}</span></div></section>
            {selectedOrder.statusHistory?.length ? <section className="rounded-lg border border-[#d8d9e9] bg-[#f9f9fd] p-4"><h3 className="mb-3 text-sm font-semibold">Status Timeline</h3><div className="space-y-3">{selectedOrder.statusHistory.map((entry, index) => <div key={index} className="border-l-2 border-indigo-500 pl-3"><p className="text-sm font-medium">{formatStatusLabel(entry.status)}</p><p className="text-xs text-slate-500">{new Date(entry.timestamp).toLocaleString("en-IN")}</p>{entry.note && <p className="mt-1 text-xs text-slate-600">{displayActivityText(entry.note)}</p>}</div>)}</div></section> : null}
            {selectedOrder.status === "processing" && <div><Button className="bg-violet-600 text-white hover:bg-violet-700" onClick={() => setIsShipDialogOpen(true)}><Truck className="mr-2 h-4 w-4" />Ship Order</Button></div>}
          </div>}
        </DialogContent>
      </Dialog>

      <Dialog open={Boolean(rejectOrder)} onOpenChange={(open) => { if (!open && !acceptanceAction) { setRejectOrder(null); setRejectionReason("") } }}>
        <DialogContent className="border-[#d1d2e6] bg-white text-slate-800 sm:max-w-md">
          <DialogHeader><DialogTitle>Reject Order</DialogTitle><DialogDescription>Provide a reason for rejecting {rejectOrder?.orderNumber}. This reason will be recorded on the order.</DialogDescription></DialogHeader>
          <Textarea aria-label="Rejection reason" value={rejectionReason} onChange={(event) => setRejectionReason(event.target.value)} placeholder="Required rejection reason" disabled={Boolean(acceptanceAction)} />
          <DialogFooter><Button variant="outline" disabled={Boolean(acceptanceAction)} onClick={() => { setRejectOrder(null); setRejectionReason("") }}>Cancel</Button><Button variant="destructive" disabled={!rejectionReason.trim() || Boolean(acceptanceAction)} onClick={() => rejectOrder && void updateAcceptance(rejectOrder, "reject", rejectionReason)}>{acceptanceAction?.type === "reject" && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Reject Order</Button></DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={isShipDialogOpen} onOpenChange={setIsShipDialogOpen}>
        <DialogContent className="border-[#d1d2e6] bg-white text-slate-800 sm:max-w-md"><DialogHeader><DialogTitle>Ship Order</DialogTitle><DialogDescription>Enter courier details for {selectedOrder?.orderNumber}</DialogDescription></DialogHeader><div className="space-y-3"><Input value={courierName} onChange={(event) => setCourierName(event.target.value)} placeholder="Courier name" /><Input value={trackingNumber} onChange={(event) => setTrackingNumber(event.target.value)} placeholder="Tracking number" /></div><DialogFooter><Button variant="outline" onClick={() => setIsShipDialogOpen(false)}>Cancel</Button><Button className="bg-violet-600 text-white hover:bg-violet-700" onClick={() => void shipOrder()} disabled={isShipping}>{isShipping && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Mark Shipped</Button></DialogFooter></DialogContent>
      </Dialog>
    </div>
  )
}
