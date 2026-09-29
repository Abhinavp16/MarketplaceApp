"use client"

import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { 
    Loader2, Save, Plus, Trash2, GripVertical, Image as ImageIcon, Upload, Search,
    ArrowRight
} from "@/components/hugeicons"
import { HugeiconsIcon } from "@hugeicons/react"
import * as HugeIconsFree from "@hugeicons/core-free-icons"
import { toast } from "sonner"
import { apiFetch, buildApiUrl } from "@/lib/api"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from "@/components/ui/command"

// Generate a searchable list of all Lucide icons
const ICON_OPTIONS = [
    { label: "Ticket (Offer)", value: "Ticket01Icon" },
    { label: "Discount / %", value: "Percent01Icon" },
    { label: "Deal Tag", value: "Tag01Icon" },
    { label: "Shopping Bag", value: "ShoppingBag01Icon" },
    { label: "Market Cart", value: "ShoppingCart01Icon" },
    { label: "Gift Box", value: "GiftIcon" },
    { label: "Flash Sale", value: "FlashIcon" },
    { label: "Truck / Delivery", value: "DeliveryBox01Icon" },
    { label: "Arrow Right", value: "ArrowRight01Icon" },
    { label: "Sparkles", value: "SparklesIcon" },
]

// Filter and prepare ALL available HugeIcons
const ALL_HUGE_ICONS = Object.keys(HugeIconsFree)
    .filter(key => key.endsWith('Icon'))
    .map(key => ({
        label: key.replace('Icon', '').replace(/([A-Z])/g, ' $1').trim(),
        value: key
    }))

const BUTTON_TEXT_SUGGESTIONS = [
    "Shop Now",
    "Explore",
    "View More",
    "Buy Now"
]

function getIconComponent(iconName: string) {
    if (!iconName || iconName === 'none') return <ArrowRight className="h-4 w-4 text-white" />
    
    // Find the icon in the HugeIcons collection
    const IconData = (HugeIconsFree as any)[iconName]
    if (IconData) {
        return (
            <HugeiconsIcon 
                icon={IconData} 
                size={16} 
                color="currentColor" 
                strokeWidth={2}
            />
        )
    }
    
    return <ArrowRight className="h-4 w-4 text-white" />
}

type BannerLinkType = "product" | "brand" | "category"

interface BannerProductOption {
    _id: string
    name: string
    category?: string
    slug?: string
}

interface BannerBrandOption {
    _id: string
    name: string
    slug: string
}

interface BannerCategoryOption {
    _id: string
    name: string
    slug: string
}

interface Banner {
    _id?: string
    title: string
    subtitle: string
    tag: string
    imageUrl: string
    mediaType: 'image' | 'video_upload' | 'youtube'
    videoUrl: string
    linkUrl: string
    linkType: BannerLinkType
    linkedProductId: string
    linkedBrandId: string
    linkedCategoryId: string
    buttonText: string
    buttonIcon: string
    isActive: boolean
    order: number
}

function buildProductLink(productId: string) {
    return productId ? `/product/${productId}` : ""
}

function buildBrandLink(brandId: string) {
    return brandId ? `/brand/${brandId}` : ""
}

function buildCategoryLink(categoryId: string) {
    return categoryId ? `/category/${categoryId}` : ""
}

