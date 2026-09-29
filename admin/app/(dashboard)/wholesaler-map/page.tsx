"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { ArrowLeft, ExternalLink, Loader2, MapPinned, Package, Phone, Search } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"
import { toast } from "sonner"
import { MapSkeleton, TableSkeleton } from "@/components/ui/skeleton"

type WholesalerLocation = {
  id: string
  businessName: string
  contactPerson: string
  phone: string
  businessAddress: string
  approvedAt?: string
  shopLocation: {
    lat: number
    lng: number
    placeLabel?: string | null
    capturedAt?: string | null
  }
}

type ShopOrder = {
  _id: string
  orderNumber: string
  items: {
    productSnapshot?: { name?: string }
    quantity: number
    pricePerUnit: number
  }[]
  customerSnapshot?: {
    name?: string
    phone?: string
    email?: string
  }
  total: number
  status: string
  createdAt: string
  shippingAddress?: {
    address?: string
    city?: string
    state?: string
    pincode?: string
  }
}

declare global {
  interface Window {
    L?: any
  }
}

function loadLeafletCss() {
  if (document.getElementById("leaflet-css")) return
  const link = document.createElement("link")
  link.id = "leaflet-css"
  link.rel = "stylesheet"
  link.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
  document.head.appendChild(link)
}

function loadLeafletScript() {
  return new Promise<void>((resolve, reject) => {
    if (window.L) {
      resolve()
      return
    }

    const existing = document.getElementById("leaflet-js") as HTMLScriptElement | null
    if (existing) {
      existing.addEventListener("load", () => resolve())
      existing.addEventListener("error", () => reject(new Error("Failed to load Leaflet")))
      return
    }

    const script = document.createElement("script")
    script.id = "leaflet-js"
    script.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
    script.async = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error("Failed to load Leaflet"))
    document.body.appendChild(script)
  })
}

