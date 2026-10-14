"use client"

import { useEffect, useMemo, useState } from "react"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Loader2, Plus, Edit2, Trash2, Power, User, History } from "@/components/hugeicons"
import { toast } from "sonner"
import { AffiliateModal } from "@/components/offers/affiliate-modal"
import { apiFetch } from "@/lib/api"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet"
import { ScrollArea } from "@/components/ui/scroll-area"

interface AffiliateCode {
  _id: string
  code: string
  personName: string
  discountType: "percentage" | "fixed"
  discountValue: number
  usageLimit: number
  usageCount: number
  isActive: boolean
  startDate: string
  endDate?: string
  totalDiscountGenerated?: number
  totalCommissionAccrued?: number
}

interface UsageItem {
  _id: string
  orderNumber: string
  total: number
  status: string
  createdAt: string
  discount?: number
  commissionAmount?: number
  commissionStatus?: string | null
  customerSnapshot?: { name?: string }
}

interface CommissionItem {
  _id: string
  orderNumber: string
  affiliateCode: string
  personNameSnapshot: string
  discountAmount: number
  commissionAmount: number
  status: "unpaid"
  triggerEvent: "payment_verified"
  createdAt: string
}

const formatInr = (v: number) => `₹${Number(v || 0).toFixed(2)}`

