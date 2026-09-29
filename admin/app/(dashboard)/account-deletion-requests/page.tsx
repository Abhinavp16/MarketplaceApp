"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { Loader2 } from "@/components/hugeicons"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { apiFetch } from "@/lib/api"
import { toast } from "sonner"

type DeletionStatus = "pending" | "in_review" | "completed" | "rejected" | "cancelled"

type DeletionRequest = {
  _id: string
  status: DeletionStatus
  source: "app" | "website"
  requestedAt: string
  dueAt: string
  completedAt?: string | null
  staffNote?: string | null
  identityVerification?: {
    verifiedAt?: string | null
    verifiedBy?: string | null
    method?: string | null
  } | null
  userId?: {
    _id: string
    name: string
    email?: string | null
    phone?: string | null
    role?: string
    isActive?: boolean
  } | null
}

const statusLabel: Record<DeletionStatus, string> = {
  pending: "Pending",
  in_review: "In review",
  completed: "Completed",
  rejected: "Rejected",
  cancelled: "Cancelled",
}

const statusClass: Record<DeletionStatus, string> = {
  pending: "border-amber-400/40 bg-amber-400/10 text-amber-300",
  in_review: "border-blue-400/40 bg-blue-400/10 text-blue-300",
  completed: "border-indigo-400/40 bg-indigo-400/10 text-indigo-300",
  rejected: "border-red-400/40 bg-red-400/10 text-red-300",
  cancelled: "border-slate-400/40 bg-slate-400/10 text-slate-300",
}

function formatDate(value?: string | null) {
  if (!value) return "—"
  return new Date(value).toLocaleString("en-IN", {
    dateStyle: "medium",
    timeStyle: "short",
  })
}

async function fetchDeletionRequests(statusFilter: "all" | DeletionStatus) {
  const params = new URLSearchParams({ limit: "100" })
  if (statusFilter !== "all") params.set("status", statusFilter)
  const response = await apiFetch(`/admin/account-deletion-requests?${params.toString()}`)
  const body = await response.json()
  if (!response.ok) throw new Error(body.message || "Unable to load deletion requests")
  return body.data || []
}