export default function WholesalerMapPage() {
  const mapRef = useRef<HTMLDivElement | null>(null)
  const leafletMapRef = useRef<any>(null)
  const markersLayerRef = useRef<any>(null)

  const [locations, setLocations] = useState<WholesalerLocation[]>([])
  const [search, setSearch] = useState("")
  const [isLoading, setIsLoading] = useState(true)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [panelMode, setPanelMode] = useState<"details" | "history">("details")
  const [shopOrders, setShopOrders] = useState<ShopOrder[]>([])
  const [isLoadingOrders, setIsLoadingOrders] = useState(false)
  const [ordersError, setOrdersError] = useState<string | null>(null)
  const [expandedOrderId, setExpandedOrderId] = useState<string | null>(null)

  useEffect(() => {
    void fetchLocations()
  }, [])

  async function fetchLocations() {
    setIsLoading(true)
    try {
      const res = await apiFetch("/admin/wholesaler-locations")
      const data = await res.json()
      if (!res.ok) {
        toast.error(data.message || "Failed to load wholesaler locations")
        return
      }
      setLocations(data.data || [])
      if (!selectedId && data.data?.length) {
        setSelectedId(data.data[0].id)
      }
    } catch (error) {
      toast.error("Error loading wholesaler locations")
    } finally {
      setIsLoading(false)
    }
  }

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return locations
    return locations.filter((item) =>
      [item.businessName, item.contactPerson, item.phone, item.businessAddress]
        .filter(Boolean)
        .some((value) => value.toLowerCase().includes(q))
    )
  }, [locations, search])

  const selected = filtered.find((item) => item.id === selectedId) || filtered[0] || null

  useEffect(() => {
    setExpandedOrderId(null)
    if (panelMode === "history" && selected?.id) {
      void fetchShopOrders(selected.id)
    }
  }, [panelMode, selected?.id])

  async function fetchShopOrders(userId: string) {
    setIsLoadingOrders(true)
    setOrdersError(null)
    try {
      const params = new URLSearchParams({
        userId,
        limit: "10",
        page: "1",
      })
      const res = await apiFetch(`/admin/orders?${params.toString()}`)
      const data = await res.json()
      if (!res.ok) {
        const message = data.message || "Failed to load order history"
        setOrdersError(message)
        toast.error(message)
        return
      }
      setShopOrders(data.data || [])
    } catch (error) {
      setOrdersError("Error loading order history")
      toast.error("Error loading order history")
    } finally {
      setIsLoadingOrders(false)
    }
  }

  useEffect(() => {
    let cancelled = false

    async function initMap() {
      if (!mapRef.current) return
      loadLeafletCss()
      await loadLeafletScript()
      if (cancelled || !mapRef.current || !window.L) return

      if (!leafletMapRef.current) {
        leafletMapRef.current = window.L.map(mapRef.current).setView([20.5937, 78.9629], 5)
        window.L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
          attribution: "&copy; OpenStreetMap contributors",
        }).addTo(leafletMapRef.current)
        markersLayerRef.current = window.L.layerGroup().addTo(leafletMapRef.current)
      }

      const markerLayer = markersLayerRef.current
      markerLayer.clearLayers()

      if (!filtered.length) return

      const bounds: any[] = []
      filtered.forEach((item) => {
        const latLng = [item.shopLocation.lat, item.shopLocation.lng]
        bounds.push(latLng)
        const marker = window.L.marker(latLng)
        marker.bindPopup(
          `<strong>${item.businessName}</strong><br/>${item.contactPerson}<br/>${item.phone}<br/>${item.businessAddress}`
        )
        marker.on("click", () => setSelectedId(item.id))
        marker.addTo(markerLayer)
      })

      if (selected) {
        leafletMapRef.current.setView([selected.shopLocation.lat, selected.shopLocation.lng], 13)
      } else if (bounds.length > 1) {
        leafletMapRef.current.fitBounds(bounds, { padding: [30, 30] })
      } else {
        leafletMapRef.current.setView(bounds[0], 13)
      }
    }

    void initMap()
    return () => {
      cancelled = true
    }
  }, [filtered, selected])

    return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-white">Wholesaler Map</h1>
          <p className="text-gray-400 text-sm">Approved wholesaler shops only</p>
        </div>
        <Button
          variant="outline"
          className="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] sm:w-auto"
          onClick={() => void fetchLocations()}
        >
          Refresh
        </Button>
      </div>

      <div className="relative w-full max-w-md">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by business, contact, phone, address"
          className="pl-10 bg-[#161616] border-[#333] text-white placeholder:text-gray-500"
        />
      </div>

      {isLoading ? (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1.2fr)_360px]">
          <MapSkeleton />
          <TableSkeleton rows={5} columns={1} />
        </div>
      ) : (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1.2fr)_360px]">
          <Card className="bg-[#161616] border-[#333] overflow-hidden">
            <CardHeader>
              <CardTitle className="text-white">Shop Pins</CardTitle>
            </CardHeader>
            <CardContent>
              {filtered.length === 0 ? (
                <div className="rounded-xl border border-dashed border-[#333] bg-[#0D0D0D] p-10 text-center text-gray-500">
                  No approved wholesaler locations found.
                </div>
              ) : (
                <div ref={mapRef} className="h-[42vh] w-full overflow-hidden rounded-xl sm:h-[50vh] lg:h-[65vh]" />
              )}
            </CardContent>
          </Card>

          <div className="flex flex-col gap-4">
            <Card className="bg-[#161616] border-[#333]">
              <CardHeader>
                <CardTitle className="text-white">Wholesalers ({filtered.length})</CardTitle>
              </CardHeader>
              <CardContent className="max-h-[32vh] space-y-3 overflow-y-auto pr-1 sm:max-h-[38vh]">
                {filtered.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => setSelectedId(item.id)}
                    className={`w-full rounded-xl border p-4 text-left transition ${
                      selected?.id === item.id
                        ? "border-[#818cf8] bg-[#818cf8]/10"
                        : "border-[#333] bg-[#0D0D0D] hover:border-[#555]"
                    }`}
                  >
                    <div className="text-sm font-semibold text-white">{item.businessName}</div>
                    <div className="mt-1 text-xs text-gray-400">{item.contactPerson}</div>
                    <div className="mt-2 flex items-center gap-2 text-xs text-gray-300">
                      <Phone className="h-3.5 w-3.5" />
                      {item.phone}
                    </div>
                  </button>
                ))}
              </CardContent>
            </Card>

            <Card className="bg-[#161616] border-[#333]">
              <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0">
                <CardTitle className="text-white">
                  {panelMode === "history" ? "Order History" : "Selected Shop"}
                </CardTitle>
                {panelMode === "history" && (
                  <Button
                    type="button"
                    variant="ghost"
                    className="h-auto px-2 py-1 text-gray-400 hover:text-white"
                    onClick={() => setPanelMode("details")}
                  >
                    <ArrowLeft className="mr-1 h-4 w-4" />
                    Back
                  </Button>
                )}
              </CardHeader>
              <CardContent>
                {!selected ? (
                  <div className="text-sm text-gray-500">Select a wholesaler to view details.</div>
                ) : panelMode === "details" ? (
                  <div className="space-y-4 text-sm">
                    <div className="space-y-3">
                      <div className="flex items-start gap-3">
                        <MapPinned className="mt-0.5 h-4 w-4 text-[#818cf8]" />
                        <div>
                          <div className="font-semibold text-white">{selected.businessName}</div>
                          <div className="text-gray-400">{selected.contactPerson}</div>
                        </div>
                      </div>
                      <div className="text-gray-300">{selected.phone}</div>
                      <div className="text-gray-400 whitespace-pre-wrap">{selected.businessAddress}</div>
                      <div className="rounded-lg border border-[#333] bg-[#0D0D0D] p-3 text-xs text-gray-300">
                        {selected.shopLocation.lat.toFixed(6)}, {selected.shopLocation.lng.toFixed(6)}
                      </div>
                      {selected.approvedAt && (
                        <div className="text-xs text-gray-500">
                          Approved on {new Date(selected.approvedAt).toLocaleDateString("en-IN")}
                        </div>
                      )}
                    </div>

                    <div className="flex flex-col gap-2">
                      <Button
                        type="button"
                        className="w-full bg-[#818cf8] text-black hover:bg-[#797cd6]"
                        onClick={() => {
                          setPanelMode("history")
                          void fetchShopOrders(selected.id)
                        }}
                      >
                        <Package className="mr-2 h-4 w-4" />
                        View Order History
                      </Button>
                      <Link
                        href={`/orders?userId=${encodeURIComponent(selected.id)}&customerName=${encodeURIComponent(selected.businessName)}`}
                        className="inline-flex items-center justify-center rounded-md border border-[#333] px-4 py-2 text-sm font-medium text-white transition hover:bg-[#1A1A1A]"
                      >
                        <ExternalLink className="mr-2 h-4 w-4" />
                        Open in Orders
                      </Link>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-4">
                    <div>
                      <div className="text-sm font-semibold text-white">{selected.businessName}</div>
                      <div className="text-xs text-gray-400">
                        Orders placed by {selected.contactPerson}
                      </div>
                    </div>

                    <Link
                      href={`/orders?userId=${encodeURIComponent(selected.id)}&customerName=${encodeURIComponent(selected.businessName)}`}
                      className="inline-flex items-center gap-2 text-sm text-[#818cf8] hover:underline"
                    >
                      <ExternalLink className="h-4 w-4" />
                      Open full order management
                    </Link>

                    {isLoadingOrders ? (
                      <TableSkeleton rows={3} columns={2} />
                    ) : ordersError ? (
                      <div className="rounded-lg border border-[#4a2d2d] bg-[#201414] p-3 text-sm text-red-300">
                        {ordersError}
                      </div>
                    ) : shopOrders.length === 0 ? (
                      <div className="rounded-lg border border-dashed border-[#333] bg-[#0D0D0D] p-4 text-sm text-gray-500">
                        No orders found for this shop yet.
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {shopOrders.map((order) => {
                          const itemCount = order.items.reduce((sum, item) => sum + (item.quantity || 0), 0)
                          const isExpanded = expandedOrderId === order._id
                          return (
                            <div key={order._id} className="rounded-xl border border-[#333] bg-[#0D0D0D] p-3">
                              <button
                                type="button"
                                onClick={() => setExpandedOrderId(isExpanded ? null : order._id)}
                                className="w-full text-left"
                              >
                                <div className="flex items-start justify-between gap-3">
                                  <div>
                                    <div className="text-sm font-semibold text-white">{order.orderNumber}</div>
                                    <div className="mt-1 text-xs text-gray-400">
                                      {new Date(order.createdAt).toLocaleDateString("en-IN")} · {itemCount} items
                                    </div>
                                  </div>
                                  <div className="text-right">
                                    <div className="text-sm font-semibold text-white">
                                      ₹{Number(order.total || 0).toLocaleString("en-IN")}
                                    </div>
                                    <div className="mt-1 text-xs uppercase text-[#818cf8]">
                                      {order.status.replace(/_/g, " ")}
                                    </div>
                                  </div>
                                </div>
                              </button>

                              {isExpanded && (
                                <div className="mt-3 space-y-3 border-t border-[#222] pt-3 text-xs text-gray-300">
                                  <div className="space-y-1">
                                    {order.items.map((item, index) => (
                                      <div key={`${order._id}-${index}`} className="flex justify-between gap-3">
                                        <span className="text-gray-300">
                                          {item.productSnapshot?.name || "Product"} x {item.quantity}
                                        </span>
                                        <span className="text-gray-400">
                                          ₹{Number(item.pricePerUnit || 0).toLocaleString("en-IN")}
                                        </span>
                                      </div>
                                    ))}
                                  </div>

                                  {order.shippingAddress && (
                                    <div className="rounded-lg border border-[#222] bg-[#111] p-3 text-gray-400">
                                      <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-gray-500">
                                        Shipping Address
                                      </div>
                                      <div>
                                        {[
                                          order.shippingAddress.address,
                                          order.shippingAddress.city,
                                          order.shippingAddress.state,
                                          order.shippingAddress.pincode,
                                        ]
                                          .filter(Boolean)
                                          .join(", ")}
                                      </div>
                                    </div>
                                  )}

                                  <Link
                                    href={`/orders?userId=${encodeURIComponent(selected.id)}&customerName=${encodeURIComponent(selected.businessName)}&search=${encodeURIComponent(order.orderNumber)}`}
                                    className="inline-flex items-center gap-2 text-[#818cf8] hover:underline"
                                  >
                                    <ExternalLink className="h-3.5 w-3.5" />
                                    Open this order in Orders
                                  </Link>
                                </div>
                              )}
                            </div>
                          )
                        })}
                      </div>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      )}
    </div>
  )
}
