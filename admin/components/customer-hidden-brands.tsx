"use client"

import { useEffect, useMemo, useState } from "react"
import { toast } from "sonner"
import { EyeOff, Loader2, Search } from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"
import { apiFetch } from "@/lib/api"

type Brand = { _id: string; name: string; hideFromCustomers?: boolean }

const sameSet = (a: Set<string>, b: Set<string>) => a.size === b.size && [...a].every((id) => b.has(id))

// Customer Profile: brands hidden from this one customer. They won't see those
// brands, their categories or products in the app, and can't order them.
export function CustomerHiddenBrands({
    customerId,
    hiddenBrands,
    onSaved,
}: {
    customerId: string
    hiddenBrands: string[]
    onSaved: (hiddenBrands: string[]) => void
}) {
    const [brands, setBrands] = useState<Brand[] | null>(null)
    const [loadFailed, setLoadFailed] = useState(false)
    const [saved, setSaved] = useState(() => new Set(hiddenBrands))
    const [selected, setSelected] = useState(() => new Set(hiddenBrands))
    const [search, setSearch] = useState("")
    const [isSaving, setIsSaving] = useState(false)

    useEffect(() => {
        let cancelled = false
        apiFetch("/companies?page=1&limit=500")
            .then((res) => res.json().then((body) => ({ ok: res.ok, body })))
            .then(({ ok, body }) => {
                if (cancelled) return
                if (!ok) throw new Error(body?.message)
                setBrands(Array.isArray(body?.data) ? body.data : [])
            })
            .catch(() => !cancelled && setLoadFailed(true))
        return () => {
            cancelled = true
        }
    }, [])

    const visibleBrands = useMemo(() => {
        const query = search.trim().toLowerCase()
        return (brands || []).filter((brand) => !query || brand.name.toLowerCase().includes(query))
    }, [brands, search])

    const changed = !sameSet(selected, saved)

    function toggle(id: string, checked: boolean) {
        setSelected((current) => {
            const next = new Set(current)
            if (checked) next.add(id)
            else next.delete(id)
            return next
        })
    }

    async function save() {
        setIsSaving(true)
        try {
            const res = await apiFetch(`/admin/customers/${customerId}/brand-access`, {
                method: "PUT",
                body: JSON.stringify({ hiddenBrands: [...selected] }),
            })
            const body = await res.json()
            if (!res.ok) throw new Error(body?.message || "Could not save hidden brands")
            const next = new Set<string>(body?.data?.hiddenBrands || [...selected])
            setSaved(next)
            setSelected(next)
            onSaved([...next])
            toast.success(body?.message || "Hidden brands saved")
        } catch (error) {
            toast.error(error instanceof Error ? error.message : "Could not save hidden brands")
        } finally {
            setIsSaving(false)
        }
    }

    return (
        <section aria-labelledby="hidden-brands-heading" className="rounded-lg border border-[#333] bg-[#0D0D0D] p-4">
            <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                    <h3 id="hidden-brands-heading" className="flex items-center gap-2 font-medium">
                        <EyeOff className="h-4 w-4 text-amber-300" />
                        Hidden brands
                    </h3>
                    <p className="mt-1 text-xs text-gray-400">
                        Tick brands to hide from this customer. They won&apos;t see those brands, their categories or products in the app, and can&apos;t order them.
                    </p>
                </div>
                {saved.size > 0 && (
                    <span className="rounded-full border border-amber-500/40 bg-amber-500/10 px-2 py-0.5 text-[11px] font-semibold text-amber-300">
                        {saved.size} hidden
                    </span>
                )}
            </div>

            {loadFailed ? (
                <p className="mt-3 text-sm text-red-300">Couldn&apos;t load brands. Close and reopen the profile to try again.</p>
            ) : brands === null ? (
                <div className="mt-3 flex items-center gap-2 text-sm text-gray-400"><Loader2 className="h-4 w-4 animate-spin" /> Loading brands…</div>
            ) : (
                <>
                    {brands.length > 8 && (
                        <div className="relative mt-3">
                            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
                            <Input
                                value={search}
                                onChange={(event) => setSearch(event.target.value)}
                                placeholder="Search brands…"
                                aria-label="Search brands"
                                className="h-9 border-[#333] bg-[#161616] pl-9 text-white"
                            />
                        </div>
                    )}
                    <div className="mt-3 grid max-h-56 grid-cols-1 gap-1 overflow-y-auto pr-1 sm:grid-cols-2">
                        {visibleBrands.map((brand) => {
                            const id = `hide-brand-${brand._id}`
                            return (
                                <label key={brand._id} htmlFor={id} className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-[#1A1A1A]">
                                    <Checkbox
                                        id={id}
                                        checked={selected.has(brand._id)}
                                        onCheckedChange={(checked) => toggle(brand._id, checked === true)}
                                        aria-label={`Hide ${brand.name} from this customer`}
                                    />
                                    <span className="min-w-0 flex-1 truncate">{brand.name}</span>
                                    {brand.hideFromCustomers && (
                                        <span className="shrink-0 text-[10px] text-gray-500" title="This brand's own switch hides it from all retail customers">all retail hidden</span>
                                    )}
                                </label>
                            )
                        })}
                        {visibleBrands.length === 0 && <p className="px-2 py-1.5 text-sm text-gray-500">No brands match.</p>}
                    </div>
                    <div className="mt-3 flex flex-wrap justify-end gap-2">
                        {selected.size > 0 && (
                            <Button type="button" variant="outline" size="sm" onClick={() => setSelected(new Set())} disabled={isSaving}>
                                Clear all
                            </Button>
                        )}
                        <Button type="button" size="sm" onClick={() => void save()} disabled={!changed || isSaving}>
                            {isSaving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                            Save hidden brands
                        </Button>
                    </div>
                </>
            )}
        </section>
    )
}
