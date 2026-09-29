import { ReactNode } from "react"
import { redirect } from "next/navigation"

import { HIDE_OFFERS_UI } from "@/lib/feature-flags"

export default function OffersLayout({ children }: { children: ReactNode }) {
  if (HIDE_OFFERS_UI) {
    redirect("/")
  }

  return <>{children}</>
}
