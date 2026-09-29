"use client"

import { useState, useEffect } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { toast } from "sonner"
import { Loader2, Plus, Trash2 } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"

interface OfferModalProps {
    isOpen: boolean
    onClose: () => void
    onSuccess: () => void
    offer?: any
    targetGroup: "buyer" | "wholesaler"
}

interface DiscountRuleForm {
    minPurchaseAmount: string
    discountType: "percentage" | "fixed"
    discountValue: string
    maxDiscountAmount: string
}

const emptyRule = (): DiscountRuleForm => ({
    minPurchaseAmount: "0",
    discountType: "percentage",
    discountValue: "",
    maxDiscountAmount: "",
})

export function OfferModal({ isOpen, onClose, onSuccess, offer, targetGroup }: OfferModalProps) {
    const [loading, setLoading] = useState(false)
    const [formData, setFormData] = useState({
        title: "",
        description: "",
        code: "",
        targetGroup: targetGroup,
        startDate: "",
        endDate: "",
        isActive: true,
    })
    const [rules, setRules] = useState<DiscountRuleForm[]>([emptyRule()])

    useEffect(() => {
        if (offer) {
            const sourceRules = Array.isArray(offer.discountRules) && offer.discountRules.length > 0
                ? offer.discountRules
                : [{
                    minPurchaseAmount: offer.minPurchaseAmount ?? 0,
                    discountType: offer.discountType ?? "percentage",
                    discountValue: offer.discountValue ?? 0,
                    maxDiscountAmount: offer.maxDiscountAmount,
                }]

            setFormData({
                title: offer.title || "",
                description: offer.description || "",
                code: offer.code || "",
                targetGroup: offer.targetGroup || targetGroup,
                startDate: offer.startDate ? new Date(offer.startDate).toISOString().split("T")[0] : "",
                endDate: offer.endDate ? new Date(offer.endDate).toISOString().split("T")[0] : "",
                isActive: offer.isActive !== false,
            })
            setRules(sourceRules.map((r: any) => ({
                minPurchaseAmount: (r.minPurchaseAmount ?? 0).toString(),
                discountType: r.discountType === "fixed" ? "fixed" : "percentage",
                discountValue: (r.discountValue ?? "").toString(),
                maxDiscountAmount: r.maxDiscountAmount?.toString() || "",
            })))
        } else {
            setFormData({
                title: "",
                description: "",
                code: "",
                targetGroup: targetGroup,
                startDate: new Date().toISOString().split("T")[0],
                endDate: "",
                isActive: true,
            })
            setRules([emptyRule()])
        }
    }, [offer, targetGroup, isOpen])

    const updateRule = (index: number, patch: Partial<DiscountRuleForm>) => {
        setRules((prev) => prev.map((rule, i) => i === index ? { ...rule, ...patch } : rule))
    }

    const addRule = () => setRules((prev) => [...prev, emptyRule()])
    const removeRule = (index: number) => setRules((prev) => prev.filter((_, i) => i !== index))

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setLoading(true)

        try {
            const normalizedRules = rules
                .map((r) => ({
                    minPurchaseAmount: Number(r.minPurchaseAmount || 0),
                    discountType: r.discountType,
                    discountValue: Number(r.discountValue || 0),
                    maxDiscountAmount: r.maxDiscountAmount ? Number(r.maxDiscountAmount) : undefined,
                }))
                .filter((r) => r.discountValue >= 0 && r.minPurchaseAmount >= 0)
                .sort((a, b) => a.minPurchaseAmount - b.minPurchaseAmount)

            if (normalizedRules.length === 0) {
                toast.error("Add at least one valid discount rule")
                setLoading(false)
                return
            }

            const primary = normalizedRules[0]
            const endpoint = offer ? `/admin/offers/${offer._id}` : `/admin/offers`
            const method = offer ? "PUT" : "POST"

            const res = await apiFetch(endpoint, {
                method,
                body: JSON.stringify({
                    ...formData,
                    discountType: primary.discountType,
                    discountValue: primary.discountValue,
                    minPurchaseAmount: primary.minPurchaseAmount,
                    maxDiscountAmount: primary.maxDiscountAmount,
                    discountRules: normalizedRules,
                    code: formData.code || undefined,
                    endDate: formData.endDate || undefined,
                }),
            })

            const data = await res.json()
            if (res.ok) {
                toast.success(offer ? "Offer updated" : "Offer created")
                onSuccess()
                onClose()
            } else {
                toast.error(data.message || "Something went wrong")
            }
        } catch (error) {
            console.error(error)
            toast.error("Failed to save offer")
        } finally {
            setLoading(false)
        }
    }

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent className="bg-[#161616] border-[#333] text-white max-w-3xl max-h-[90vh] flex flex-col overflow-hidden">
                <DialogHeader>
                    <DialogTitle>{offer ? "Edit Offer" : "Create New Offer"}</DialogTitle>
                    <DialogDescription className="text-gray-400">
                        Create rules like: ₹1000 =&gt; 10%, ₹5000 =&gt; 20%.
                    </DialogDescription>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="flex-1 min-h-0 flex flex-col">
                    <div className="min-h-0 flex-1 space-y-4 overflow-y-auto py-4 pr-1">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <Label htmlFor="title">Title</Label>
                            <Input
                                id="title"
                                value={formData.title}
                                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                                placeholder="Festive Offer"
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                                required
                            />
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="code">Promo Code (Optional)</Label>
                            <Input
                                id="code"
                                value={formData.code}
                                onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                                placeholder="SAVE20"
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                            />
                        </div>
                    </div>

                    <div className="space-y-2">
                        <Label htmlFor="description">Description</Label>
                        <Textarea
                            id="description"
                            value={formData.description}
                            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                            placeholder="Offer details..."
                            className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8] min-h-[80px]"
                        />
                    </div>

                    <div className="space-y-3">
                        <div className="flex items-center justify-between">
                            <Label>Discount Conditions / Slabs</Label>
                            <Button type="button" variant="outline" size="sm" onClick={addRule} className="border-[#333]">
                                <Plus className="h-4 w-4 mr-1" /> Add Slab
                            </Button>
                        </div>
                        <div className="space-y-3">
                            {rules.map((rule, index) => (
                                <div key={index} className="grid grid-cols-1 md:grid-cols-12 gap-3 bg-[#0D0D0D] border border-[#333] rounded-lg p-3">
                                    <div className="md:col-span-3 space-y-1">
                                        <Label className="text-xs text-gray-400">Min Purchase (₹)</Label>
                                        <Input
                                            type="number"
                                            value={rule.minPurchaseAmount}
                                            onChange={(e) => updateRule(index, { minPurchaseAmount: e.target.value })}
                                            className="bg-[#161616] border-[#333]"
                                        />
                                    </div>
                                    <div className="md:col-span-3 space-y-1">
                                        <Label className="text-xs text-gray-400">Type</Label>
                                        <Select
                                            value={rule.discountType}
                                            onValueChange={(val: "percentage" | "fixed") => updateRule(index, { discountType: val })}
                                        >
                                            <SelectTrigger className="bg-[#161616] border-[#333] w-full">
                                                <SelectValue />
                                            </SelectTrigger>
                                            <SelectContent className="bg-[#161616] border-[#333] text-white">
                                                <SelectItem value="percentage">Percentage (%)</SelectItem>
                                                <SelectItem value="fixed">Fixed Amount (₹)</SelectItem>
                                            </SelectContent>
                                        </Select>
                                    </div>
                                    <div className="md:col-span-2 space-y-1">
                                        <Label className="text-xs text-gray-400">Value</Label>
                                        <Input
                                            type="number"
                                            value={rule.discountValue}
                                            onChange={(e) => updateRule(index, { discountValue: e.target.value })}
                                            className="bg-[#161616] border-[#333]"
                                            required
                                        />
                                    </div>
                                    <div className="md:col-span-3 space-y-1">
                                        <Label className="text-xs text-gray-400">Max Cap (₹)</Label>
                                        <Input
                                            type="number"
                                            value={rule.maxDiscountAmount}
                                            onChange={(e) => updateRule(index, { maxDiscountAmount: e.target.value })}
                                            placeholder="optional"
                                            className="bg-[#161616] border-[#333]"
                                        />
                                    </div>
                                    <div className="md:col-span-1 flex items-end justify-end">
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="icon"
                                            disabled={rules.length === 1}
                                            onClick={() => removeRule(index)}
                                            className="text-red-400 hover:bg-red-400/10"
                                        >
                                            <Trash2 className="h-4 w-4" />
                                        </Button>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <Label htmlFor="startDate">Start Date</Label>
                            <Input
                                id="startDate"
                                type="date"
                                value={formData.startDate}
                                onChange={(e) => setFormData({ ...formData, startDate: e.target.value })}
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                                required
                            />
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="endDate">End Date (Optional)</Label>
                            <Input
                                id="endDate"
                                type="date"
                                value={formData.endDate}
                                onChange={(e) => setFormData({ ...formData, endDate: e.target.value })}
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                            />
                        </div>
                    </div>

                    </div>

                    <DialogFooter className="pt-4 mt-2 border-t border-[#333]">
                        <Button type="button" variant="ghost" onClick={onClose} className="text-gray-400 hover:text-white hover:bg-[#333]">
                            Cancel
                        </Button>
                        <Button type="submit" disabled={loading} className="is-active hover:bg-[#818cf8]/90 px-8">
                            {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                            {offer ? "Update Offer" : "Create Offer"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    )
}
