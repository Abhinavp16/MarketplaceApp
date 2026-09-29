"use client"

import { useEffect, useRef, useState } from "react"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
} from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Loader2, Eye, UserSearch, Phone, Mail, Package, ChevronLeft, ChevronRight, Clock, TrendingUp, MessageCircle, ShoppingCart } from "@/components/hugeicons"
import { toast } from "sonner"
import { apiFetch } from "@/lib/api"

type InterestLevel = "Hot" | "Warm" | "Browsing"

// One lead = one customer + one product. Repeat views update the same lead.
interface PotentialCustomer {
    userId: string
    productId: string
    viewCount: number
    totalWatchSeconds: number
    averageWatchSeconds: number
    lastViewed: string
    addedToCart: boolean
    interest: InterestLevel
    user: {
        name: string
        email: string
        phone: string
        role?: string
        businessName?: string
    }
    product: {
        name: string
        sku?: string
        price: number
        mrp?: number | null
        discountPercent?: number | null
        stock: number
        image?: string
    }
}

interface LeadSummary {
    total: number
    hot: number
    warm: number
    browsing: number
    addedToCart: number
    averageViews: number
    averageWatchSeconds: number
}

interface LeadRules {
    periodDays: number
    delayMinutes: number
    retentionDays: number
}

const EMPTY_SUMMARY: LeadSummary = { total: 0, hot: 0, warm: 0, browsing: 0, addedToCart: 0, averageViews: 0, averageWatchSeconds: 0 }
const DEFAULT_RULES: LeadRules = { periodDays: 5, delayMinutes: 10, retentionDays: 5 }

function formatWatchTime(seconds: number): string {
    if (!seconds || seconds < 1) return "—"
    const minutes = Math.floor(seconds / 60)
    const rest = Math.round(seconds % 60)
    if (minutes === 0) return `${rest}s`
    if (minutes < 60) return rest ? `${minutes}m ${rest}s` : `${minutes}m`
    const hours = Math.floor(minutes / 60)
    return `${hours}h ${minutes % 60}m`
}

interface Pagination {
    page: number
    limit: number
    total: number
    pages: number
}

