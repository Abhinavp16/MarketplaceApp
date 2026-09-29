"use client"

import { useEffect, useState, useCallback } from "react"
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
import { Loader2, Eye, User, ShoppingBag, TrendingUp, Search, Bell, Send, CheckSquare, Square, X } from "@/components/hugeicons"
import { toast } from "sonner"
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { apiFetch } from "@/lib/api"
import { displayRole } from "@/lib/role-labels"

interface Customer {
    _id: string
    name: string
    email: string
    phone: string
    role: string
    businessInfo?: {
        businessName: string
        gstIn: string
    }
    createdAt: string
}

interface CustomerDetails extends Customer {
    stats: {
        orders: { totalOrders: number; totalSpent: number }
        negotiations: Record<string, number>
    }
    recentOrders: {
        _id: string
        orderNumber: string
        total: number
        status: string
        createdAt: string
    }[]
}

export default function CustomersPage() {
    const [customers, setCustomers] = useState<Customer[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isLoadingMore, setIsLoadingMore] = useState(false)
    const [selectedCustomer, setSelectedCustomer] = useState<CustomerDetails | null>(null)
    const [isDetailsOpen, setIsDetailsOpen] = useState(false)

    const [selectedIds, setSelectedIds] = useState<string[]>([])
    const [isNotifyModalOpen, setIsNotifyModalOpen] = useState(false)
    const [isSending, setIsSending] = useState(false)
    const [notificationData, setNotificationData] = useState({ title: "", body: "" })

    const [searchQuery, setSearchQuery] = useState("")
    const [page, setPage] = useState(1)
    const [totalCustomers, setTotalCustomers] = useState(0)
    const [hasMore, setHasMore] = useState(false)

    useEffect(() => {
        void fetchCustomers(1, true)
    }, [])

    async function fetchCustomers(pageNum: number = 1, reset: boolean = false) {
        if (reset) {
            setIsLoading(true)
            setPage(1)
        } else {
            setIsLoadingMore(true)
        }

        try {
            const params = new URLSearchParams()
            params.append("page", pageNum.toString())
            params.append("limit", "20")
            if (searchQuery.trim()) {
                params.append("search", searchQuery.trim())
            }

            const res = await apiFetch(`/admin/customers?${params.toString()}`)
            const data = await res.json()
            if (res.ok) {
                const items = data.data || []
                const pagination = data.pagination || {}

                if (reset || pageNum === 1) {
                    setCustomers(items)
                } else {
                    setCustomers((prev) => [...prev, ...items])
                }

                setTotalCustomers(pagination.total || items.length)
                setHasMore((pagination.page || 1) < (pagination.totalPages || 1))
            } else {
                toast.error("Failed to fetch customers")
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
        void fetchCustomers(1, true)
    }, [searchQuery])

    const loadMore = useCallback(() => {
        if (hasMore && !isLoadingMore) {
            const nextPage = page + 1
            setPage(nextPage)
            void fetchCustomers(nextPage, false)
        }
    }, [hasMore, isLoadingMore, page])

    async function fetchCustomerDetails(id: string) {
        try {
            const res = await apiFetch(`/admin/customers/${id}`)
            const data = await res.json()
            if (res.ok) {
                setSelectedCustomer(data.data)
                setIsDetailsOpen(true)
            }
        } catch {
            toast.error("Failed to load details")
        }
    }

    const toggleSelect = (id: string) => {
        setSelectedIds((prev) =>
            prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id]
        )
    }

    const toggleSelectAll = () => {
        if (selectedIds.length === customers.length && customers.length > 0) {
            setSelectedIds([])
        } else {
            setSelectedIds(customers.map((customer) => customer._id))
        }
    }

    const toggleDraftingHeader = () => {
        setIsNotifyModalOpen((prev) => !prev)
    }

    async function handleSendNotification() {
        if (!notificationData.title || !notificationData.body) {
            toast.error("Please fill in both title and message")
            return
        }

        setIsSending(true)
        try {
            const res = await apiFetch("/admin/customers/notifications", {
                method: "POST",
                body: JSON.stringify({
                    userIds: selectedIds,
                    title: notificationData.title,
                    body: notificationData.body
                })
            })

            const data = await res.json()
            if (res.ok) {
                toast.success(data.message || "Notification sent successfully")
                setIsNotifyModalOpen(false)
                setNotificationData({ title: "", body: "" })
                setSelectedIds([])
            } else {
                toast.error(data.message || "Failed to send notification")
            }
        } catch {
            toast.error("Error connecting to server")
        } finally {
            setIsSending(false)
        }
    }

    return (
        <div className="customers-page flex flex-col gap-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 className="text-3xl font-bold text-white">Customers</h1>
                    <p className="text-sm text-gray-400">{totalCustomers > 0 && `(${totalCustomers} customers)`}</p>
                </div>
                <Button
                    onClick={toggleDraftingHeader}
                    className={`${isNotifyModalOpen ? "bg-red-500/10 text-red-500 hover:bg-red-500/20" : "bg-[#818cf8] text-black hover:bg-[#7478e1]"} w-full gap-2 font-bold sm:w-auto`}
                >
                    {isNotifyModalOpen ? "Cancel Draft" : <><Bell className="h-4 w-4" /> Custom Notification</>}
                    {selectedIds.length > 0 && `(${selectedIds.length})`}
                </Button>
            </div>

            {isNotifyModalOpen && (
                <div className="relative mb-2 animate-in fade-in slide-in-from-top-4 duration-500 ease-out">
                    <div className="absolute inset-x-0 -top-px h-px bg-gradient-to-r from-transparent via-[#818cf8]/50 to-transparent" />

                    <Card className="overflow-hidden border-[#333] bg-[#111111] shadow-2xl">
                        <CardHeader className="border-b border-[#333]/50 bg-gradient-to-b from-[#1a1a1a]/50 to-transparent pb-4">
                            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                                <CardTitle className="flex items-center gap-3 text-xl font-bold text-white">
                                    <div className="rounded-lg border border-[#818cf8]/20 bg-[#818cf8]/10 p-2">
                                        <Send className="h-5 w-5 text-[#818cf8]" />
                                    </div>
                                    Draft Custom Notification
                                </CardTitle>
                                <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                                    <div className={`flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-semibold
                                        ${selectedIds.length > 0
                                            ? "border-[#818cf8]/30 bg-[#818cf8]/10 text-[#818cf8]"
                                            : "border-yellow-500/20 bg-yellow-500/5 text-yellow-500/70"
                                        }`}>
                                        <User className="h-3.5 w-3.5" />
                                        {selectedIds.length} {selectedIds.length === 1 ? "Customer" : "Customers"} Selected
                                    </div>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={toggleDraftingHeader}
                                        className="h-8 w-8 p-0 text-gray-500 hover:bg-white/5 hover:text-white"
                                    >
                                        <X className="h-4 w-4" />
                                    </Button>
                                </div>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-6 p-4 sm:p-6">
                            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
                                <div className="space-y-5 lg:col-span-2">
                                    <div className="space-y-2">
                                        <label className="ml-1 text-[11px] font-bold uppercase tracking-[0.1em] text-gray-400">
                                            Notification Title
                                        </label>
                                        <Input
                                            placeholder="Write a clear, punchy title..."
                                            value={notificationData.title}
                                            onChange={(e) => setNotificationData((prev) => ({ ...prev, title: e.target.value }))}
                                            className="h-11 bg-[#0D0D0D] border-[#333] text-white focus-visible:ring-1 focus-visible:ring-[#818cf8]/50"
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <label className="ml-1 text-[11px] font-bold uppercase tracking-[0.1em] text-gray-400">
                                            Message Content
                                        </label>
                                        <Textarea
                                            placeholder="What do you want to tell your customers?"
                                            value={notificationData.body}
                                            onChange={(e) => setNotificationData((prev) => ({ ...prev, body: e.target.value }))}
                                            className="min-h-[140px] resize-none bg-[#0D0D0D] border-[#333] text-white focus-visible:ring-1 focus-visible:ring-[#818cf8]/50"
                                        />
                                    </div>
                                </div>

                                <div className="flex flex-col justify-between rounded-xl border border-[#333]/50 bg-[#0a0a0a] p-5">
                                    <div className="space-y-4">
                                        <h4 className="text-xs font-bold uppercase tracking-widest text-gray-500">Delivery Preview</h4>
                                        <div className="origin-top scale-95 space-y-3 opacity-60 pointer-events-none">
                                            <div className="rounded-lg border border-[#333] bg-[#161616] p-3">
                                                <div className="mb-2 h-2 w-20 rounded bg-[#333]" />
                                                <div className="h-3 w-32 rounded bg-[#444]" />
                                            </div>
                                        </div>
                                        <p className="text-[11px] italic leading-relaxed text-gray-500">
                                            Customers will receive this as a push notification on their registered devices.
                                        </p>
                                    </div>

                                    <div className="mt-6 border-t border-[#333]/50 pt-6">
                                        <Button
                                            onClick={handleSendNotification}
                                            disabled={isSending || !notificationData.title || !notificationData.body || selectedIds.length === 0}
                                            className="h-14 w-full gap-3 bg-[#818cf8] font-black text-black shadow-[0_0_20px_-5px_rgba(129, 140, 248,0.3)] hover:bg-[#abadef]"
                                        >
                                            {isSending ? <Loader2 className="h-5 w-5 animate-spin" /> : <Send className="h-5 w-5" />}
                                            Send Now
                                        </Button>
                                    </div>
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                </div>
            )}

            <form onSubmit={handleSearch} className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <div className="relative w-full sm:max-w-md sm:flex-1">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
                    <Input
                        type="text"
                        placeholder="Search by name, email, phone..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="bg-[#161616] border-[#333] pl-10 text-white placeholder:text-gray-500 focus-visible:ring-[#818cf8]"
                    />
                </div>
                <Button type="submit" variant="outline" className="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] sm:w-auto">
                    Search
                </Button>
                {searchQuery && (
                    <Button
                        type="button"
                        variant="ghost"
                        onClick={() => {
                            setSearchQuery("")
                            void fetchCustomers(1, true)
                        }}
                        className="w-full text-gray-400 hover:text-white sm:w-auto"
                    >
                        Clear
                    </Button>
                )}
            </form>

            <Card className="bg-[#161616] border-[#333]">
                <CardHeader>
                    <CardTitle className="text-white">All Customers</CardTitle>
                </CardHeader>
                <CardContent>
                    {isLoading ? (
                        <div className="flex justify-center p-8">
                            <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
                        </div>
                    ) : customers.length === 0 ? (
                        <div className="py-10 text-center text-gray-500">No customers found</div>
                    ) : (
                        <>
                            <div className="mb-4 flex items-center justify-between rounded-xl border border-[#333] bg-[#0D0D0D] p-3 md:hidden">
                                <div className="text-sm text-gray-300">
                                    {selectedIds.length} selected
                                </div>
                                <Button
                                    variant="outline"
                                    size="sm"
                                    className="border-[#333] bg-transparent text-white hover:bg-[#1A1A1A]"
                                    onClick={toggleSelectAll}
                                >
                                    {selectedIds.length === customers.length && customers.length > 0 ? "Clear All" : "Select All"}
                                </Button>
                            </div>

                            <div className="space-y-3 md:hidden">
                                {customers.map((customer) => {
                                    const isSelected = selectedIds.includes(customer._id)
                                    return (
                                        <div key={customer._id} className="rounded-2xl border border-[#333] bg-[#0D0D0D] p-4">
                                            <div className="flex items-start justify-between gap-3">
                                                <div className="flex items-center gap-3">
                                                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-gray-800 text-gray-300">
                                                        <User className="h-5 w-5" />
                                                    </div>
                                                    <div>
                                                        <div className="text-sm font-semibold text-white">{customer.name}</div>
                                                        <div className="mt-1 text-xs text-gray-400">{customer.phone}</div>
                                                    </div>
                                                </div>
                                                <Badge variant="outline" className={customer.role === "wholesaler" ? "border-purple-400 text-purple-400" : "border-blue-400 text-blue-400"}>
                                                    {displayRole(customer.role)}
                                                </Badge>
                                            </div>

                                            <div className="mt-4 space-y-2 text-xs text-gray-400">
                                                <div>{customer.email}</div>
                                                <div>{customer.businessInfo?.businessName || "No business name"}</div>
                                                <div>Joined {new Date(customer.createdAt).toLocaleDateString("en-IN")}</div>
                                            </div>

                                            <div className="mt-4 flex items-center gap-2">
                                                <Button
                                                    variant="outline"
                                                    size="sm"
                                                    className="flex-1 border-[#333] bg-transparent text-white hover:bg-[#1A1A1A]"
                                                    onClick={() => fetchCustomerDetails(customer._id)}
                                                >
                                                    <Eye className="mr-2 h-4 w-4" />
                                                    View
                                                </Button>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="border border-[#333] text-white hover:bg-[#1A1A1A]"
                                                    onClick={() => toggleSelect(customer._id)}
                                                >
                                                    {isSelected ? <CheckSquare className="h-4 w-4 text-[#818cf8]" /> : <Square className="h-4 w-4" />}
                                                </Button>
                                            </div>
                                        </div>
                                    )
                                })}
                            </div>

                            <div className="hidden md:block">
                                <Table>
                                    <TableHeader>
                                        <TableRow className="border-[#333] hover:bg-[#1A1A1A]">
                                            <TableHead className="text-gray-400">Name</TableHead>
                                            <TableHead className="text-gray-400">Contact</TableHead>
                                            <TableHead className="text-gray-400">Type</TableHead>
                                            <TableHead className="text-gray-400">Business</TableHead>
                                            <TableHead className="text-right text-gray-400">Joined</TableHead>
                                            <TableHead className="text-right text-gray-400">Actions</TableHead>
                                            <TableHead className="w-10 text-right text-gray-400">
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 hover:bg-[#333]"
                                                    onClick={toggleSelectAll}
                                                >
                                                    {selectedIds.length === customers.length && customers.length > 0 ? (
                                                        <CheckSquare className="h-4 w-4 text-[#818cf8]" />
                                                    ) : (
                                                        <Square className="h-4 w-4" />
                                                    )}
                                                </Button>
                                            </TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {customers.map((customer) => (
                                            <TableRow key={customer._id} className="border-[#333] hover:bg-[#1A1A1A]">
                                                <TableCell className="font-medium text-white">
                                                    <div className="flex items-center gap-2">
                                                        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-gray-800 text-gray-300">
                                                            <User className="h-4 w-4" />
                                                        </div>
                                                        {customer.name}
                                                    </div>
                                                </TableCell>
                                                <TableCell className="text-gray-400">
                                                    <div className="text-xs">{customer.email}</div>
                                                    <div className="text-xs">{customer.phone}</div>
                                                </TableCell>
                                                <TableCell>
                                                    <Badge variant="outline" className={customer.role === "wholesaler" ? "border-purple-400 text-purple-400" : "border-blue-400 text-blue-400"}>
                                                        {displayRole(customer.role)}
                                                    </Badge>
                                                </TableCell>
                                                <TableCell className="text-sm text-gray-400">
                                                    {customer.businessInfo?.businessName || "-"}
                                                </TableCell>
                                                <TableCell className="text-right text-xs text-gray-500">
                                                    {new Date(customer.createdAt).toLocaleDateString("en-IN")}
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <Button
                                                        variant="ghost"
                                                        size="sm"
                                                        className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                                                        onClick={() => fetchCustomerDetails(customer._id)}
                                                    >
                                                        <Eye className="h-4 w-4" />
                                                    </Button>
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <Button
                                                        variant="ghost"
                                                        size="sm"
                                                        className="h-8 w-8 p-0 hover:bg-[#333]"
                                                        onClick={() => toggleSelect(customer._id)}
                                                    >
                                                        {selectedIds.includes(customer._id) ? (
                                                            <CheckSquare className="h-4 w-4 text-[#818cf8]" />
                                                        ) : (
                                                            <Square className="h-4 w-4" />
                                                        )}
                                                    </Button>
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </div>
                        </>
                    )}
                </CardContent>
            </Card>

            <Dialog open={isDetailsOpen} onOpenChange={setIsDetailsOpen}>
                <DialogContent className="max-w-[95vw] border-[#333] bg-[#161616] text-white sm:max-w-2xl">
                    <DialogHeader>
                        <DialogTitle>Customer Profile</DialogTitle>
                        <DialogDescription>
                            {selectedCustomer?.name} ({displayRole(selectedCustomer?.role)})
                        </DialogDescription>
                    </DialogHeader>

                    {selectedCustomer && (
                        <div className="space-y-6">
                            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                                <div className="rounded-lg border border-[#333] bg-[#0D0D0D] p-4">
                                    <div className="mb-1 flex items-center gap-2 text-xs uppercase text-gray-400">
                                        <ShoppingBag className="h-3 w-3" /> Total Spend
                                    </div>
                                    <div className="text-2xl font-bold">Rs {selectedCustomer.stats?.orders.totalSpent.toLocaleString("en-IN")}</div>
                                    <div className="text-xs text-gray-500">{selectedCustomer.stats?.orders.totalOrders} total orders</div>
                                </div>
                                <div className="rounded-lg border border-[#333] bg-[#0D0D0D] p-4">
                                    <div className="mb-1 flex items-center gap-2 text-xs uppercase text-gray-400">
                                        <TrendingUp className="h-3 w-3" /> Negotiations
                                    </div>
                                    <div className="text-2xl font-bold">{Object.values(selectedCustomer.stats?.negotiations || {}).reduce((sum, count) => sum + count, 0)}</div>
                                    <div className="flex gap-2 text-xs text-gray-500">
                                        <span className="text-green-500">{selectedCustomer.stats?.negotiations.accepted || 0} accepted</span>
                                        <span className="text-yellow-500">{selectedCustomer.stats?.negotiations.pending || 0} pending</span>
                                    </div>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 gap-4 rounded-lg border border-[#333] bg-[#0D0D0D] p-4 text-sm sm:grid-cols-2">
                                <div>
                                    <span className="block text-xs text-gray-500">Email</span>
                                    {selectedCustomer.email}
                                </div>
                                <div>
                                    <span className="block text-xs text-gray-500">Phone</span>
                                    {selectedCustomer.phone}
                                </div>
                                {selectedCustomer.businessInfo?.businessName && (
                                    <div className="border-[#333] pt-2 sm:col-span-2 sm:border-t sm:mt-2">
                                        <span className="block text-xs text-gray-500">Business</span>
                                        <span className="font-medium">{selectedCustomer.businessInfo.businessName}</span>
                                        {selectedCustomer.businessInfo.gstIn ? <span className="ml-2 text-xs text-gray-400">GST: {selectedCustomer.businessInfo.gstIn}</span> : null}
                                    </div>
                                )}
                            </div>

                            <div>
                                <h3 className="mb-3 font-medium">Recent Orders</h3>
                                <div className="space-y-2">
                                    {selectedCustomer.recentOrders.length === 0 ? (
                                        <div className="text-sm italic text-gray-500">No orders yet</div>
                                    ) : (
                                        selectedCustomer.recentOrders.map((order) => (
                                            <div key={order._id} className="flex flex-col gap-2 rounded border border-[#333] bg-[#0D0D0D] p-3 text-sm sm:flex-row sm:items-center sm:justify-between">
                                                <span className="font-mono text-gray-300">{order.orderNumber}</span>
                                                <Badge variant="outline" className="h-5 border-gray-700 py-0 text-xs text-gray-400">
                                                    {order.status.replace(/_/g, " ")}
                                                </Badge>
                                                <span className="font-bold">Rs {order.total.toLocaleString("en-IN")}</span>
                                            </div>
                                        ))
                                    )}
                                </div>
                            </div>
                        </div>
                    )}
                </DialogContent>
            </Dialog>

            {hasMore && customers.length > 0 && (
                <div className="flex justify-center pt-2">
                    <Button onClick={loadMore} disabled={isLoadingMore} variant="outline" className="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] sm:min-w-[200px] sm:w-auto">
                        {isLoadingMore ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" />Loading...</> : `Load More (${customers.length}/${totalCustomers})`}
                    </Button>
                </div>
            )}
        </div>
    )
}
