"use client"

import { useEffect, useState } from "react"
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
import { Loader2, Plus, Edit2, Trash2, Power } from "@/components/hugeicons"
import { toast } from "sonner"
import { OfferModal } from "@/components/offers/offer-modal"
import { apiFetch } from "@/lib/api"

interface Offer {
    _id: string
    title: string
    description: string
    discountType: 'percentage' | 'fixed'
    discountValue: number
    code: string
    targetGroup: string
    startDate: string
    endDate?: string
    isActive: boolean
    usageCount: number
}

export default function CustomerOffersPage() {
    const [offers, setOffers] = useState<Offer[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [editingOffer, setEditingOffer] = useState<Offer | null>(null)

    useEffect(() => {
        fetchOffers()
    }, [])

    async function fetchOffers() {
        try {
            // targetGroup=buyer means offers for retail customers
            const res = await apiFetch('/admin/offers?targetGroup=buyer')
            const data = await res.json()
            if (res.ok) {
                setOffers(data.data || [])
            } else {
                toast.error("Failed to fetch offers")
            }
        } catch (error) {
            console.error(error)
            toast.error("Error connecting to server")
        } finally {
            setIsLoading(false)
        }
    }

    async function toggleStatus(id: string) {
        try {
            const res = await apiFetch(`/admin/offers/${id}/toggle`, { method: 'PATCH' })
            if (res.ok) {
                setOffers(prev => prev.map(off =>
                    off._id === id ? { ...off, isActive: !off.isActive } : off
                ))
                toast.success("Status updated")
            }
        } catch (error) {
            toast.error("Failed to update status")
        }
    }

    async function deleteOffer(id: string) {
        if (!confirm("Are you sure you want to delete this offer?")) return
        try {
            const res = await apiFetch(`/admin/offers/${id}`, { method: 'DELETE' })
            if (res.ok) {
                setOffers(prev => prev.filter(off => off._id !== id))
                toast.success("Offer deleted")
            }
        } catch (error) {
            toast.error("Failed to delete offer")
        }
    }

    return (
        <div className="flex flex-col gap-6">
            <div className="flex justify-between items-center">
                <h1 className="text-3xl font-bold text-white">Customer Offers</h1>
                <Button
                    onClick={() => {
                        setEditingOffer(null)
                        setIsModalOpen(true)
                    }}
                    className="bg-[#86efac] text-black hover:bg-[#86efac]/90"
                >
                    <Plus className="h-4 w-4 mr-2" /> Add Offer
                </Button>
            </div>

            <Card className="bg-[#161616] border-[#333]">
                <CardHeader>
                    <CardTitle className="text-white text-lg">Active Promotions for Retail Buyers</CardTitle>
                </CardHeader>
                <CardContent>
                    {isLoading ? (
                        <div className="flex justify-center p-8">
                            <Loader2 className="h-8 w-8 animate-spin text-[#86efac]" />
                        </div>
                    ) : offers.length === 0 ? (
                        <div className="text-center text-gray-500 py-10">No offers found for customers</div>
                    ) : (
                        <Table>
                            <TableHeader>
                                <TableRow className="border-[#333] hover:bg-transparent">
                                    <TableHead className="text-gray-400">Offer Details</TableHead>
                                    <TableHead className="text-gray-400">Code</TableHead>
                                    <TableHead className="text-gray-400">Discount</TableHead>
                                    <TableHead className="text-gray-400">Validity</TableHead>
                                    <TableHead className="text-gray-400">Status</TableHead>
                                    <TableHead className="text-gray-400 text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {offers.map((offer) => (
                                    <TableRow key={offer._id} className="border-[#333] hover:bg-[#1A1A1A]">
                                        <TableCell className="text-white">
                                            <div className="font-medium">{offer.title}</div>
                                            <div className="text-xs text-gray-500 line-clamp-1">{offer.description}</div>
                                        </TableCell>
                                        <TableCell>
                                            <code className="bg-[#0D0D0D] px-2 py-1 rounded text-[#86efac] text-xs font-mono">
                                                {offer.code || 'NO CODE'}
                                            </code>
                                        </TableCell>
                                        <TableCell className="text-white">
                                            {offer.discountType === 'percentage' ? `${offer.discountValue}%` : `₹${offer.discountValue}`}
                                        </TableCell>
                                        <TableCell className="text-gray-400 text-xs">
                                            <div>From: {new Date(offer.startDate).toLocaleDateString()}</div>
                                            {offer.endDate && <div>To: {new Date(offer.endDate).toLocaleDateString()}</div>}
                                        </TableCell>
                                        <TableCell>
                                            <Badge variant="outline" className={offer.isActive ? "text-green-400 border-green-400" : "text-gray-500 border-gray-500"}>
                                                {offer.isActive ? 'Active' : 'Inactive'}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <div className="flex justify-end gap-2">
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                                                    onClick={() => toggleStatus(offer._id)}
                                                    title={offer.isActive ? "Deactivate" : "Activate"}
                                                >
                                                    <Power className={`h-4 w-4 ${offer.isActive ? 'text-green-400' : 'text-gray-400'}`} />
                                                </Button>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                                                    onClick={() => {
                                                        setEditingOffer(offer)
                                                        setIsModalOpen(true)
                                                    }}
                                                >
                                                    <Edit2 className="h-4 w-4" />
                                                </Button>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 text-red-400 hover:bg-red-400/10 hover:text-red-400"
                                                    onClick={() => deleteOffer(offer._id)}
                                                >
                                                    <Trash2 className="h-4 w-4" />
                                                </Button>
                                            </div>
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    )}
                </CardContent>
            </Card>

            <OfferModal
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                onSuccess={fetchOffers}
                offer={editingOffer}
                targetGroup="buyer"
            />
        </div>
    )
}