export default function AccountDeletionRequestsPage() {
  const [requests, setRequests] = useState<DeletionRequest[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [statusFilter, setStatusFilter] = useState<"all" | DeletionStatus>("all")
  const [selectedRequest, setSelectedRequest] = useState<DeletionRequest | null>(null)
  const [memberNote, setMemberNote] = useState("")
  const [identityVerified, setIdentityVerified] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const outstandingCount = useMemo(
    () => requests.filter((request) => request.status === "pending" || request.status === "in_review").length,
    [requests],
  )

  useEffect(() => {
    let cancelled = false

    async function loadInitialRequests() {
      try {
        const nextRequests = await fetchDeletionRequests(statusFilter)
        if (!cancelled) setRequests(nextRequests)
      } catch (error) {
        if (!cancelled) {
          toast.error(error instanceof Error ? error.message : "Unable to load deletion requests")
        }
      } finally {
        if (!cancelled) setIsLoading(false)
      }
    }

    void loadInitialRequests()
    return () => {
      cancelled = true
    }
  }, [statusFilter])

  const loadRequests = useCallback(async () => {
    setIsLoading(true)
    try {
      setRequests(await fetchDeletionRequests(statusFilter))
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Unable to load deletion requests")
    } finally {
      setIsLoading(false)
    }
  }, [statusFilter])

  function openRequest(request: DeletionRequest) {
    setSelectedRequest(request)
    setMemberNote(request.staffNote || "")
    setIdentityVerified(Boolean(request.identityVerification?.verifiedAt))
  }

  async function updateStatus(status: "in_review" | "rejected" | "completed") {
    if (!selectedRequest) return
    if (status === "completed" && !window.confirm("Complete this deletion request? This will immediately revoke account access and remove/anonymize direct account data.")) {
      return
    }

    setIsSubmitting(true)
    try {
      const endpoint = status === "completed"
        ? `/admin/account-deletion-requests/${selectedRequest._id}/complete`
        : `/admin/account-deletion-requests/${selectedRequest._id}`
      const response = await apiFetch(endpoint, {
        method: status === "completed" ? "POST" : "PUT",
        body: JSON.stringify(status === "completed" ? { staffNote: memberNote } : { status, staffNote: memberNote, identityVerified }),
      })
      const body = await response.json()
      if (!response.ok) throw new Error(body.message || "Unable to update deletion request")
      toast.success(body.message || "Deletion request updated")
      setSelectedRequest(null)
      await loadRequests()
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Unable to update deletion request")
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Account Deletion Requests</h1>
          <p className="mt-1 text-sm text-gray-400">
            Process verified account-deletion requests within 30 days. Completion revokes access and removes or anonymizes direct account data.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <Badge className="border-amber-400/30 bg-amber-400/10 px-3 py-1.5 text-amber-200">
            {outstandingCount} awaiting action
          </Badge>
          <select
            aria-label="Filter deletion requests by status"
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value as "all" | DeletionStatus)}
            className="h-10 rounded-md border border-[#333] bg-[#111] px-3 text-sm text-white outline-none focus:border-[#818cf8]"
          >
            <option value="all">All statuses</option>
            {Object.entries(statusLabel).map(([status, label]) => <option key={status} value={status}>{label}</option>)}
          </select>
          <Button onClick={() => void loadRequests()} variant="outline" className="border-[#333] bg-[#111] text-white hover:bg-[#222]">
            Refresh
          </Button>
        </div>
      </div>

      <Card className="border-[#333] bg-[#161616]">
        <CardHeader>
          <CardTitle className="text-white">Deletion queue</CardTitle>
          <CardDescription className="text-gray-400">Verify website requests with the account holder before marking them in review or completing them.</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex justify-center py-12"><Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" /></div>
          ) : requests.length === 0 ? (
            <p className="py-12 text-center text-sm text-gray-500">No deletion requests match this filter.</p>
          ) : (
            <div className="space-y-3">
              {requests.map((request) => {
                const isOverdue = ["pending", "in_review"].includes(request.status) && new Date(request.dueAt) < new Date()
                return (
                  <button
                    type="button"
                    key={request._id}
                    onClick={() => openRequest(request)}
                    className="grid w-full gap-3 rounded-xl border border-[#333] bg-[#0D0D0D] p-4 text-left transition-colors hover:border-[#818cf8]/50 hover:bg-[#151515] md:grid-cols-[minmax(0,1fr)_auto_auto] md:items-center"
                  >
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-white">{request.userId?.name || "Account no longer available"}</p>
                      <p className="truncate text-sm text-gray-400">{request.userId?.email || request.userId?.phone || "Account identity requires member verification"}</p>
                      <p className="mt-1 text-xs text-gray-500">Requested {formatDate(request.requestedAt)} via {request.source}</p>
                    </div>
                    <div className="text-left md:text-right">
                      <p className={`text-xs font-semibold ${isOverdue ? "text-red-300" : "text-gray-300"}`}>{isOverdue ? "Overdue" : "Due"}: {formatDate(request.dueAt)}</p>
                    </div>
                    <Badge variant="outline" className={statusClass[request.status]}>{statusLabel[request.status]}</Badge>
                  </button>
                )
              })}
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={selectedRequest !== null} onOpenChange={(open) => !open && setSelectedRequest(null)}>
        <DialogContent className="max-w-xl border-[#333] bg-[#161616] text-white">
          <DialogHeader>
            <DialogTitle>Process deletion request</DialogTitle>
            <DialogDescription className="text-gray-400">
              {selectedRequest?.userId?.name || "Unknown account"} · requested {formatDate(selectedRequest?.requestedAt)}
            </DialogDescription>
          </DialogHeader>
          {selectedRequest ? (
            <div className="space-y-5">
              <div className="rounded-lg border border-[#333] bg-[#0D0D0D] p-4 text-sm text-gray-300">
                <p><span className="text-gray-500">Source:</span> {selectedRequest.source}</p>
                <p className="mt-2"><span className="text-gray-500">Due:</span> {formatDate(selectedRequest.dueAt)}</p>
                <p className="mt-2"><span className="text-gray-500">Current status:</span> {statusLabel[selectedRequest.status]}</p>
                <p className="mt-3 text-xs leading-relaxed text-gray-500">Completing the request deactivates the account, revokes all refresh tokens, deletes cart/device-token/notification/negotiation data, removes account media, and anonymizes direct profile data. Restricted financial records remain according to the retention schedule.</p>
              </div>
              {selectedRequest.status === "pending" || selectedRequest.status === "in_review" ? (
                <>
                  {selectedRequest.source === "website" && selectedRequest.status === "pending" ? (
                    <label className="flex items-start gap-3 rounded-lg border border-amber-400/30 bg-amber-400/10 p-3 text-sm text-amber-100">
                      <input
                        type="checkbox"
                        checked={identityVerified}
                        onChange={(event) => setIdentityVerified(event.target.checked)}
                        className="mt-1 h-4 w-4 accent-amber-400"
                      />
                      <span>I verified this request directly with the account holder. This confirmation is recorded with my member account.</span>
                    </label>
                  ) : null}
                  <Textarea
                    value={memberNote}
                    onChange={(event) => setMemberNote(event.target.value)}
                    placeholder="Verification outcome, retention exception, or rejection reason"
                    className="min-h-28 border-[#333] bg-[#0D0D0D] text-white placeholder:text-gray-500"
                  />
                  <div className="flex flex-col gap-2 sm:flex-row sm:justify-end">
                    {selectedRequest.status === "pending" ? <Button disabled={isSubmitting || (selectedRequest.source === "website" && !identityVerified)} onClick={() => void updateStatus("in_review")} variant="outline" className="border-blue-400/30 bg-blue-400/10 text-blue-200 hover:bg-blue-400/20">Mark in review</Button> : null}
                    <Button disabled={isSubmitting} onClick={() => void updateStatus("rejected")} variant="outline" className="border-red-400/30 bg-red-400/10 text-red-200 hover:bg-red-400/20">Reject request</Button>
                    <Button disabled={isSubmitting} onClick={() => void updateStatus("completed")} className="bg-[#818cf8] text-black hover:bg-[#abadef]">{isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : "Complete deletion"}</Button>
                  </div>
                </>
              ) : (
                <p className="rounded-lg border border-[#333] bg-[#0D0D0D] p-3 text-sm text-gray-400">This request is no longer actionable. Member note: {selectedRequest.staffNote || "—"}</p>
              )}
            </div>
          ) : null}
        </DialogContent>
      </Dialog>
    </div>
  )
}