export default function AffiliateCodesPage() {
  const [codes, setCodes] = useState<AffiliateCode[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [editingCode, setEditingCode] = useState<AffiliateCode | null>(null)
  const [isUsageOpen, setIsUsageOpen] = useState(false)
  const [selectedCode, setSelectedCode] = useState<AffiliateCode | null>(null)
  const [usageData, setUsageData] = useState<UsageItem[]>([])
  const [usageLoading, setUsageLoading] = useState(false)
  const [commissions, setCommissions] = useState<CommissionItem[]>([])
  const [commissionsLoading, setCommissionsLoading] = useState(true)

  useEffect(() => {
    fetchCodes()
    fetchCommissions()
  }, [])

  async function fetchCodes() {
    try {
      const res = await apiFetch("/admin/affiliate-codes")
      const data = await res.json()
      if (res.ok) {
        setCodes(data.data || [])
      } else {
        toast.error("Failed to fetch affiliate codes")
      }
    } catch (error) {
      console.error(error)
      toast.error("Error connecting to server")
    } finally {
      setIsLoading(false)
    }
  }

  async function fetchCommissions() {
    setCommissionsLoading(true)
    try {
      const res = await apiFetch("/admin/affiliate-commissions?limit=100")
      const data = await res.json()
      if (res.ok) {
        setCommissions(data.data || [])
      } else {
        toast.error("Failed to fetch commission history")
      }
    } catch (error) {
      console.error(error)
      toast.error("Failed to fetch commission history")
    } finally {
      setCommissionsLoading(false)
    }
  }

  async function fetchUsage(code: AffiliateCode) {
    setSelectedCode(code)
    setIsUsageOpen(true)
    setUsageLoading(true)
    try {
      const res = await apiFetch(`/admin/affiliate-codes/${code._id}/usage`)
      const data = await res.json()
      if (res.ok) {
        setUsageData(data.data || [])
      }
    } catch (error) {
      console.error(error)
      toast.error("Failed to fetch usage history")
    } finally {
      setUsageLoading(false)
    }
  }

  async function toggleStatus(id: string) {
    try {
      const res = await apiFetch(`/admin/affiliate-codes/${id}/toggle`, { method: "PATCH" })
      if (res.ok) {
        setCodes((prev) => prev.map((c) => (c._id === id ? { ...c, isActive: !c.isActive } : c)))
        toast.success("Status updated")
      }
    } catch (error) {
      toast.error("Failed to update status")
    }
  }

  async function deleteCode(id: string) {
    if (!confirm("Are you sure you want to delete this affiliate code?")) return
    try {
      const res = await apiFetch(`/admin/affiliate-codes/${id}`, { method: "DELETE" })
      if (res.ok) {
        setCodes((prev) => prev.filter((c) => c._id !== id))
        toast.success("Code deleted")
      }
    } catch (error) {
      toast.error("Failed to delete code")
    }
  }

  const totals = useMemo(() => {
    return codes.reduce(
      (acc, c) => {
        acc.discount += c.totalDiscountGenerated || 0
        acc.commission += c.totalCommissionAccrued || 0
        return acc
      },
      { discount: 0, commission: 0 }
    )
  }, [codes])

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-white">Affiliate Codes</h1>
        <Button
          onClick={() => {
            setEditingCode(null)
            setIsModalOpen(true)
          }}
          className="bg-[#86efac] text-black hover:bg-[#86efac]/90"
        >
          <Plus className="h-4 w-4 mr-2" /> Add Code
        </Button>
      </div>

      <div className="grid md:grid-cols-2 gap-4">
        <Card className="bg-[#161616] border-[#333]">
          <CardHeader>
            <CardTitle className="text-sm text-gray-400">Total Discount Generated</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-white">{formatInr(totals.discount)}</div>
          </CardContent>
        </Card>
        <Card className="bg-[#161616] border-[#333]">
          <CardHeader>
            <CardTitle className="text-sm text-gray-400">Total Commission (30%)</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-[#86efac]">{formatInr(totals.commission)}</div>
          </CardContent>
        </Card>
      </div>

      <Card className="bg-[#161616] border-[#333]">
        <CardHeader>
          <CardTitle className="text-white text-lg">Personal Affiliate Recommendations</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex justify-center p-8">
              <Loader2 className="h-8 w-8 animate-spin text-[#86efac]" />
            </div>
          ) : codes.length === 0 ? (
            <div className="text-center text-gray-500 py-10">No affiliate codes found</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow className="border-[#333] hover:bg-transparent">
                  <TableHead className="text-gray-400">Affiliate / Person</TableHead>
                  <TableHead className="text-gray-400">Code</TableHead>
                  <TableHead className="text-gray-400">Discount</TableHead>
                  <TableHead className="text-gray-400">Usage</TableHead>
                  <TableHead className="text-gray-400">Total Discount</TableHead>
                  <TableHead className="text-gray-400">Total Commission</TableHead>
                  <TableHead className="text-gray-400">Status</TableHead>
                  <TableHead className="text-gray-400 text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {codes.map((code) => (
                  <TableRow key={code._id} className="border-[#333] hover:bg-[#1A1A1A]">
                    <TableCell className="text-white">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-gray-800 flex items-center justify-center text-xs">
                          <User className="w-4 h-4 text-gray-400" />
                        </div>
                        <div className="font-medium">{code.personName}</div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <code className="bg-[#0D0D0D] px-2 py-1 rounded text-[#86efac] text-xs font-mono">
                        {code.code}
                      </code>
                    </TableCell>
                    <TableCell className="text-white">
                      {code.discountType === "percentage" ? `${code.discountValue}%` : formatInr(code.discountValue)}
                    </TableCell>
                    <TableCell className="text-gray-400 text-xs text-center">
                      <div className="font-bold text-white">{code.usageCount}</div>
                      <div>limit: {code.usageLimit || "∞"}</div>
                    </TableCell>
                    <TableCell className="text-white">{formatInr(code.totalDiscountGenerated || 0)}</TableCell>
                    <TableCell className="text-[#86efac]">{formatInr(code.totalCommissionAccrued || 0)}</TableCell>
                    <TableCell>
                      <Badge
                        variant="outline"
                        className={code.isActive ? "text-green-400 border-green-400" : "text-gray-500 border-gray-500"}
                      >
                        {code.isActive ? "Active" : "Inactive"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-8 px-3 text-[#86efac] hover:bg-[#86efac]/10 flex items-center gap-2 border border-[#86efac]/20"
                          onClick={() => fetchUsage(code)}
                        >
                          <History className="h-3.5 w-3.5" />
                          <span className="text-xs font-semibold">History</span>
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                          onClick={() => toggleStatus(code._id)}
                          title={code.isActive ? "Deactivate" : "Activate"}
                        >
                          <Power className={`h-4 w-4 ${code.isActive ? "text-green-400" : "text-gray-400"}`} />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                          onClick={() => {
                            setEditingCode(code)
                            setIsModalOpen(true)
                          }}
                        >
                          <Edit2 className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-8 w-8 p-0 text-red-400 hover:bg-red-400/10 hover:text-red-400"
                          onClick={() => deleteCode(code._id)}
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

      <Card className="bg-[#161616] border-[#333]">
        <CardHeader>
          <CardTitle className="text-white text-lg">Commission History</CardTitle>
        </CardHeader>
        <CardContent>
          {commissionsLoading ? (
            <div className="flex justify-center p-8">
              <Loader2 className="h-8 w-8 animate-spin text-[#86efac]" />
            </div>
          ) : commissions.length === 0 ? (
            <div className="text-center text-gray-500 py-10">No commission records found</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow className="border-[#333] hover:bg-transparent">
                  <TableHead className="text-gray-400">Order</TableHead>
                  <TableHead className="text-gray-400">Affiliate</TableHead>
                  <TableHead className="text-gray-400">Discount</TableHead>
                  <TableHead className="text-gray-400">Commission</TableHead>
                  <TableHead className="text-gray-400">Status</TableHead>
                  <TableHead className="text-gray-400">Trigger</TableHead>
                  <TableHead className="text-gray-400">Date</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {commissions.map((row) => (
                  <TableRow key={row._id} className="border-[#333] hover:bg-[#1A1A1A]">
                    <TableCell className="font-mono text-gray-300">{row.orderNumber}</TableCell>
                    <TableCell>
                      <div className="text-white">{row.personNameSnapshot}</div>
                      <div className="text-xs text-[#86efac] font-mono">{row.affiliateCode}</div>
                    </TableCell>
                    <TableCell className="text-white">{formatInr(row.discountAmount)}</TableCell>
                    <TableCell className="text-[#86efac]">{formatInr(row.commissionAmount)}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className="text-yellow-300 border-yellow-300">
                        {row.status.toUpperCase()}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-gray-300">{row.triggerEvent}</TableCell>
                    <TableCell className="text-gray-400 text-sm">
                      {new Date(row.createdAt).toLocaleDateString(undefined, { dateStyle: "medium" })}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <AffiliateModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSuccess={() => {
          fetchCodes()
          fetchCommissions()
        }}
        code={editingCode}
      />

      <Sheet open={isUsageOpen} onOpenChange={setIsUsageOpen}>
        <SheetContent side="right" className="bg-[#161616] border-l-[#333] text-white sm:max-w-md p-0 flex flex-col">
          <SheetHeader className="p-6 border-b border-[#333]">
            <SheetTitle className="text-white flex items-center gap-2">
              <History className="h-5 w-5 text-[#86efac]" />
              Usage History
            </SheetTitle>
            <SheetDescription className="text-gray-400">
              Orders that used code <span className="text-[#86efac] font-mono">{selectedCode?.code}</span>
            </SheetDescription>
          </SheetHeader>

          <div className="flex-1 overflow-hidden flex flex-col">
            {usageLoading ? (
              <div className="flex flex-col items-center justify-center py-20 text-gray-400">
                <Loader2 className="h-10 w-10 animate-spin mb-4 text-[#86efac]" />
                <p>Checking usage data...</p>
              </div>
            ) : usageData.length > 0 ? (
              <ScrollArea className="flex-1 px-6 py-4">
                <div className="space-y-4">
                  {usageData.map((usage) => (
                    <div
                      key={usage._id}
                      className="bg-[#0D0D0D] border border-[#333] p-4 rounded-xl flex items-center justify-between group hover:border-[#86efac]/50 transition-colors"
                    >
                      <div className="flex items-center gap-4">
                        <div className="h-12 w-12 rounded-full bg-[#161616] flex items-center justify-center border border-[#333] group-hover:border-[#86efac]/30">
                          <User className="h-6 w-6 text-gray-500" />
                        </div>
                        <div>
                          <p className="font-semibold text-white">{usage.customerSnapshot?.name || "Anonymous"}</p>
                          <p className="text-xs text-gray-500 font-mono">Order #{usage.orderNumber}</p>
                          <p className="text-[11px] text-gray-400 mt-1">
                            Discount: {formatInr(usage.discount || 0)} | Commission: {formatInr(usage.commissionAmount || 0)}
                          </p>
                          <p className="text-[10px] text-gray-600 mt-1">
                            {new Date(usage.createdAt).toLocaleDateString(undefined, { dateStyle: "medium" })}
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="font-bold text-[#86efac] text-lg">{formatInr(usage.total || 0)}</p>
                        <span
                          className={`text-[10px] px-2 py-0.5 rounded-full inline-block border ${
                            usage.status === "delivered"
                              ? "bg-green-500/5 text-green-500 border-green-500/20"
                              : usage.status === "cancelled"
                              ? "bg-red-500/5 text-red-500 border-red-500/20"
                              : "bg-blue-500/5 text-blue-500 border-blue-500/20"
                          }`}
                        >
                          {usage.status.toUpperCase()}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </ScrollArea>
            ) : (
              <div className="flex flex-col items-center justify-center py-20 text-center px-10">
                <div className="h-20 w-20 rounded-full bg-[#333]/20 flex items-center justify-center mb-4">
                  <User className="h-10 w-10 text-gray-600 opacity-20" />
                </div>
                <h3 className="text-gray-300 font-medium mb-1">No usage recorded</h3>
                <p className="text-sm text-gray-500">This affiliate code hasn&apos;t been used by any customers yet.</p>
              </div>
            )}
          </div>
        </SheetContent>
      </Sheet>
    </div>
  )
}