function inferLinkedProductId(linkUrl: unknown) {
    const value = String(linkUrl || "").trim()
    const match = value.match(/^\/product\/([^/?#]+)/i)
    return match?.[1] || ""
}

function inferLinkedBrandId(linkUrl: unknown) {
    const value = String(linkUrl || "").trim()
    const match = value.match(/^\/brand\/([^/?#]+)/i)
    return match?.[1] || ""
}

function inferLinkedCategoryId(linkUrl: unknown) {
    const value = String(linkUrl || "").trim()
    const match = value.match(/^\/category\/([^/?#]+)/i)
    return match?.[1] || ""
}

function extractYoutubeId(url: unknown) {
    const value = String(url || "").trim()
    const match = value.match(/(?:youtube\.com\/(?:watch\?[^#]*v=|shorts\/|embed\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/i)
    return match?.[1] || ""
}

function youtubeThumbnailUrl(url: unknown) {
    const id = extractYoutubeId(url)
    return id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : ""
}

function createEmptyBanner(order: number): Banner {
    return {
        title: "",
        subtitle: "",
        tag: "",
        imageUrl: "",
        mediaType: "image",
        videoUrl: "",
        linkUrl: "",
        linkType: "url",
        linkedProductId: "",
        linkedBrandId: "",
        linkedCategoryId: "",
        buttonText: "Shop Now",
        buttonIcon: "ArrowRight",
        isActive: true,
        order,
    }
}

function normalizeBanner(banner: any, index: number): Banner {
    const linkedProductId = String(banner?.linkedProductId || inferLinkedProductId(banner?.linkUrl))
    const linkedBrandId = String(banner?.linkedBrandId || inferLinkedBrandId(banner?.linkUrl))
    const linkedCategoryId = String(banner?.linkedCategoryId || inferLinkedCategoryId(banner?.linkUrl))
    
    let linkType: BannerLinkType = "product"
    if (linkedBrandId) linkType = "brand"
    else if (linkedCategoryId) linkType = "category"
    else if (linkedProductId) linkType = "product"

    return {
        _id: typeof banner?._id === "string" ? banner._id : undefined,
        title: String(banner?.title || ""),
        subtitle: String(banner?.subtitle || ""),
        tag: String(banner?.tag || ""),
        imageUrl: String(banner?.imageUrl || ""),
        mediaType: (banner?.mediaType === "video_upload" || banner?.mediaType === "youtube") ? banner.mediaType : "image",
        videoUrl: String(banner?.videoUrl || ""),
        linkUrl: String(banner?.linkUrl || (
            linkType === "product" ? buildProductLink(linkedProductId) :
            linkType === "brand" ? buildBrandLink(linkedBrandId) :
            linkType === "category" ? buildCategoryLink(linkedCategoryId) : ""
        )),
        linkType,
        linkedProductId,
        linkedBrandId,
        linkedCategoryId,
        buttonText: String(banner?.buttonText || "Shop Now"),
        buttonIcon: String(banner?.buttonIcon || "ArrowRight"),
        isActive: banner?.isActive !== false,
        order: Number.isFinite(banner?.order) ? banner.order : index,
    }
}

function BannerIconPicker({ value, onSelect }: { value: string, onSelect: (val: string) => void }) {
    const [open, setOpen] = useState(false)
    const [search, setSearch] = useState("")

    return (
        <Popover open={open} onOpenChange={setOpen}>
            <PopoverTrigger asChild>
                <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={open}
                    className="w-full justify-between bg-[#161616] border-[#333] text-white hover:bg-[#222]"
                >
                    <div className="flex items-center gap-2">
                        {getIconComponent(value)}
                        <span>{ICON_OPTIONS.find(opt => opt.value === value)?.label || 
                              ALL_HUGE_ICONS.find(opt => opt.value === value)?.label || 
                              "Select icon"}</span>
                    </div>
                    <Search className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
            </PopoverTrigger>
            <PopoverContent side="bottom" align="start" className="w-[300px] p-0 bg-[#161616] border-[#333] z-[100]">
                <Command className="bg-[#161616] text-white" shouldFilter={false}>
                    <CommandInput
                        placeholder="Type to search all icons..."
                        className="text-white"
                        onValueChange={setSearch}
                    />
                    <CommandEmpty>No icon found.</CommandEmpty>

                    <div className="max-h-[300px] overflow-y-auto min-h-[300px]">
                        {/* Show suggestions only when NOT searching */}
                        {!search && (
                            <CommandGroup heading="Product & Offers" className="text-[#919191]">
                                {ICON_OPTIONS.map((opt) => (
                                    <CommandItem
                                        key={opt.value}
                                        value={opt.value}
                                        onSelect={(val) => {
                                            // Directly select the value from ICON_OPTIONS finding logic
                                            const original = ICON_OPTIONS.find(o => o.value.toLowerCase() === val.toLowerCase())?.value || val
                                            onSelect(original)
                                            setOpen(false)
                                            setSearch("")
                                        }}
                                        className="hover:bg-[#333] cursor-pointer text-white"
                                    >
                                        <div className="flex items-center gap-2">
                                            {getIconComponent(opt.value)}
                                            <span>{opt.label}</span>
                                        </div>
                                    </CommandItem>
                                ))}
                            </CommandGroup>
                        )}

                        {/* Show results only when searching */}
                        {search && (
                            <CommandGroup heading="Search Results" className="text-[#919191]">
                                {ALL_HUGE_ICONS.filter(opt =>
                                    opt.label.toLowerCase().includes(search.toLowerCase()) ||
                                    opt.value.toLowerCase().includes(search.toLowerCase()) ||
                                    opt.value === value // keep current icon visible if possible
                                ).slice(0, 50).map((opt: any) => (
                                    <CommandItem
                                        key={opt.value}
                                        value={opt.value}
                                        onSelect={(val) => {
                                            const originalValue = ALL_HUGE_ICONS.find(i => i.value.toLowerCase() === val.toLowerCase())?.value || val
                                            onSelect(originalValue)
                                            setOpen(false)
                                            setSearch("")
                                        }}
                                        className="hover:bg-[#333] cursor-pointer text-white"
                                    >
                                        <div className="flex items-center gap-2">
                                            {getIconComponent(opt.value)}
                                            <span>{opt.label}</span>
                                        </div>
                                    </CommandItem>
                                ))}
                            </CommandGroup>
                        )}
                    </div>
                </Command>
            </PopoverContent>
        </Popover>
    )
}

export default function BannersPage() {
    const [isLoading, setIsLoading] = useState(true)
    const [heroBanners, setHeroBanners] = useState<Banner[]>([])
    const [promoBanners, setPromoBanners] = useState<Banner[]>([])
    const [availableProducts, setAvailableProducts] = useState<BannerProductOption[]>([])
    const [availableBrands, setAvailableBrands] = useState<BannerBrandOption[]>([])
    const [availableCategories, setAvailableCategories] = useState<BannerCategoryOption[]>([])
    const [isLoadingProductOptions, setIsLoadingProductOptions] = useState(false)
    const [isLoadingBrandOptions, setIsLoadingBrandOptions] = useState(false)
    const [isLoadingCategoryOptions, setIsLoadingCategoryOptions] = useState(false)
    const [isSavingHero, setIsSavingHero] = useState(false)
    const [isSavingPromo, setIsSavingPromo] = useState(false)
    const [uploadingIndex, setUploadingIndex] = useState<{ type: 'hero' | 'promo', index: number } | null>(null)

    function resolveBannerPreviewUrl(url: string) {
        const trimmed = url.trim()
        if (!trimmed) return ""
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        if (trimmed.startsWith("/")) {
            return buildApiUrl(trimmed).replace("/api/v1", "")
        }
        return trimmed
    }

    async function handleBannerUpload(e: React.ChangeEvent<HTMLInputElement>, type: 'hero' | 'promo', index: number) {
        const file = e.target.files?.[0]
        if (!file) return

        setUploadingIndex({ type, index })

        const formData = new FormData()
        formData.append('image', file)

        try {
            const token = localStorage.getItem('accessToken')
            const res = await fetch(buildApiUrl('/upload/image?folder=banners'), {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`
                },
                body: formData
            })

            const data = await res.json()
            if (res.ok && data.success) {
                if (type === 'hero') {
                    updateHeroBanner(index, 'imageUrl', data.data.url)
                } else {
                    updatePromoBanner(index, 'imageUrl', data.data.url)
                }
                toast.success("Image uploaded successfully")
            } else {
                toast.error(data.message || "Upload failed")
            }
        } catch (error) {
            toast.error("Error uploading image")
        } finally {
            setUploadingIndex(null)
            // Reset the input value so the same file can be uploaded again if needed
            e.target.value = ''
        }
    }

    async function handleBannerVideoUpload(e: React.ChangeEvent<HTMLInputElement>, type: 'hero' | 'promo', index: number) {
        const file = e.target.files?.[0]
        if (!file) return

        if (file.size > 25 * 1024 * 1024) {
            toast.error("Video too large. Maximum size: 25MB")
            e.target.value = ''
            return
        }

        setUploadingIndex({ type, index })

        const formData = new FormData()
        formData.append('video', file)

        try {
            const token = localStorage.getItem('accessToken')
            const res = await fetch(buildApiUrl('/upload/video?folder=banners'), {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`
                },
                body: formData
            })

            const data = await res.json()
            if (res.ok && data.success) {
                if (type === 'hero') {
                    updateHeroBanner(index, 'videoUrl', data.data.url)
                } else {
                    updatePromoBanner(index, 'videoUrl', data.data.url)
                }
                toast.success("Video uploaded successfully")
            } else {
                toast.error(data.message || "Video upload failed")
            }
        } catch (error) {
            toast.error("Error uploading video")
        } finally {
            setUploadingIndex(null)
            // Reset the input value so the same file can be uploaded again if needed
            e.target.value = ''
        }
    }

    useEffect(() => {
        fetchBanners()
        loadProductOptions()
        loadBrandOptions()
        loadCategoryOptions()
    }, [])

    async function fetchBanners() {
        try {
            const res = await apiFetch('/admin/settings')
            const data = await res.json()
            if (res.ok && data.data) {
                if (data.data.heroBanners) {
                    setHeroBanners(data.data.heroBanners.map((banner: any, index: number) => normalizeBanner(banner, index)))
                }
                if (data.data.promoBanners) {
                    setPromoBanners(data.data.promoBanners.map((banner: any, index: number) => normalizeBanner(banner, index)))
                }
            }
        } catch (error) {
            toast.error("Failed to load banners")
        } finally {
            setIsLoading(false)
        }
    }

    async function loadProductOptions() {
        setIsLoadingProductOptions(true)
        try {
            const collected: BannerProductOption[] = []
            let page = 1
            let hasNext = true

            while (hasNext && page <= 20) {
                const res = await apiFetch(`/admin/products?page=${page}&limit=50&status=active&sort=name:asc`)
                const data = await res.json()
                if (!res.ok) throw new Error("failed")

                const items = Array.isArray(data?.data) ? data.data : []
                collected.push(
                    ...items
                        .map((item: any) => ({
                            _id: String(item?._id || ""),
                            name: String(item?.name || ""),
                            category: typeof item?.category === "string" ? item.category : "",
                            slug: typeof item?.slug === "string" ? item.slug : "",
                        }))
                        .filter((item: BannerProductOption) => item._id && item.name)
                )

                hasNext = Boolean(data?.pagination?.hasNext)
                page += 1
            }

            setAvailableProducts(collected)
        } catch {
            toast.error("Failed to load products for banner links")
        } finally {
            setIsLoadingProductOptions(false)
        }
    }

    async function loadBrandOptions() {
        setIsLoadingBrandOptions(true)
        try {
            const collected: BannerBrandOption[] = []
            let page = 1
            let hasNext = true

            while (hasNext && page <= 20) {
                const res = await apiFetch(`/companies?page=${page}&limit=50&sort=name:asc`, { skipAuth: true })
                const data = await res.json()
                if (!res.ok) throw new Error("failed")

                const items = Array.isArray(data?.data) ? data.data : []
                collected.push(
                    ...items
                        .map((item: any) => ({
                            _id: String(item?._id || ""),
                            name: String(item?.name || ""),
                            slug: String(item?.slug || ""),
                        }))
                        .filter((item: BannerBrandOption) => item._id && item.name)
                )

                hasNext = Boolean(data?.pagination?.hasNext)
                page += 1
            }

            setAvailableBrands(collected)
        } catch {
            toast.error("Failed to load brands for banner links")
        } finally {
            setIsLoadingBrandOptions(false)
        }
    }

    async function loadCategoryOptions() {
        setIsLoadingCategoryOptions(true)
        try {
            const collected: BannerCategoryOption[] = []
            let page = 1
            let hasNext = true

            while (hasNext && page <= 20) {
                const res = await apiFetch(`/categories?page=${page}&limit=50&sort=name:asc`, { skipAuth: true })
                const data = await res.json()
                if (!res.ok) throw new Error("failed")

                const items = Array.isArray(data?.data) ? data.data : []
                collected.push(
                    ...items
                        .map((item: any) => ({
                            _id: String(item?._id || ""),
                            name: String(item?.name || ""),
                            slug: String(item?.slug || ""),
                        }))
                        .filter((item: BannerCategoryOption) => item._id && item.name)
                )

                hasNext = Boolean(data?.pagination?.hasNext)
                page += 1
            }

            setAvailableCategories(collected)
        } catch {
            toast.error("Failed to load categories for banner links")
        } finally {
            setIsLoadingCategoryOptions(false)
        }
    }

    // Hero Banners CRUD
    function addHeroBanner() {
        setHeroBanners(prev => [...prev, createEmptyBanner(prev.length)])
    }

    function updateHeroBanner(index: number, field: keyof Banner, value: string | boolean | number) {
        setHeroBanners(prev => prev.map((b, i) => i === index ? { ...b, [field]: value } : b))
    }

    function removeHeroBanner(index: number) {
        setHeroBanners(prev => prev.filter((_, i) => i !== index))
    }

    async function saveHeroBanners() {
        for (let i = 0; i < heroBanners.length; i++) {
            const banner = heroBanners[i]
            if (banner.mediaType !== 'image') {
                if (!banner.videoUrl.trim()) {
                    toast.error(`Banner ${i + 1}: add a video (upload or YouTube link) or switch back to Image`)
                    return
                }
                if (banner.mediaType === 'youtube' && !extractYoutubeId(banner.videoUrl)) {
                    toast.error(`Banner ${i + 1}: YouTube link looks invalid`)
                    return
                }
                if (!banner.imageUrl.trim()) {
                    toast.error(`Banner ${i + 1}: poster image is required for video banners`)
                    return
                }
            }
        }
        setIsSavingHero(true)
        try {
            const res = await apiFetch('/admin/settings', {
                method: 'PUT',
                body: JSON.stringify({ heroBanners })
            })
            if (res.ok) {
                toast.success("Hero banners saved successfully")
            } else {
                toast.error("Failed to save hero banners")
            }
        } catch {
            toast.error("Error saving hero banners")
        } finally {
            setIsSavingHero(false)
        }
    }

    // Promo Banners CRUD
    function addPromoBanner() {
        setPromoBanners(prev => [...prev, createEmptyBanner(prev.length)])
    }

    function updatePromoBanner(index: number, field: keyof Banner, value: string | boolean | number) {
        setPromoBanners(prev => prev.map((b, i) => i === index ? { ...b, [field]: value } : b))
    }

    function removePromoBanner(index: number) {
        setPromoBanners(prev => prev.filter((_, i) => i !== index))
    }

    async function savePromoBanners() {
        setIsSavingPromo(true)
        try {
            const res = await apiFetch('/admin/settings', {
                method: 'PUT',
                body: JSON.stringify({ promoBanners })
            })
            if (res.ok) {
                toast.success("Promo banners saved successfully")
            } else {
                toast.error("Failed to save promo banners")
            }
        } catch {
            toast.error("Error saving promo banners")
        } finally {
            setIsSavingPromo(false)
        }
    }

    function renderBannerCard(
        banner: Banner,
        index: number,
        type: 'hero' | 'promo',
        updateFn: (index: number, field: keyof Banner, value: string | boolean | number) => void,
        removeFn: (index: number) => void
    ) {
        const isUploading = uploadingIndex?.type === type && uploadingIndex?.index === index
        const selectedProduct = availableProducts.find((product) => product._id === banner.linkedProductId)
        // Video banners (hero only): button + link only, no title/desc overlay.
        const isVideo = type === 'hero' && banner.mediaType !== 'image'

        return (
            <div key={index} className="border border-[#333] rounded-lg p-4 space-y-4 bg-[#0D0D0D]">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex items-center gap-2 min-w-0">
                        <GripVertical className="h-4 w-4 text-[#555]" />
                        <span className="text-sm font-medium text-white">
                            Banner {index + 1}{isVideo ? (banner.mediaType === 'youtube' ? ' · Video (YouTube)' : ' · Video') : ''}
                        </span>
                    </div>
                    <div className="flex flex-wrap items-center gap-3">
                        <div className="flex items-center gap-2">
                            <span className="text-xs text-[#919191]">Active</span>
                            <Switch
                                checked={banner.isActive}
                                onCheckedChange={(val) => updateFn(index, 'isActive', val)}
                            />
                        </div>
                        <Button
                            variant="ghost" size="icon"
                            className="h-8 w-8 text-red-400 hover:text-red-300 hover:bg-red-900/20"
                            onClick={() => removeFn(index)}
                        >
                            <Trash2 className="h-4 w-4" />
                        </Button>
                    </div>
                </div>

                <div className="flex flex-col gap-4 md:flex-row">
                    {/* Media Preview */}
                    <div className="relative flex h-40 w-full items-center justify-center overflow-hidden rounded-md border border-[#333] bg-[#161616] md:h-32 md:w-48 md:flex-shrink-0">
                        {isVideo && banner.mediaType === 'video_upload' && banner.videoUrl ? (
                            <video
                                src={resolveBannerPreviewUrl(banner.videoUrl)}
                                className="w-full h-full object-cover"
                                muted
                                playsInline
                                preload="metadata"
                            />
                        ) : isVideo && banner.mediaType === 'youtube' && youtubeThumbnailUrl(banner.videoUrl) ? (
                            <img
                                src={youtubeThumbnailUrl(banner.videoUrl)}
                                alt="YouTube preview"
                                className="w-full h-full object-cover"
                                onError={(e) => {
                                    (e.target as HTMLImageElement).src = 'https://placehold.co/600x400/161616/white?text=Invalid+Video';
                                }}
                            />
                        ) : banner.imageUrl ? (
                            <img
                                src={resolveBannerPreviewUrl(banner.imageUrl)}
                                alt="Preview"
                                className="w-full h-full object-cover"
                                onError={(e) => {
                                    (e.target as HTMLImageElement).src = 'https://placehold.co/600x400/161616/white?text=Invalid+Image';
                                }}
                            />
                        ) : (
                            <div className="flex flex-col items-center gap-1 text-[#555]">
                                <ImageIcon className="h-8 w-8" />
                                <span className="text-[10px]">{isVideo ? 'No Video' : 'No Image'}</span>
                            </div>
                        )}

                        {isUploading && (
                            <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
                                <Loader2 className="h-6 w-6 animate-spin text-white" />
                            </div>
                        )}
                    </div>

                    <div className="flex-1 space-y-3 min-w-0">
                        {type === 'hero' && (
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">Media Type</label>
                                <select
                                    className="h-10 w-full rounded-md border border-[#333] bg-[#161616] px-3 text-sm text-white sm:w-64"
                                    value={banner.mediaType}
                                    onChange={(e) => updateFn(index, 'mediaType', e.target.value)}
                                >
                                    <option value="image">Image</option>
                                    <option value="video_upload">Video (upload MP4)</option>
                                    <option value="youtube">Video (YouTube link)</option>
                                </select>
                                {isVideo && (
                                    <p className="text-[10px] text-[#777] mt-1">Video banners show only a play button + link. No title, subtitle or button text.</p>
                                )}
                            </div>
                        )}
                        {!isVideo && (
                        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">Title *</label>
                                <Input
                                    className="bg-[#161616] border-[#333] text-white text-sm"
                                    placeholder="e.g. Summer Sale"
                                    value={banner.title}
                                    onChange={(e) => updateFn(index, 'title', e.target.value)}
                                />
                            </div>
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">Tag</label>
                                <Input
                                    className="bg-[#161616] border-[#333] text-white text-sm"
                                    placeholder="e.g. NEW ARRIVAL"
                                    value={banner.tag}
                                    onChange={(e) => updateFn(index, 'tag', e.target.value)}
                                />
                            </div>
                        </div>
                        )}
                        {!isVideo && (
                        <div>
                            <label className="text-xs text-[#919191] mb-1 block">Subtitle</label>
                            <Input
                                className="bg-[#161616] border-[#333] text-white text-sm"
                                placeholder="e.g. Up to 20% off on bulk orders"
                                value={banner.subtitle}
                                onChange={(e) => updateFn(index, 'subtitle', e.target.value)}
                            />
                        </div>
                        )}
                        {isVideo && banner.mediaType === 'video_upload' && (
                        <div>
                            <label className="text-xs text-[#919191] mb-1 block">Banner Video (MP4/WebM/MOV, max 25MB)</label>
                            <input
                                type="file"
                                id={`upload-video-${type}-${index}`}
                                className="hidden"
                                accept="video/mp4,video/webm,video/quicktime"
                                onChange={(e) => handleBannerVideoUpload(e, type, index)}
                            />
                            <Button
                                type="button"
                                variant="outline"
                                className="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] flex items-center justify-center gap-2 h-10"
                                onClick={() => document.getElementById(`upload-video-${type}-${index}`)?.click()}
                                disabled={isUploading}
                            >
                                {isUploading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
                                <span className="text-sm">
                                    {banner.videoUrl ? "Change Video" : "Upload Video"}
                                </span>
                            </Button>
                            {banner.videoUrl && (
                                <p className="text-[10px] text-[#555] mt-1 break-all">{banner.videoUrl}</p>
                            )}
                        </div>
                        )}
                        {isVideo && banner.mediaType === 'youtube' && (
                        <div>
                            <label className="text-xs text-[#919191] mb-1 block">YouTube Link</label>
                            <Input
                                className="bg-[#161616] border-[#333] text-white text-sm"
                                placeholder="e.g. https://www.youtube.com/watch?v=..."
                                value={banner.videoUrl}
                                onChange={(e) => updateFn(index, 'videoUrl', e.target.value)}
                            />
                            {banner.videoUrl && !youtubeThumbnailUrl(banner.videoUrl) && (
                                <p className="text-[10px] text-red-400 mt-1">That YouTube link looks invalid.</p>
                            )}
                        </div>
                        )}
                        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">{isVideo ? 'Poster Image (required)' : 'Banner Image'}</label>
                                <input
                                    type="file"
                                    id={`upload-${type}-${index}`}
                                    className="hidden"
                                    accept="image/*"
                                    onChange={(e) => handleBannerUpload(e, type, index)}
                                />
                                <Button
                                    type="button"
                                    variant="outline"
                                    className="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] flex items-center justify-center gap-2 h-10"
                                    onClick={() => document.getElementById(`upload-${type}-${index}`)?.click()}
                                    disabled={isUploading}
                                >
                                    {isUploading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
                                    <span className="text-sm">
                                        {banner.imageUrl ? "Change Image" : "Upload Image"}
                                    </span>
                                </Button>
                                {banner.imageUrl && (
                                    <p className="text-[10px] text-[#555] mt-1 break-all">{banner.imageUrl}</p>
                                )}
                            </div>
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">Link Type</label>
                                <div className="space-y-2">
                                    <select
                                        className="h-10 w-full rounded-md border border-[#333] bg-[#161616] px-3 text-sm text-white"
                                        value={banner.linkType}
                                        onChange={(e) => {
                                            const nextType = e.target.value as BannerLinkType
                                            updateFn(index, 'linkType', nextType)
                                            if (nextType === 'product') {
                                                updateFn(index, 'linkUrl', buildProductLink(banner.linkedProductId))
                                            } else if (nextType === 'brand') {
                                                updateFn(index, 'linkUrl', buildBrandLink(banner.linkedBrandId))
                                            } else if (nextType === 'category') {
                                                updateFn(index, 'linkUrl', buildCategoryLink(banner.linkedCategoryId))
                                            }
                                        }}
                                    >
                                        <option value="product">Link Product</option>
                                        <option value="brand">Link Brand</option>
                                        <option value="category">Link Category</option>
                                    </select>

                                    {banner.linkType === 'product' ? (
                                        <div className="space-y-2">
                                            <select
                                                className="h-10 w-full rounded-md border border-[#333] bg-[#161616] px-3 text-sm text-white"
                                                value={banner.linkedProductId}
                                                onChange={(e) => {
                                                    const nextProductId = e.target.value
                                                    updateFn(index, 'linkedProductId', nextProductId)
                                                    updateFn(index, 'linkUrl', buildProductLink(nextProductId))
                                                }}
                                                disabled={isLoadingProductOptions}
                                            >
                                                <option value="">{isLoadingProductOptions ? "Loading products..." : "Select product to link"}</option>
                                                {availableProducts.map((product) => (
                                                    <option key={product._id} value={product._id}>
                                                        {product.name}{product.category ? ` (${product.category})` : ""}
                                                    </option>
                                                ))}
                                            </select>
                                            <p className="text-[10px] text-[#777]">
                                                {selectedProduct
                                                    ? `Product link: ${buildProductLink(selectedProduct._id)}`
                                                    : "The banner will automatically use the selected product link."}
                                            </p>
                                        </div>
                                    ) : banner.linkType === 'brand' ? (
                                        <div className="space-y-2">
                                            <select
                                                className="h-10 w-full rounded-md border border-[#333] bg-[#161616] px-3 text-sm text-white"
                                                value={banner.linkedBrandId}
                                                onChange={(e) => {
                                                    const nextBrandId = e.target.value
                                                    updateFn(index, 'linkedBrandId', nextBrandId)
                                                    updateFn(index, 'linkUrl', buildBrandLink(nextBrandId))
                                                }}
                                                disabled={isLoadingBrandOptions}
                                            >
                                                <option value="">{isLoadingBrandOptions ? "Loading brands..." : "Select brand to link"}</option>
                                                {availableBrands.map((brand) => (
                                                    <option key={brand._id} value={brand._id}>
                                                        {brand.name}
                                                    </option>
                                                ))}
                                            </select>
                                            <p className="text-[10px] text-[#777]">
                                                {availableBrands.find(b => b._id === banner.linkedBrandId)
                                                    ? `Brand link: ${buildBrandLink(banner.linkedBrandId)}`
                                                    : "The banner will automatically use the selected brand link."}
                                            </p>
                                        </div>
                                    ) : banner.linkType === 'category' ? (
                                        <div className="space-y-2">
                                            <select
                                                className="h-10 w-full rounded-md border border-[#333] bg-[#161616] px-3 text-sm text-white"
                                                value={banner.linkedCategoryId}
                                                onChange={(e) => {
                                                    const nextCategoryId = e.target.value
                                                    updateFn(index, 'linkedCategoryId', nextCategoryId)
                                                    updateFn(index, 'linkUrl', buildCategoryLink(nextCategoryId))
                                                }}
                                                disabled={isLoadingCategoryOptions}
                                            >
                                                <option value="">{isLoadingCategoryOptions ? "Loading categories..." : "Select category to link"}</option>
                                                {availableCategories.map((category) => (
                                                    <option key={category._id} value={category._id}>
                                                        {category.name}
                                                    </option>
                                                ))}
                                            </select>
                                            <p className="text-[10px] text-[#777]">
                                                {availableCategories.find(c => c._id === banner.linkedCategoryId)
                                                    ? `Category link: ${buildCategoryLink(banner.linkedCategoryId)}`
                                                    : "The banner will automatically use the selected category link."}
                                            </p>
                                        </div>
                                    ) : (
                                        <div className="space-y-2">
                                            <p className="text-[10px] text-[#777]">Select a link type above to configure the banner destination.</p>
                                        </div>
                                    )}
                                </div>
                            </div>
                        </div>

                        {/* Button and Icon Customization (image banners only) */}
                        {!isVideo && (
                        <div className="grid grid-cols-1 gap-3 pt-2 border-t border-[#333] sm:grid-cols-2">
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">Button Text</label>
                                <div className="space-y-2">
                                    <Input
                                        className="bg-[#161616] border-[#333] text-white text-sm"
                                        placeholder="e.g. Shop Now"
                                        value={banner.buttonText}
                                        onChange={(e) => updateFn(index, 'buttonText', e.target.value)}
                                        list={`suggestions-${type}-${index}`}
                                    />
                                    <datalist id={`suggestions-${type}-${index}`}>
                                        {BUTTON_TEXT_SUGGESTIONS.map(s => <option key={s} value={s} />)}
                                    </datalist>
                                    <div className="flex flex-wrap gap-1">
                                        {BUTTON_TEXT_SUGGESTIONS.map(suggestion => (
                                            <button
                                                key={suggestion}
                                                type="button"
                                                onClick={() => updateFn(index, 'buttonText', suggestion)}
                                                className="text-[10px] px-2 py-1 rounded bg-[#333] text-white hover:bg-[#444] transition-colors"
                                            >
                                                {suggestion}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                            </div>
                            <div>
                                <label className="text-xs text-[#919191] mb-1 block">Button Icon</label>
                                <BannerIconPicker
                                    value={banner.buttonIcon}
                                    onSelect={(val) => updateFn(index, 'buttonIcon', val)}
                                />
                                <p className="text-[10px] text-[#555] mt-1">Select an icon for the button. Only top 4 suggested by default.</p>
                            </div>
                        </div>
                        )}
                    </div>
                </div>
            </div>
        )
    }

    if (isLoading) {
        return (
            <div className="flex justify-center p-8">
                <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
            </div>
        )
    }

    return (
        <div className="flex flex-col gap-6 max-w-4xl">
            <div>
                <h1 className="text-3xl font-bold text-white">Banner Management</h1>
                <p className="text-[#919191] mt-1">Manage promotional banners shown on the app home screen</p>
            </div>

            <Tabs defaultValue="hero" className="w-full">
                <TabsList className="grid w-full grid-cols-1 bg-[#161616] border border-[#333] sm:grid-cols-2">
                    <TabsTrigger value="hero" className="data-[state=active]:bg-[#333] data-[state=active]:text-white text-[#919191]">
                        Top Banners (Hero)
                    </TabsTrigger>
                    <TabsTrigger value="promo" className="data-[state=active]:bg-[#333] data-[state=active]:text-white text-[#919191]">
                        Bottom Banners (Promo)
                    </TabsTrigger>
                </TabsList>

                <TabsContent value="hero" className="mt-4">
                    <Card className="bg-[#161616] border-[#333]">
                        <CardHeader>
                            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                                <div>
                                    <CardTitle className="text-white flex items-center gap-2">
                                        <ImageIcon className="h-5 w-5" /> Top Banners
                                    </CardTitle>
                                    <CardDescription className="text-[#919191]">Main carousel at the top of the home screen</CardDescription>
                                </div>
                                <Button onClick={addHeroBanner} variant="outline" size="sm" className="w-full border-[#333] text-white hover:bg-[#222] sm:w-auto">
                                    <Plus className="h-4 w-4 mr-1" /> Add Banner
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {heroBanners.length === 0 ? (
                                <div className="text-center py-8 text-[#919191]">
                                    <ImageIcon className="h-12 w-12 mx-auto mb-3 opacity-40" />
                                    <p className="text-sm">No hero banners yet. Add your first banner.</p>
                                </div>
                            ) : (
                                heroBanners.map((banner, index) =>
                                    renderBannerCard(banner, index, 'hero', updateHeroBanner, removeHeroBanner)
                                )
                            )}
                            {heroBanners.length > 0 && (
                                <Button onClick={saveHeroBanners} disabled={isSavingHero} className="w-full">
                                    {isSavingHero && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                                    <Save className="mr-2 h-4 w-4" /> Save Hero Banners
                                </Button>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>

                <TabsContent value="promo" className="mt-4">
                    <Card className="bg-[#161616] border-[#333]">
                        <CardHeader>
                            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                                <div>
                                    <CardTitle className="text-white flex items-center gap-2">
                                        <ImageIcon className="h-5 w-5" /> Bottom Banners
                                    </CardTitle>
                                    <CardDescription className="text-[#919191]">Promotional carousel displayed just above the "Why Buy From Us" section</CardDescription>
                                </div>
                                <Button onClick={addPromoBanner} variant="outline" size="sm" className="w-full border-[#333] text-white hover:bg-[#222] sm:w-auto">
                                    <Plus className="h-4 w-4 mr-1" /> Add Banner
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {promoBanners.length === 0 ? (
                                <div className="text-center py-8 text-[#919191]">
                                    <ImageIcon className="h-12 w-12 mx-auto mb-3 opacity-40" />
                                    <p className="text-sm">No promo banners yet. Add your first banner.</p>
                                </div>
                            ) : (
                                promoBanners.map((banner, index) =>
                                    renderBannerCard(banner, index, 'promo', updatePromoBanner, removePromoBanner)
                                )
                            )}
                            {promoBanners.length > 0 && (
                                <Button onClick={savePromoBanners} disabled={isSavingPromo} className="w-full">
                                    {isSavingPromo && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                                    <Save className="mr-2 h-4 w-4" /> Save Promo Banners
                                </Button>
                            )}
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>
        </div>
    )
}
