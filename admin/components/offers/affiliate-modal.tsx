"use client"

import { useState, useEffect } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { toast } from "sonner"
import { Loader2, Plus, Trash2 } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"

interface AffiliateModalProps {
    isOpen: boolean
    onClose: () => void
    onSuccess: () => void
    code?: any
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

export function AffiliateModal({ isOpen, onClose, onSuccess, code }: AffiliateModalProps) {
    const [loading, setLoading] = useState(false)
    const [formData, setFormData] = useState({
        code: "",
        personName: "",
        usageLimit: "0",
        startDate: "",
        endDate: "",
        isActive: true,
    })
    const [rules, setRules] = useState<DiscountRuleForm[]>([emptyRule()])

    useEffect(() => {
        if (code) {
            const sourceRules = Array.isArray(code.discountRules) && code.discountRules.length > 0
                ? code.discountRules
                : [{
                    minPurchaseAmount: 0,
                    discountType: code.discountType ?? "percentage",
                    discountValue: code.discountValue ?? 0,
                    maxDiscountAmount: undefined,
                }]

            setFormData({
                code: code.code || "",
                personName: code.personName || "",
                usageLimit: code.usageLimit?.toString() || "0",
                startDate: code.startDate ? new Date(code.startDate).toISOString().split("T")[0] : "",
                endDate: code.endDate ? new Date(code.endDate).toISOString().split("T")[0] : "",
                isActive: code.isActive !== false,
            })
            setRules(sourceRules.map((r: any) => ({
                minPurchaseAmount: (r.minPurchaseAmount ?? 0).toString(),
                discountType: r.discountType === "fixed" ? "fixed" : "percentage",
                discountValue: (r.discountValue ?? "").toString(),
                maxDiscountAmount: r.maxDiscountAmount?.toString() || "",
            })))
        } else {
            setFormData({
                code: "",
                personName: "",
                usageLimit: "0",
                startDate: new Date().toISOString().split("T")[0],
                endDate: "",
                isActive: true,
            })
            setRules([emptyRule()])
        }
    }, [code, isOpen])

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
            const endpoint = code ? `/admin/affiliate-codes/${code._id}` : `/admin/affiliate-codes`
            const method = code ? "PUT" : "POST"

            const res = await apiFetch(endpoint, {
                method,
                body: JSON.stringify({
                    ...formData,
                    discountType: primary.discountType,
                    discountValue: primary.discountValue,
                    discountRules: normalizedRules,
                    usageLimit: Number(formData.usageLimit),
                    endDate: formData.endDate || undefined,
                }),
            })

            const data = await res.json()
            if (res.ok) {
                toast.success(code ? "Affiliate code updated" : "Affiliate code created")
                onSuccess()
                onClose()
            } else {
                toast.error(data.message || "Something went wrong")
            }
        } catch (error) {
            console.error(error)
            toast.error("Failed to save affiliate code")
        } finally {
            setLoading(false)
        }
    }

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent className="bg-[#161616] border-[#333] text-white max-w-3xl max-h-[90vh] flex flex-col overflow-hidden">
                <DialogHeader>
                    <DialogTitle>{code ? "Edit Affiliate Code" : "Create Affiliate Code"}</DialogTitle>
                    <DialogDescription className="text-gray-400">
                        Add custom discount slabs for this creator code.
                    </DialogDescription>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="flex-1 min-h-0 flex flex-col">
                    <div className="min-h-0 flex-1 space-y-4 overflow-y-auto py-4 pr-1">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <Label htmlFor="personName">Person Name</Label>
                            <Input
                                id="personName"
                                value={formData.personName}
                                onChange={(e) => setFormData({ ...formData, personName: e.target.value })}
                                placeholder="Enter name"
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                                required
                            />
                        </div>
                        <div className="space-y-2">
                            <Label htmlFor="code">Affiliate Code</Label>
                            <Input
                                id="code"
                                value={formData.code}
                                onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                                placeholder="CODEWITHHARRYBOGO"
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                                required
                            />
                        </div>
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
                            <Label htmlFor="usageLimit">Usage Limit</Label>
                            <Input
                                id="usageLimit"
                                type="number"
                                value={formData.usageLimit}
                                onChange={(e) => setFormData({ ...formData, usageLimit: e.target.value })}
                                className="bg-[#0D0D0D] border-[#333] focus:border-[#818cf8]"
                                required
                            />
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
                            {code ? "Update Affiliate Code" : "Create Affiliate Code"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    )
}
