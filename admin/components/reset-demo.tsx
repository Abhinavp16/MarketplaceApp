"use client"

import { useState } from "react"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Loader2 } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"
import { useDemoInfo } from "@/lib/demo"

const CONFIRM_PHRASE = "RESET DEMO"

// Only rendered when GET /demo/info reports demoMode: true.
export function ResetDemoCard() {
  const { info } = useDemoInfo()
  const [open, setOpen] = useState(false)
  const [typed, setTyped] = useState("")
  const [isResetting, setIsResetting] = useState(false)

  if (!info?.demoMode) return null

  async function resetDemo() {
    setIsResetting(true)
    try {
      const res = await apiFetch("/admin/demo/reset", {
        method: "POST",
        body: JSON.stringify({ confirm: CONFIRM_PHRASE }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok || data?.success === false) throw new Error(data?.message || "Demo reset failed")
      toast.success("Demo data reset to its original state. Reloading...")
      setOpen(false)
      setTyped("")
      window.setTimeout(() => window.location.reload(), 800)
    } catch (error: any) {
      toast.error(error?.message || "Demo reset failed")
    } finally {
      setIsResetting(false)
    }
  }

  return (
    <>
      <Card className="border-[#333] bg-[#161616]">
        <CardHeader>
          <CardTitle className="text-white">Reset Demo</CardTitle>
          <CardDescription>
            Restore all synthetic demo data (products, orders, negotiations, users) to its original seeded state. Changes made during the demo will be lost.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button type="button" variant="destructive" onClick={() => setOpen(true)}>
            Reset Demo
          </Button>
        </CardContent>
      </Card>

      <Dialog open={open} onOpenChange={(next) => { if (!isResetting) { setOpen(next); if (!next) setTyped("") } }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Reset demo data?</DialogTitle>
            <DialogDescription>
              This wipes everything created in this demo and restores the original sample data. Type <span className="font-mono font-semibold">{CONFIRM_PHRASE}</span> to confirm.
            </DialogDescription>
          </DialogHeader>
          <Input
            value={typed}
            onChange={(event) => setTyped(event.target.value)}
            placeholder={CONFIRM_PHRASE}
            aria-label="Type RESET DEMO to confirm"
            autoComplete="off"
          />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => { setOpen(false); setTyped("") }} disabled={isResetting}>
              Cancel
            </Button>
            <Button type="button" variant="destructive" onClick={resetDemo} disabled={typed !== CONFIRM_PHRASE || isResetting}>
              {isResetting ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
              Reset Demo
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}