export default function PotentialCustomersPage() {
    const [leads, setLeads] = useState<PotentialCustomer[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [period, setPeriod] = useState("5d")
    const [summary, setSummary] = useState<LeadSummary>(EMPTY_SUMMARY)
    const [rules, setRules] = useState<LeadRules>(DEFAULT_RULES)
    const [pagination, setPagination] = useState<Pagination>({ page: 1, limit: 30, total: 0, pages: 0 })
    const [scheduleTime, setScheduleTime] = useState("")
    const [scheduledAt, setScheduledAt] = useState<Date | null>(null)
    const scheduleTimeoutRef = useRef<number | null>(null)

    useEffect(() => {
        fetchLeads(1)
    }, [period])

    useEffect(() => {
        return () => {
            if (scheduleTimeoutRef.current) {
                window.clearTimeout(scheduleTimeoutRef.current)
            }
        }
    }, [])

    async function fetchLeads(page: number) {
        setIsLoading(true)
        try {
            const res = await apiFetch(`/admin/analytics/potential-customers?period=${period}&page=${page}&limit=30`)
            const data = await res.json()
            if (res.ok && data.success) {
                setLeads(data.data.potentialCustomers || [])
                setPagination(data.data.pagination)
                setSummary(data.data.summary || EMPTY_SUMMARY)
                setRules(data.data.rules || DEFAULT_RULES)
            } else {
                toast.error("Failed to fetch potential customers")
            }
        } catch (error) {
            console.error(error)
            toast.error("Error connecting to server")
        } finally {
            setIsLoading(false)
        }
    }

    function timeAgo(dateStr: string) {
        const diff = Date.now() - new Date(dateStr).getTime()
        const mins = Math.floor(diff / (1000 * 60))
        if (mins < 60) return `${mins}m ago`
        const hours = Math.floor(diff / (1000 * 60 * 60))
        if (hours < 24) return `${hours}h ago`
        const days = Math.floor(hours / 24)
        return `${days}d ago`
    }

    function formatPrice(price: number) {
        return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(price)
    }

    function formatWhatsappNumber(phone: string): string | null {
        const digits = phone.replace(/\D/g, "")
        if (!digits) return null
        if (digits.length === 10) return `91${digits}`
        return digits
    }

    function buildLeadMessage(lead: PotentialCustomer, interest: InterestLevel): string {
        const greetingName = lead.user.name || "there"
        if (interest === "Hot") {
            return `Hi ${greetingName}, we noticed your strong interest in ${lead.product.name}. It's currently available at ${formatPrice(lead.product.price)}. I can help you place an order now and share the best deal.`
        }
        if (interest === "Warm") {
            return `Hi ${greetingName}, thanks for checking ${lead.product.name}. It's available at ${formatPrice(lead.product.price)}. Let me know if you want specs, delivery timeline, or a quote.`
        }
        return `Hi ${greetingName}, sharing details for ${lead.product.name} (${formatPrice(lead.product.price)}). If you are comparing options, I can help with features, stock, and pricing.`
    }

    function sendInterestMessage(lead: PotentialCustomer) {
        const whatsappUrl = getWhatsappUrlForLead(lead)
        if (!whatsappUrl) {
            toast.error("Customer phone number is missing or invalid")
            return
        }
        window.open(whatsappUrl, "_blank", "noopener,noreferrer")
    }

    function getWhatsappUrlForLead(lead: PotentialCustomer): string | null {
        if (!lead.user.phone) return null
        const phone = formatWhatsappNumber(lead.user.phone)
        if (!phone) return null
        const message = buildLeadMessage(lead, lead.interest)
        return `https://wa.me/${phone}?text=${encodeURIComponent(message)}`
    }

    function sendMessageToAll() {
        if (leads.length === 0) {
            toast.error("No leads available to message")
            return
        }

        const urls = leads
            .map((lead) => getWhatsappUrlForLead(lead))
            .filter((url): url is string => !!url)

        if (urls.length === 0) {
            toast.error("No valid phone numbers found in current leads")
            return
        }

        urls.forEach((url, index) => {
            setTimeout(() => {
                window.open(url, "_blank", "noopener,noreferrer")
            }, index * 250)
        })

        const skipped = leads.length - urls.length
        if (skipped > 0) {
            toast.success(`Opening ${urls.length} chats. Skipped ${skipped} leads with invalid phone numbers.`)
        } else {
            toast.success(`Opening ${urls.length} WhatsApp chats`)
        }
    }

    function scheduleMessageToAll() {
        if (!scheduleTime) {
            toast.error("Please select date and time")
            return
        }
        if (leads.length === 0) {
            toast.error("No leads available to message")
            return
        }

        const targetTime = new Date(scheduleTime)
        if (Number.isNaN(targetTime.getTime())) {
            toast.error("Invalid date/time selected")
            return
        }

        const delay = targetTime.getTime() - Date.now()
        if (delay <= 0) {
            toast.error("Please select a future time")
            return
        }

        if (scheduleTimeoutRef.current) {
            window.clearTimeout(scheduleTimeoutRef.current)
        }

        scheduleTimeoutRef.current = window.setTimeout(() => {
            sendMessageToAll()
            setScheduledAt(null)
            scheduleTimeoutRef.current = null
        }, delay)
        setScheduledAt(targetTime)
        toast.success(`Bulk message scheduled for ${targetTime.toLocaleString()}. Keep this tab open.`)
    }

    function cancelScheduledMessage() {
        if (!scheduleTimeoutRef.current) return
        window.clearTimeout(scheduleTimeoutRef.current)
        scheduleTimeoutRef.current = null
        setScheduledAt(null)
        toast.success("Scheduled bulk message cancelled")
    }

    // Leads are kept for 5 days after the last view, so longer periods add nothing.
    const periods = [
        { value: "1d", label: "Last 24 hours" },
        { value: "3d", label: "Last 3 days" },
        { value: "5d", label: "Last 5 days" },
    ]

    return (
        <div className="flex flex-col gap-6">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold text-white">Potential Customers</h1>
                    <p className="text-sm text-[#919191] mt-1">
                        Customers who viewed a product but haven&apos;t ordered it or sent a requirement. A lead appears {rules.delayMinutes} minutes after the last view and is removed {rules.retentionDays} days after it.
                    </p>
                </div>
                <select
                    value={period}
                    onChange={(e) => setPeriod(e.target.value)}
                    className="bg-[#161616] border border-[#333] text-white text-sm rounded-lg px-3 py-2 focus:outline-none focus:border-[#818cf8] cursor-pointer"
                >
                    {periods.map((p) => (
                        <option key={p.value} value={p.value}>{p.label}</option>
                    ))}
                </select>
            </div>

            {/* Stats Cards (whole result, not just this page) */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-[#0D0D0D] rounded-2xl p-5 flex items-center gap-4">
                    <div className="p-2.5 rounded-xl bg-orange-500/10">
                        <UserSearch className="h-5 w-5 text-orange-400" />
                    </div>
                    <div>
                        <p className="text-3xl font-bold text-white">{summary.total}</p>
                        <p className="text-xs text-[#919191]">Total Leads</p>
                    </div>
                </div>
                <div className="bg-[#0D0D0D] rounded-2xl p-5 flex items-center gap-4">
                    <div className="p-2.5 rounded-xl bg-green-500/10">
                        <TrendingUp className="h-5 w-5 text-[#818cf8]" />
                    </div>
                    <div>
                        <p className="text-3xl font-bold text-white">{summary.hot + summary.warm}</p>
                        <p className="text-xs text-[#919191]">High Interest ({summary.hot} hot · {summary.warm} warm)</p>
                    </div>
                </div>
                <div className="bg-[#0D0D0D] rounded-2xl p-5 flex items-center gap-4">
                    <div className="p-2.5 rounded-xl bg-blue-500/10">
                        <Eye className="h-5 w-5 text-blue-400" />
                    </div>
                    <div>
                        <p className="text-3xl font-bold text-white">{formatWatchTime(summary.averageWatchSeconds)}</p>
                        <p className="text-xs text-[#919191]">Avg. Watch Time · {summary.averageViews} views per lead</p>
                    </div>
                </div>
                <div className="bg-[#0D0D0D] rounded-2xl p-5 flex items-center gap-4">
                    <div className="p-2.5 rounded-xl bg-purple-500/10">
                        <ShoppingCart className="h-5 w-5 text-purple-400" />
                    </div>
                    <div>
                        <p className="text-3xl font-bold text-white">{summary.addedToCart}</p>
                        <p className="text-xs text-[#919191]">Added to Cart, Not Ordered</p>
                    </div>
                </div>
            </div>

            {/* Table */}
            <div className="bg-[#161616] border border-[#333] rounded-2xl">
                <div className="px-6 py-4 border-b border-[#333] flex items-center justify-between gap-3">
                    <h2 className="text-lg font-semibold text-white">Lead Details</h2>
                    <div className="flex items-center gap-2 flex-wrap justify-end">
                        <input
                            type="datetime-local"
                            value={scheduleTime}
                            onChange={(e) => setScheduleTime(e.target.value)}
                            className="bg-[#0D0D0D] border border-[#333] text-white text-sm rounded-lg px-3 py-2 focus:outline-none focus:border-[#818cf8]"
                        />
                        <Button
                            size="sm"
                            variant="outline"
                            className="border-[#818cf8] text-[#818cf8] hover:bg-[#818cf8]/10"
                            onClick={scheduleMessageToAll}
                            disabled={isLoading || leads.length === 0}
                        >
                            Schedule All
                        </Button>
                        {scheduledAt && (
                            <Button
                                size="sm"
                                variant="ghost"
                                className="text-white hover:bg-[#333]"
                                onClick={cancelScheduledMessage}
                            >
                                Cancel Schedule
                            </Button>
                        )}
                        <Button
                            size="sm"
                            className="bg-[#818cf8] text-black hover:bg-[#818cf8]/90"
                            onClick={sendMessageToAll}
                            disabled={isLoading || leads.length === 0}
                        >
                            <MessageCircle className="h-4 w-4 mr-1" />
                            Send Message to All
                        </Button>
                    </div>
                </div>
                {scheduledAt && (
                    <div className="px-6 py-2 border-b border-[#333] text-xs text-[#818cf8]">
                        Scheduled bulk message: {scheduledAt.toLocaleString()}
                    </div>
                )}
                <div className="p-6">
                    {isLoading ? (
                        <div className="flex justify-center py-16">
                            <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
                        </div>
                    ) : leads.length === 0 ? (
                        <div className="text-center py-16">
                            <UserSearch className="h-12 w-12 mx-auto mb-3 text-[#333]" />
                            <p className="font-medium text-gray-400">No potential customers found</p>
                            <p className="text-sm text-[#919191] mt-1">New views show here {rules.delayMinutes} minutes after the customer leaves the product</p>
                        </div>
                    ) : (
                        <>
                            <Table>
                                <TableHeader>
                                    <TableRow className="border-[#333] hover:bg-[#1A1A1A]">
                                        <TableHead className="text-gray-400">Customer</TableHead>
                                        <TableHead className="text-gray-400">Product Viewed</TableHead>
                                        <TableHead className="text-gray-400 text-center">Views</TableHead>
                                        <TableHead className="text-gray-400">Watch Time</TableHead>
                                        <TableHead className="text-gray-400">Last Viewed</TableHead>
                                        <TableHead className="text-gray-400">Stock</TableHead>
                                        <TableHead className="text-gray-400">Interest</TableHead>
                                        <TableHead className="text-gray-400 text-right">Action</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {leads.map((lead, i) => {
                                        const interest = lead.interest
                                        const hasDiscount = Boolean(lead.product.mrp && lead.product.mrp > lead.product.price)
                                        return (
                                        <TableRow key={`${lead.userId}-${lead.productId}-${i}`} className="border-[#333] hover:bg-[#1A1A1A]">
                                            <TableCell>
                                                <div className="space-y-1">
                                                    <p className="font-medium text-sm text-white">{lead.user.name}</p>
                                                    {lead.user.businessName && (
                                                        <p className="text-xs text-[#919191]">{lead.user.businessName}</p>
                                                    )}
                                                    <div className="flex items-center gap-3 text-xs text-gray-500">
                                                        {lead.user.phone && (
                                                            <span className="flex items-center gap-1">
                                                                <Phone className="h-3 w-3" />
                                                                {lead.user.phone}
                                                            </span>
                                                        )}
                                                        {lead.user.email && (
                                                            <span className="flex items-center gap-1">
                                                                <Mail className="h-3 w-3" />
                                                                {lead.user.email}
                                                            </span>
                                                        )}
                                                    </div>
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                <div className="flex items-center gap-3">
                                                    {lead.product.image ? (
                                                        <img
                                                            src={lead.product.image}
                                                            alt={lead.product.name}
                                                            className="w-10 h-10 rounded-md object-cover border border-[#333]"
                                                        />
                                                    ) : (
                                                        <div className="w-10 h-10 rounded-md bg-[#1A1A1A] flex items-center justify-center border border-[#333]">
                                                            <Package className="h-4 w-4 text-gray-500" />
                                                        </div>
                                                    )}
                                                    <div>
                                                        <p className="text-sm font-medium text-white line-clamp-1">{lead.product.name}</p>
                                                        <p className="text-xs text-[#919191]">
                                                            {formatPrice(lead.product.price)}
                                                            {hasDiscount && (
                                                                <span className="ml-1.5 text-gray-600 line-through">{formatPrice(lead.product.mrp as number)}</span>
                                                            )}
                                                        </p>
                                                        {lead.addedToCart && (
                                                            <span className="mt-1 inline-flex items-center gap-1 rounded-full bg-purple-500/10 px-2 py-0.5 text-[11px] font-medium text-purple-300">
                                                                <ShoppingCart className="h-3 w-3" />
                                                                Added to cart
                                                            </span>
                                                        )}
                                                    </div>
                                                </div>
                                            </TableCell>
                                            <TableCell className="text-center">
                                                <span className="font-semibold text-sm text-white">
                                                    Viewed {lead.viewCount} {lead.viewCount === 1 ? "time" : "times"}
                                                </span>
                                            </TableCell>
                                            <TableCell>
                                                <p className="text-sm font-medium text-white">{formatWatchTime(lead.totalWatchSeconds)}</p>
                                                {lead.viewCount > 1 && lead.totalWatchSeconds > 0 && (
                                                    <p className="text-xs text-gray-500">~{formatWatchTime(lead.averageWatchSeconds)} per view</p>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <div className="flex items-center gap-1 text-xs text-gray-500">
                                                    <Clock className="h-3 w-3" />
                                                    {timeAgo(lead.lastViewed)}
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                {lead.product.stock === 0 ? (
                                                    <span className="px-2 py-1 rounded-full text-xs font-medium text-red-400 bg-red-500/10">Out of stock</span>
                                                ) : lead.product.stock <= 10 ? (
                                                    <span className="px-2 py-1 rounded-full text-xs font-medium text-yellow-400 bg-yellow-500/10">{lead.product.stock} left</span>
                                                ) : (
                                                    <span className="px-2 py-1 rounded-full text-xs font-medium text-gray-400 bg-gray-500/10">{lead.product.stock} left</span>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {interest === "Hot" ? (
                                                    <span className="px-2 py-1 rounded-full text-xs font-medium text-red-400 bg-red-500/10">Hot</span>
                                                ) : interest === "Warm" ? (
                                                    <span className="px-2 py-1 rounded-full text-xs font-medium text-orange-400 bg-orange-500/10">Warm</span>
                                                ) : (
                                                    <span className="px-2 py-1 rounded-full text-xs font-medium text-blue-400 bg-blue-500/10">Browsing</span>
                                                )}
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <Button
                                                    size="sm"
                                                    className="bg-[#818cf8] text-black hover:bg-[#818cf8]/90"
                                                    onClick={() => sendInterestMessage(lead)}
                                                >
                                                    <MessageCircle className="h-4 w-4 mr-1" />
                                                    Send Message
                                                </Button>
                                            </TableCell>
                                        </TableRow>
                                        )
                                    })}
                                </TableBody>
                            </Table>

                            {/* Pagination */}
                            {pagination.pages > 1 && (
                                <div className="flex items-center justify-between mt-4 pt-4 border-t border-[#333]">
                                    <p className="text-sm text-[#919191]">
                                        Page {pagination.page} of {pagination.pages} ({pagination.total} leads)
                                    </p>
                                    <div className="flex gap-2">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="text-white hover:bg-[#333]"
                                            disabled={pagination.page <= 1}
                                            onClick={() => fetchLeads(pagination.page - 1)}
                                        >
                                            <ChevronLeft className="h-4 w-4" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="text-white hover:bg-[#333]"
                                            disabled={pagination.page >= pagination.pages}
                                            onClick={() => fetchLeads(pagination.page + 1)}
                                        >
                                            <ChevronRight className="h-4 w-4" />
                                        </Button>
                                    </div>
                                </div>
                            )}
                        </>
                    )}
                </div>
            </div>
        </div>
    )
}
