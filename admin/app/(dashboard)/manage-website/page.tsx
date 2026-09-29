"use client"

import Link from "next/link"
import { type ComponentType, useEffect, useMemo, useState } from "react"
import { useSearchParams } from "next/navigation"
import { apiFetch, buildApiUrl } from "@/lib/api"
import { toast } from "sonner"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { Checkbox } from "@/components/ui/checkbox"
import { Loader2, Plus, Save, Trash2, Upload, Globe, ChevronDown, ChevronRight, BadgeCheck, RefreshCcw, Package, Headphones, ShieldCheck, CircleDollarSign, Truck, Wrench, Pencil } from "@/components/hugeicons"

type WebsiteCategoryProduct = {
    productId: string
    name: string
    slug: string
    category: string
    shortDescription: string
    description: string
    sku: string
    mrp: number
    retailPrice: number
    wholesalePrice: number
    stock: number
    priceUnit: string
    packing: string
    status: string
    image: string
    images: string[]
    order: number
}
type WebsiteCategory = { name: string; description: string; image: string; products: string[]; productDetails: WebsiteCategoryProduct[]; isActive: boolean; order: number }
type WebsiteFeaturedProduct = { name: string; price: string; image: string; badge: string; specs: string[]; shortDescription: string; isActive: boolean; order: number }
type WebsiteHeroCard = { image: string; order: number }
type LabelSourceType = "image" | "icon"
type WebsiteLabel = { id: string; title: string; sourceType: LabelSourceType; image: string; icon: string; isActive: boolean; order: number }
type SectionConfig = { eyebrow: string; title: string; description?: string; sideText?: string; buttonText: string }
type AdminProductImage = { url: string; isPrimary?: boolean; order?: number }
type AdminProductOption = {
    _id: string
    name: string
    slug?: string
    category?: string
    shortDescription?: string
    description?: string
    sku?: string
    mrp?: number
    retailPrice?: number
    wholesalePrice?: number
    stock?: number
    priceUnit?: string
    packing?: string
    status?: string
    images?: AdminProductImage[]
}
type WebsiteCatalogBrand = { _id: string; name: string; slug: string; showOnWebsite?: boolean; isActive?: boolean; productCount?: number }
type WebsiteCatalogCategory = { _id: string; name: string; slug: string; showOnWebsite?: boolean; isActive?: boolean; productCount?: number; company?: { _id: string; name: string; slug: string } }
type WebsiteCatalogProduct = { _id: string; name: string; slug: string; sku?: string; showOnWebsite?: boolean; status?: string; stock?: number; company?: { _id: string; name: string; slug: string }; categoryRef?: { _id: string; name: string; slug: string } }
type WebsiteCatalogType = "brand" | "category" | "product"
type CatalogTreeCategory = WebsiteCatalogCategory & { products: WebsiteCatalogProduct[] }
type CatalogTreeBrand = WebsiteCatalogBrand & { categories: CatalogTreeCategory[]; uncategorizedProducts: WebsiteCatalogProduct[] }

const DEFAULT_HERO_CARD_IMAGES = ["/images/Banner/1.jpg", "/images/Banner/2.jpg", "/images/Banner/3.jpg", "/images/Banner/4.jpg", "/images/Banner/5.jpg"]
const HERO_CARD_PAGE_LABELS = ["Home", "About Us", "Products", "Dealership", "Contact / Other Pages"]
const defaultHeroCards = (): WebsiteHeroCard[] => DEFAULT_HERO_CARD_IMAGES.map((image, order) => ({ image, order }))
const normalizeList = (values: string[]) => values.map((v) => v.trim()).filter(Boolean)
const toNumber = (value: unknown): number => {
    const num = Number(value)
    return Number.isFinite(num) ? num : 0
}
const createEmptyCategoryProduct = (categoryName = ""): WebsiteCategoryProduct => ({
    productId: "",
    name: "",
    slug: "",
    category: categoryName,
    shortDescription: "",
    description: "",
    sku: "",
    mrp: 0,
    retailPrice: 0,
    wholesalePrice: 0,
    stock: 0,
    priceUnit: "",
    packing: "",
    status: "active",
    image: "",
    images: [],
    order: 0,
})
const normalizeCategoryProduct = (value: any, order: number): WebsiteCategoryProduct => {
    if (typeof value === "string") {
        const name = value.trim()
        return {
            productId: "",
            name,
            slug: "",
            category: "",
            shortDescription: "",
            description: "",
            sku: "",
            mrp: 0,
            retailPrice: 0,
            wholesalePrice: 0,
            stock: 0,
            priceUnit: "",
            packing: "",
            status: "",
            image: "",
            images: [],
            order,
        }
    }

    const images = Array.isArray(value?.images) ? value.images.map((image: any) => String(image || "")).filter(Boolean) : []
    return {
        productId: String(value?.productId || value?._id || ""),
        name: String(value?.name || "").trim(),
        slug: String(value?.slug || ""),
        category: String(value?.category || ""),
        shortDescription: String(value?.shortDescription || ""),
        description: String(value?.description || ""),
        sku: String(value?.sku || ""),
        mrp: toNumber(value?.mrp),
        retailPrice: toNumber(value?.retailPrice),
        wholesalePrice: toNumber(value?.wholesalePrice),
        stock: toNumber(value?.stock),
        priceUnit: String(value?.priceUnit || ""),
        packing: String(value?.packing || ""),
        status: String(value?.status || ""),
        image: String(value?.image || images[0] || ""),
        images,
        order: Number.isFinite(value?.order) ? value.order : order,
    }
}
const normalizeCategoryProductList = (values: any[]): WebsiteCategoryProduct[] => {
    if (!Array.isArray(values)) return []
    return values
        .map((value, index) => normalizeCategoryProduct(value, index))
        .filter((product) => product.name)
}
const getPrimaryProductImage = (product: AdminProductOption): string => {
    const images = Array.isArray(product.images) ? product.images : []
    const sorted = [...images].sort((a, b) => (a?.order || 0) - (b?.order || 0))
    const primary = sorted.find((image) => image?.isPrimary) || sorted[0]
    return primary?.url || ""
}
const normalizeAdminProductOption = (item: any): AdminProductOption => ({
    _id: String(item?._id || ""),
    name: String(item?.name || ""),
    slug: String(item?.slug || ""),
    category: typeof item?.category === "string" ? item.category : "",
    shortDescription: String(item?.shortDescription || ""),
    description: String(item?.description || ""),
    sku: String(item?.sku || ""),
    mrp: toNumber(item?.mrp),
    retailPrice: toNumber(item?.retailPrice),
    wholesalePrice: toNumber(item?.wholesalePrice),
    stock: toNumber(item?.stock),
    priceUnit: String(item?.priceUnit || ""),
    packing: String(item?.packing || ""),
    status: String(item?.status || ""),
    images: Array.isArray(item?.images) ? item.images.map((image: any) => ({
        url: String(image?.url || ""),
        isPrimary: Boolean(image?.isPrimary),
        order: toNumber(image?.order),
    })).filter((image: AdminProductImage) => image.url) : [],
})
const mapAdminProductToWebsiteProduct = (product: AdminProductOption, order: number): WebsiteCategoryProduct => {
    const image = getPrimaryProductImage(product)
    const images = Array.isArray(product.images) ? product.images.map((img) => String(img?.url || "")).filter(Boolean) : (image ? [image] : [])
    return {
        productId: product._id,
        name: product.name,
        slug: String(product.slug || ""),
        category: String(product.category || ""),
        shortDescription: String(product.shortDescription || ""),
        description: String(product.description || ""),
        sku: String(product.sku || ""),
        mrp: toNumber(product.mrp),
        retailPrice: toNumber(product.retailPrice),
        wholesalePrice: toNumber(product.wholesalePrice),
        stock: toNumber(product.stock),
        priceUnit: String(product.priceUnit || ""),
        packing: String(product.packing || ""),
        status: String(product.status || ""),
        image,
        images,
        order,
    }
}
const getCategoryProducts = (category: WebsiteCategory): WebsiteCategoryProduct[] => {
    const fromDetails = normalizeCategoryProductList(category.productDetails || [])
    if (fromDetails.length > 0) return fromDetails
    return normalizeList(category.products || []).map((name, index) => normalizeCategoryProduct(name, index))
}
const getCategoryProductNames = (category: WebsiteCategory): string[] => normalizeList(getCategoryProducts(category).map((product) => product.name))
const hasDraftProductContent = (product?: WebsiteCategoryProduct | null): boolean => {
    if (!product) return false
    return Boolean(product.name?.trim() || product.shortDescription?.trim() || product.image?.trim() || product.sku?.trim())
}
const categoryPreviewFallback = "https://placehold.co/160x110/0f1115/8a93a3?text=Category"
const productPreviewFallback = "https://placehold.co/120x120/0f1115/8a93a3?text=Product"
const defaultCategoriesSection: SectionConfig = {
    eyebrow: "PRODUCT CATEGORIES",
    title: "The Heart of Modern Farming",
    description: "Our diverse range of agriculture and industrial machines stands at the core of modern farming practices. Each piece of equipment is designed with utmost precision.",
    buttonText: "View All products",
}
const defaultFeaturedSection: SectionConfig = {
    eyebrow: "PRECISION ENGINEERING",
    title: "Our Popular Product",
    sideText: "Reliable agricultural products engineered for durability, performance, and strong field results.",
    buttonText: "Get Quote",
}
const ICON_OPTIONS = [
    { value: "refresh", label: "Return", Icon: RefreshCcw },
    { value: "badge", label: "Quality", Icon: BadgeCheck },
    { value: "package", label: "Delivery", Icon: Package },
    { value: "support", label: "Support", Icon: Headphones },
    { value: "shield", label: "Protection", Icon: ShieldCheck },
    { value: "value", label: "Value", Icon: CircleDollarSign },
    { value: "truck", label: "Shipping", Icon: Truck },
    { value: "service", label: "Service", Icon: Wrench },
] as const
const iconMap = Object.fromEntries(ICON_OPTIONS.map((item) => [item.value, item.Icon])) as Record<string, ComponentType<{ className?: string }>>
const createEmptyLabel = (order = 0): WebsiteLabel => ({
    id: "",
    title: "",
    sourceType: "icon",
    image: "",
    icon: ICON_OPTIONS[0].value,
    isActive: true,
    order,
})
const normalizeLabel = (value: any, order: number): WebsiteLabel => {
    const icon = String(value?.icon || ICON_OPTIONS[0].value).trim()
    const sourceType: LabelSourceType = value?.sourceType === "image" ? "image" : "icon"
    return {
        id: String(value?.id || "").trim(),
        title: String(value?.title || "").trim(),
        sourceType,
        image: String(value?.image || "").trim(),
        icon: iconMap[icon] ? icon : ICON_OPTIONS[0].value,
        isActive: value?.isActive !== false,
        order: Number.isFinite(value?.order) ? value.order : order,
    }
}
const hasLabelVisual = (label: WebsiteLabel) => label.sourceType === "image" ? Boolean(label.image.trim()) : Boolean(label.icon.trim())

export default function ManageWebsitePage() {
    const searchParams = useSearchParams()
    const requestedTab = searchParams.get("tab")
    const initialTab = requestedTab === "labels" || requestedTab === "categories" || requestedTab === "featured" || requestedTab === "hero" || requestedTab === "catalog"
        ? requestedTab
        : "hero"
    const [isLoading, setIsLoading] = useState(true)
    const [isSavingHero, setIsSavingHero] = useState(false)
    const [isSavingCategories, setIsSavingCategories] = useState(false)
    const [isSavingProducts, setIsSavingProducts] = useState(false)
    const [isSavingLabels, setIsSavingLabels] = useState(false)
    const [isSavingVisibility, setIsSavingVisibility] = useState(false)
    const [uploading, setUploading] = useState<string | null>(null)
    const [heroCards, setHeroCards] = useState<WebsiteHeroCard[]>(defaultHeroCards())
    const [labels, setLabels] = useState<WebsiteLabel[]>([])
    const [categories, setCategories] = useState<WebsiteCategory[]>([])
    const [featuredProducts, setFeaturedProducts] = useState<WebsiteFeaturedProduct[]>([])
    const [categoriesSection, setCategoriesSection] = useState<SectionConfig>(defaultCategoriesSection)
    const [featuredSection, setFeaturedSection] = useState<SectionConfig>(defaultFeaturedSection)
    const [availableProducts, setAvailableProducts] = useState<AdminProductOption[]>([])
    const [isLoadingProductOptions, setIsLoadingProductOptions] = useState(false)
    const [refreshingProductKey, setRefreshingProductKey] = useState<string | null>(null)
    const [categorySelectedProductIds, setCategorySelectedProductIds] = useState<Record<number, string>>({})
    const [categoryDraftProducts, setCategoryDraftProducts] = useState<Record<number, WebsiteCategoryProduct>>({})
    const [expandedCategoryIndex, setExpandedCategoryIndex] = useState<number | null>(null)
    const [expandedProductKey, setExpandedProductKey] = useState<string | null>(null)
    const [draftLabel, setDraftLabel] = useState<WebsiteLabel>(createEmptyLabel())
    const [editingLabelIndex, setEditingLabelIndex] = useState<number | null>(null)
    const [activeTab, setActiveTab] = useState<"hero" | "labels" | "categories" | "featured" | "catalog">(initialTab)
    const [catalogBrands, setCatalogBrands] = useState<WebsiteCatalogBrand[]>([])
    const [catalogCategories, setCatalogCategories] = useState<WebsiteCatalogCategory[]>([])
    const [catalogProducts, setCatalogProducts] = useState<WebsiteCatalogProduct[]>([])
    const [hiddenCatalogItems, setHiddenCatalogItems] = useState<Record<WebsiteCatalogType, string[]>>({ brand: [], category: [], product: [] })
    const [catalogSearch, setCatalogSearch] = useState("")
    const [expandedCatalogBrands, setExpandedCatalogBrands] = useState<string[]>([])
    const [expandedCatalogCategories, setExpandedCatalogCategories] = useState<string[]>([])

    const uploadUrl = useMemo(() => buildApiUrl("/upload/image?folder=website"), [])
    const websiteBaseUrl = useMemo(() => {
        const raw = process.env.NEXT_PUBLIC_WEBSITE_BASE_URL || "https://demo.tradehub.example"
        return raw.replace(/\/+$/, "")
    }, [])
    const catalogTree = useMemo<CatalogTreeBrand[]>(() => {
        return catalogBrands.map((brand) => {
            const categories = catalogCategories
                .filter((category) => category.company?._id === brand._id)
                .map((category) => ({
                    ...category,
                    products: catalogProducts.filter((product) => product.company?._id === brand._id && product.categoryRef?._id === category._id),
                }))
            const categorizedProductIds = new Set(categories.flatMap((category) => category.products.map((product) => product._id)))
            return {
                ...brand,
                categories,
                uncategorizedProducts: catalogProducts.filter((product) => product.company?._id === brand._id && !categorizedProductIds.has(product._id)),
            }
        })
    }, [catalogBrands, catalogCategories, catalogProducts])

    const filteredCatalogTree = useMemo<CatalogTreeBrand[]>(() => {
        const search = catalogSearch.trim().toLowerCase()
        if (!search) return catalogTree

        return catalogTree
            .map((brand) => {
                const brandMatches = `${brand.name} ${brand.slug}`.toLowerCase().includes(search)
                const categories = brand.categories
                    .map((category) => {
                        const categoryMatches = `${category.name} ${category.slug}`.toLowerCase().includes(search)
                        const products = category.products.filter((product) => (
                            categoryMatches
                            || brandMatches
                            || `${product.name} ${product.sku || ""} ${product.slug}`.toLowerCase().includes(search)
                        ))
                        return categoryMatches || brandMatches || products.length > 0 ? { ...category, products } : null
                    })
                    .filter(Boolean) as CatalogTreeCategory[]
                const uncategorizedProducts = brand.uncategorizedProducts.filter((product) => (
                    brandMatches || `${product.name} ${product.sku || ""} ${product.slug}`.toLowerCase().includes(search)
                ))
                return brandMatches || categories.length > 0 || uncategorizedProducts.length > 0 ? { ...brand, categories, uncategorizedProducts } : null
            })
            .filter(Boolean) as CatalogTreeBrand[]
    }, [catalogTree, catalogSearch])

    function previewSrc(url: string) {
        if (!url) return ""
        if (url.startsWith("http://") || url.startsWith("https://")) return url
        if (url.startsWith("/")) return `${websiteBaseUrl}${url}`
        return url
    }

    useEffect(() => {
        loadData()
        loadProductOptions()
        loadCatalogVisibility()
    }, [])

    useEffect(() => {
        setExpandedCategoryIndex((prev) => {
            if (categories.length === 0) return null
            if (prev === null) return 0
            return Math.min(prev, categories.length - 1)
        })
    }, [categories.length])

    async function loadData() {
        try {
            const res = await apiFetch("/admin/website-settings")
            const data = await res.json()
            if (!res.ok || !data?.data) throw new Error("failed")
            const nextCategories = (data.data.productCategories || []).map((item: any, index: number) => ({
                name: item?.name || "",
                description: item?.description || "",
                image: item?.image || "",
                products: normalizeList(Array.isArray(item?.products) ? item.products : []),
                productDetails: normalizeCategoryProductList(
                    Array.isArray(item?.productDetails) ? item.productDetails : (Array.isArray(item?.products) ? item.products : [])
                ),
                isActive: item?.isActive !== false,
                order: Number.isFinite(item?.order) ? item.order : index,
            }))
            setCategories(nextCategories)
            // Ensure shortDescription exists for all products
            const loadedFeaturedProducts = (data.data.featuredProducts || []).map((p: any) => ({
                ...p,
                shortDescription: p.shortDescription || '',
                specs: Array.isArray(p.specs) ? p.specs : [],
            }))
            const loadedLabels = Array.isArray(data.data.labels)
                ? data.data.labels.map((item: any, index: number) => normalizeLabel(item, index))
                : []
            setLabels(loadedLabels)
            setFeaturedProducts(loadedFeaturedProducts)
            setCategoriesSection({ ...defaultCategoriesSection, ...(data.data.categoriesSection || {}) })
            setFeaturedSection({ ...defaultFeaturedSection, ...(data.data.featuredSection || {}) })
            const incoming = Array.isArray(data.data.heroCards) ? data.data.heroCards : []
            setHeroCards(incoming.length === 5 ? incoming.map((x: any, i: number) => ({ image: x?.image || DEFAULT_HERO_CARD_IMAGES[i], order: i })) : defaultHeroCards())
        } catch {
            toast.error("Failed to load website settings")
        } finally {
            setIsLoading(false)
        }
    }

    async function loadCatalogVisibility() {
        try {
            const [brandsRes, categoriesRes, productsRes] = await Promise.all([
                apiFetch("/admin/website-catalog/brands"),
                apiFetch("/admin/website-catalog/categories"),
                apiFetch("/admin/website-catalog/products"),
            ])
            const [brandsData, categoriesData, productsData] = await Promise.all([
                brandsRes.json(),
                categoriesRes.json(),
                productsRes.json(),
            ])
            if (!brandsRes.ok || !categoriesRes.ok || !productsRes.ok) throw new Error("Failed to load catalog visibility")
            const nextBrands = Array.isArray(brandsData?.data) ? brandsData.data : []
            const nextCategories = Array.isArray(categoriesData?.data) ? categoriesData.data : []
            const nextProducts = Array.isArray(productsData?.data) ? productsData.data : []
            setCatalogBrands(nextBrands)
            setCatalogCategories(nextCategories)
            setCatalogProducts(nextProducts)
            setHiddenCatalogItems({
                brand: nextBrands.filter((item: WebsiteCatalogBrand) => item.showOnWebsite === false).map((item: WebsiteCatalogBrand) => item._id),
                category: nextCategories.filter((item: WebsiteCatalogCategory) => item.showOnWebsite === false).map((item: WebsiteCatalogCategory) => item._id),
                product: nextProducts.filter((item: WebsiteCatalogProduct) => item.showOnWebsite === false).map((item: WebsiteCatalogProduct) => item._id),
            })
        } catch (error: any) {
            toast.error(error?.message || "Failed to load catalog visibility")
        }
    }

    function setCatalogHidden(type: WebsiteCatalogType, ids: string[], hidden: boolean, draft?: Record<WebsiteCatalogType, string[]>) {
        const target = draft || hiddenCatalogItems
        const current = new Set(target[type] || [])
        ids.forEach((id) => {
            if (hidden) current.add(id)
            else current.delete(id)
        })
        target[type] = Array.from(current)
        if (!draft) setHiddenCatalogItems({ ...target })
    }

    function isCatalogHidden(type: WebsiteCatalogType, id: string) {
        return (hiddenCatalogItems[type] || []).includes(id)
    }

    function getBrandChildIds(brand: CatalogTreeBrand) {
        return {
            categoryIds: brand.categories.map((category) => category._id),
            productIds: [
                ...brand.categories.flatMap((category) => category.products.map((product) => product._id)),
                ...brand.uncategorizedProducts.map((product) => product._id),
            ],
        }
    }

    function getBrandHiddenState(brand: CatalogTreeBrand): boolean | "indeterminate" {
        const { categoryIds, productIds } = getBrandChildIds(brand)
        const ids = [brand._id, ...categoryIds, ...productIds]
        if (ids.length === 0) return isCatalogHidden("brand", brand._id)
        const hiddenCount = ids.filter((id) => (
            id === brand._id
                ? isCatalogHidden("brand", id)
                : categoryIds.includes(id)
                    ? isCatalogHidden("category", id)
                    : isCatalogHidden("product", id)
        )).length
        if (hiddenCount === 0) return false
        if (hiddenCount === ids.length) return true
        return "indeterminate"
    }

    function getCategoryHiddenState(category: CatalogTreeCategory): boolean | "indeterminate" {
        const ids = [category._id, ...category.products.map((product) => product._id)]
        const hiddenCount = ids.filter((id) => id === category._id ? isCatalogHidden("category", id) : isCatalogHidden("product", id)).length
        if (hiddenCount === 0) return false
        if (hiddenCount === ids.length) return true
        return "indeterminate"
    }

    function toggleCatalogHidden(type: WebsiteCatalogType, id: string) {
        setHiddenCatalogItems((prev) => {
            const current = prev[type] || []
            const exists = current.includes(id)
            return { ...prev, [type]: exists ? current.filter((item) => item !== id) : [...current, id] }
        })
    }

    function toggleBrandVisibility(brand: CatalogTreeBrand) {
        const nextHidden = getBrandHiddenState(brand) !== true
        setHiddenCatalogItems((prev) => {
            const next = { brand: [...prev.brand], category: [...prev.category], product: [...prev.product] }
            const { categoryIds, productIds } = getBrandChildIds(brand)
            setCatalogHidden("brand", [brand._id], nextHidden, next)
            setCatalogHidden("category", categoryIds, nextHidden, next)
            setCatalogHidden("product", productIds, nextHidden, next)
            return next
        })
    }

    function toggleCategoryVisibility(category: CatalogTreeCategory) {
        const nextHidden = getCategoryHiddenState(category) !== true
        setHiddenCatalogItems((prev) => {
            const next = { brand: [...prev.brand], category: [...prev.category], product: [...prev.product] }
            setCatalogHidden("category", [category._id], nextHidden, next)
            setCatalogHidden("product", category.products.map((product) => product._id), nextHidden, next)
            return next
        })
    }

    function toggleCatalogBrandExpanded(id: string) {
        setExpandedCatalogBrands((prev) => prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id])
    }

    function toggleCatalogCategoryExpanded(id: string) {
        setExpandedCatalogCategories((prev) => prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id])
    }

    function getCatalogVisibilityChanges<T extends { _id: string; showOnWebsite?: boolean }>(type: WebsiteCatalogType, items: T[]) {
        const hiddenIds = hiddenCatalogItems[type] || []
        const idsToHide = items.filter((item) => item.showOnWebsite !== false && hiddenIds.includes(item._id)).map((item) => item._id)
        const idsToShow = items.filter((item) => item.showOnWebsite === false && !hiddenIds.includes(item._id)).map((item) => item._id)
        return { idsToHide, idsToShow }
    }

    async function updateCatalogVisibility() {
        const changes = {
            brand: getCatalogVisibilityChanges("brand", catalogBrands),
            category: getCatalogVisibilityChanges("category", catalogCategories),
            product: getCatalogVisibilityChanges("product", catalogProducts),
        }
        const requests = (Object.entries(changes) as Array<[WebsiteCatalogType, { idsToHide: string[]; idsToShow: string[] }]>).flatMap(([type, change]) => [
            change.idsToHide.length > 0 ? { type, ids: change.idsToHide, showOnWebsite: false } : null,
            change.idsToShow.length > 0 ? { type, ids: change.idsToShow, showOnWebsite: true } : null,
        ].filter(Boolean) as Array<{ type: WebsiteCatalogType; ids: string[]; showOnWebsite: boolean }>)

        if (requests.length === 0) {
            toast.info("No visibility changes to update")
            return
        }
        try {
            setIsSavingVisibility(true)
            for (const request of requests) {
                const res = await apiFetch("/admin/website-catalog/visibility", {
                    method: "PATCH",
                    body: JSON.stringify({ type: request.type, ids: request.ids, showOnWebsite: request.showOnWebsite }),
                })
                const data = await res.json().catch(() => null)
                if (!res.ok) throw new Error(data?.message || "Failed to update visibility")
            }

            toast.success("Website visibility updated")
            await loadCatalogVisibility()
        } catch (error: any) {
            toast.error(error?.message || "Failed to update visibility")
        } finally {
            setIsSavingVisibility(false)
        }
    }

    async function loadProductOptions() {
        setIsLoadingProductOptions(true)
        try {
            const collected: AdminProductOption[] = []
            let page = 1
            let hasNext = true

            while (hasNext && page <= 20) {
                const res = await apiFetch(`/admin/products?page=${page}&limit=50&status=active&sort=name:asc`)
                const data = await res.json()
                if (!res.ok) throw new Error("failed")

                const items = Array.isArray(data?.data) ? data.data : []
                collected.push(...items.map(normalizeAdminProductOption).filter((item: AdminProductOption) => item._id && item.name))

                hasNext = Boolean(data?.pagination?.hasNext)
                page += 1
            }

            setAvailableProducts(collected)
        } catch {
            toast.error("Failed to load product options")
        } finally {
            setIsLoadingProductOptions(false)
        }
    }

    async function persistCategories(nextCategories: WebsiteCategory[], nextCategoriesSection = categoriesSection) {
        const productCategories = nextCategories.map((category, index) => {
            const productDetails = getCategoryProducts(category).map((product, productIndex) => ({
                ...product,
                category: product.category || category.name,
                images: product.image ? [product.image] : normalizeList(product.images || []),
                order: productIndex,
            }))
            return {
                ...category,
                products: normalizeList(productDetails.map((product) => product.name)),
                productDetails,
                order: Number.isFinite(category.order) ? category.order : index,
            }
        })

        const res = await apiFetch("/admin/website-settings", {
            method: "PUT",
            body: JSON.stringify({ productCategories, categoriesSection: nextCategoriesSection }),
        })

        if (!res.ok) {
            throw new Error("failed")
        }
    }

    async function addProductToCategory(categoryIndex: number) {
        const selectedProductId = categorySelectedProductIds[categoryIndex]
        if (!selectedProductId) return

        const selectedProduct = availableProducts.find((product) => product._id === selectedProductId)
        if (!selectedProduct) {
            toast.error("Selected product not found")
            return
        }

        const currentCategory = categories[categoryIndex]
        if (!currentCategory) return

        const productDetails = getCategoryProducts(currentCategory)
        const alreadyAdded = productDetails.some((product) =>
            product.productId
                ? product.productId === selectedProduct._id
                : product.name.toLowerCase() === selectedProduct.name.toLowerCase()
        )

        if (alreadyAdded) {
            toast.error("This product is already in the category")
            return
        }

        const nextProductDetails = [...productDetails, mapAdminProductToWebsiteProduct(selectedProduct, productDetails.length)]
        const nextCategories = categories.map((category, index) =>
            index === categoryIndex
                ? {
                    ...category,
                    productDetails: nextProductDetails,
                    products: normalizeList(nextProductDetails.map((product) => product.name)),
                }
                : category
        )

        setCategories(nextCategories)
        setCategorySelectedProductIds((prev) => ({ ...prev, [categoryIndex]: "" }))
        setExpandedProductKey(null)

        try {
            setIsSavingCategories(true)
            await persistCategories(nextCategories)
            toast.success("Product added and saved")
        } catch {
            setCategories(categories)
            toast.error("Product was added locally, but saving failed")
        } finally {
            setIsSavingCategories(false)
        }
    }

    async function refreshCategoryProductFromCatalog(categoryIndex: number, productIndex: number) {
        const currentCategory = categories[categoryIndex]
        const currentProduct = currentCategory ? getCategoryProducts(currentCategory)[productIndex] : null
        const productId = currentProduct?.productId

        if (!currentCategory || !currentProduct || !productId) {
            toast.error("Only linked catalog products can be refreshed")
            return
        }

        const productKey = `${categoryIndex}-${productIndex}`
        setRefreshingProductKey(productKey)

        try {
            const res = await apiFetch(`/admin/products/${productId}`)
            const data = await res.json()
            if (!res.ok || !data?.data) throw new Error("failed")

            const catalogProduct = normalizeAdminProductOption(data.data)
            const refreshedProduct = {
                ...mapAdminProductToWebsiteProduct(catalogProduct, productIndex),
                category: catalogProduct.category || currentCategory.name,
            }

            const nextCategories = categories.map((category, index) => {
                if (index !== categoryIndex) return category
                const productDetails = getCategoryProducts(category).map((product, idx) => idx === productIndex ? refreshedProduct : product)
                return {
                    ...category,
                    productDetails,
                    products: normalizeList(productDetails.map((product) => product.name)),
                }
            })

            setCategories(nextCategories)
            await persistCategories(nextCategories)
            setAvailableProducts((prev) => prev.map((product) => product._id === catalogProduct._id ? catalogProduct : product))
            toast.success(`Refreshed ${catalogProduct.name} from catalog`)
        } catch {
            toast.error("Failed to refresh product from catalog")
        } finally {
            setRefreshingProductKey(null)
        }
    }

    function updateDraftCategoryProduct(categoryIndex: number, updates: Partial<WebsiteCategoryProduct>) {
        setCategoryDraftProducts((prev) => {
            const current = prev[categoryIndex] || createEmptyCategoryProduct(categories[categoryIndex]?.name || "")
            const next = { ...current, ...updates }
            return { ...prev, [categoryIndex]: next }
        })
    }

    async function addDraftProductToCategory(categoryIndex: number) {
        const draftProduct = categoryDraftProducts[categoryIndex] || createEmptyCategoryProduct(categories[categoryIndex]?.name || "")
        if (!draftProduct.name.trim()) {
            toast.error("Product name is required")
            return
        }

        const currentCategory = categories[categoryIndex]
        if (!currentCategory) return

        const productDetails = getCategoryProducts(currentCategory)
        const nextProduct: WebsiteCategoryProduct = {
            ...draftProduct,
            name: draftProduct.name.trim(),
            category: draftProduct.category || currentCategory.name,
            image: draftProduct.image.trim(),
            images: draftProduct.image ? [draftProduct.image.trim()] : [],
            order: productDetails.length,
        }

        const nextProductDetails = [...productDetails, nextProduct]
        const nextCategories = categories.map((category, index) =>
            index === categoryIndex
                ? {
                    ...category,
                    productDetails: nextProductDetails,
                    products: normalizeList(nextProductDetails.map((product) => product.name)),
                }
                : category
        )

        const nextDraftProduct = createEmptyCategoryProduct(categories[categoryIndex]?.name || "")
        setCategories(nextCategories)
        setCategoryDraftProducts((prev) => ({
            ...prev,
            [categoryIndex]: nextDraftProduct,
        }))
        setExpandedProductKey(null)

        try {
            setIsSavingCategories(true)
            await persistCategories(nextCategories)
            toast.success("Quick product added and saved")
        } catch {
            setCategories(categories)
            setCategoryDraftProducts((prev) => ({
                ...prev,
                [categoryIndex]: draftProduct,
            }))
            toast.error("Quick product was added locally, but saving failed")
        } finally {
            setIsSavingCategories(false)
        }
    }

    function updateCategoryProduct(categoryIndex: number, productIndex: number, updates: Partial<WebsiteCategoryProduct>) {
        setCategories((prev) => prev.map((category, index) => {
            if (index !== categoryIndex) return category
            const nextProductDetails = getCategoryProducts(category).map((product, idx) => {
                if (idx !== productIndex) return product
                const nextProduct = { ...product, ...updates }
                if (updates.image !== undefined) {
                    nextProduct.images = updates.image ? [updates.image] : []
                }
                return nextProduct
            })
            return {
                ...category,
                productDetails: nextProductDetails,
                products: normalizeList(nextProductDetails.map((product) => product.name)),
            }
        }))
    }

    async function removeCategoryProduct(categoryIndex: number, productIndex: number) {
        const nextCategories = categories.map((category, index) => {
            if (index !== categoryIndex) return category
            const nextProductDetails = getCategoryProducts(category)
                .filter((_, idx) => idx !== productIndex)
                .map((product, idx) => ({ ...product, order: idx }))
            return {
                ...category,
                productDetails: nextProductDetails,
                products: normalizeList(nextProductDetails.map((product) => product.name)),
            }
        })

        setCategories(nextCategories)
        setExpandedProductKey((prev) => prev === `${categoryIndex}-${productIndex}` ? null : prev)

        try {
            setIsSavingCategories(true)
            await persistCategories(nextCategories)
            toast.success("Product removed and saved")
        } catch {
            setCategories(categories)
            toast.error("Product was removed locally, but saving failed")
        } finally {
            setIsSavingCategories(false)
        }
    }

    function removeCategoryCard(indexToRemove: number) {
        setCategories((prev) =>
            prev
                .filter((_, index) => index !== indexToRemove)
                .map((category, index) => ({ ...category, order: index }))
        )
        setCategorySelectedProductIds((prev) => {
            const next: Record<number, string> = {}
            for (const [key, value] of Object.entries(prev)) {
                const index = Number(key)
                if (index < indexToRemove) next[index] = value
                if (index > indexToRemove) next[index - 1] = value
            }
            return next
        })
        setCategoryDraftProducts((prev) => {
            const next: Record<number, WebsiteCategoryProduct> = {}
            for (const [key, value] of Object.entries(prev)) {
                const index = Number(key)
                if (index < indexToRemove) next[index] = value
                if (index > indexToRemove) next[index - 1] = value
            }
            return next
        })
        setExpandedCategoryIndex((prev) => {
            if (prev === null) return null
            if (prev === indexToRemove) return null
            return prev > indexToRemove ? prev - 1 : prev
        })
    }

    async function uploadSingleImage(file: File) {
        const token = localStorage.getItem("accessToken")
        const formData = new FormData()
        formData.append("image", file)
        const res = await fetch(uploadUrl, { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: formData })
        const data = await res.json()
        if (!res.ok || !data?.data?.url) throw new Error("Upload failed")
        return String(data.data.url)
    }

    async function uploadLabelImage(e: React.ChangeEvent<HTMLInputElement>) {
        const file = e.target.files?.[0]
        if (!file) return
        setUploading("label-draft")
        try {
            const imageUrl = await uploadSingleImage(file)
            setDraftLabel((prev) => ({ ...prev, image: imageUrl, sourceType: "image" }))
            toast.success("Label image uploaded")
        } catch {
            toast.error("Failed to upload label image")
        } finally {
            setUploading(null)
            e.target.value = ""
        }
    }

    async function uploadImage(
        e: React.ChangeEvent<HTMLInputElement>,
        type: "hero" | "category" | "featured" | "category-product" | "draft-category-product",
        index: number,
        productIndex?: number
    ) {
        const file = e.target.files?.[0]
        if (!file) return
        const uploadKey = productIndex === undefined ? `${type}-${index}` : `${type}-${index}-${productIndex}`
        setUploading(uploadKey)
        try {
            const imageUrl = await uploadSingleImage(file)
            if (type === "hero") setHeroCards((prev) => prev.map((h, i) => i === index ? { ...h, image: imageUrl } : h))
            if (type === "category") setCategories((prev) => prev.map((c, i) => i === index ? { ...c, image: imageUrl } : c))
            if (type === "featured") setFeaturedProducts((prev) => prev.map((p, i) => i === index ? { ...p, image: imageUrl } : p))
            if (type === "category-product" && productIndex !== undefined) updateCategoryProduct(index, productIndex, { image: imageUrl, images: [imageUrl] })
            if (type === "draft-category-product") updateDraftCategoryProduct(index, { image: imageUrl, images: [imageUrl] })
            toast.success("Image uploaded")
        } catch {
            toast.error("Failed to upload image")
        } finally {
            setUploading(null)
            e.target.value = ""
        }
    }

    async function saveHeroCards() {
        setIsSavingHero(true)
        try {
            const heroCardsPayload = heroCards.map((item, index) => ({ image: item.image || DEFAULT_HERO_CARD_IMAGES[index], order: index }))
            const res = await apiFetch("/admin/website-settings", { method: "PUT", body: JSON.stringify({ heroCards: heroCardsPayload }) })
            if (!res.ok) throw new Error()
            toast.success("Hero images saved")
        } catch {
            toast.error("Failed to save hero images")
        } finally { setIsSavingHero(false) }
    }

    async function saveCategories() {
        setIsSavingCategories(true)
        try {
            await persistCategories(categories)
            setExpandedProductKey(null)
            toast.success("Website product categories saved")
        } catch {
            toast.error("Failed to save product categories")
        } finally { setIsSavingCategories(false) }
    }

    async function saveProducts() {
        setIsSavingProducts(true)
        try {
            const featuredProductsPayload = featuredProducts.map((p, i) => ({ ...p, specs: normalizeList(p.specs || []), shortDescription: p.shortDescription || '', order: Number.isFinite(p.order) ? p.order : i }))
            const res = await apiFetch("/admin/website-settings", { method: "PUT", body: JSON.stringify({ featuredProducts: featuredProductsPayload, featuredSection }) })
            if (!res.ok) throw new Error()
            toast.success("Website featured products saved")
        } catch {
            toast.error("Failed to save featured products")
        } finally { setIsSavingProducts(false) }
    }

    function resetDraftLabel() {
        setEditingLabelIndex(null)
        setDraftLabel(createEmptyLabel(labels.length))
    }

    function startEditLabel(index: number) {
        setEditingLabelIndex(index)
        setDraftLabel({ ...labels[index] })
    }

    async function persistLabels(nextLabels: WebsiteLabel[]) {
        const payload = nextLabels
            .map((item, index) => ({
                id: item.id || undefined,
                title: item.title.trim(),
                sourceType: item.sourceType,
                image: item.image.trim(),
                icon: item.icon.trim(),
                isActive: item.isActive !== false,
                order: index,
            }))
            .filter((item) => item.title && (item.sourceType === "image" ? item.image : item.icon))

        setIsSavingLabels(true)
        try {
            const res = await apiFetch("/admin/website-settings", {
                method: "PUT",
                body: JSON.stringify({ labels: payload }),
            })
            const data = await res.json().catch(() => ({}))
            if (!res.ok) throw new Error(data?.message || "Failed to save labels")

            const nextSavedLabels = Array.isArray(data?.data?.labels)
                ? data.data.labels.map((item: any, index: number) => normalizeLabel(item, index))
                : payload.map((item, index) => normalizeLabel(item, index))
            setLabels(nextSavedLabels)
            toast.success("Website labels saved")
            return true
        } catch (error: any) {
            toast.error(error?.message || "Failed to save labels")
            return false
        } finally {
            setIsSavingLabels(false)
        }
    }

    async function saveDraftLabel() {
        if (!draftLabel.title.trim()) {
            toast.error("Label title is required")
            return
        }
        if (!hasLabelVisual(draftLabel)) {
            toast.error("Choose an icon or upload an image")
            return
        }

        const targetIndex = editingLabelIndex === null ? labels.length : editingLabelIndex
        const normalizedDraft = normalizeLabel(
            {
                ...draftLabel,
                title: draftLabel.title.trim(),
                image: draftLabel.image.trim(),
                order: targetIndex,
            },
            targetIndex
        )

        const nextLabels = editingLabelIndex === null
            ? [...labels, normalizedDraft]
            : labels.map((item, index) => (index === editingLabelIndex ? normalizedDraft : item))

        const saved = await persistLabels(nextLabels)
        if (saved) {
            resetDraftLabel()
        }
    }

    async function removeLabel(index: number) {
        const nextLabels = labels.filter((_, itemIndex) => itemIndex !== index)
        const saved = await persistLabels(nextLabels)
        if (saved && editingLabelIndex === index) {
            resetDraftLabel()
        } else if (saved && editingLabelIndex !== null && editingLabelIndex > index) {
            setEditingLabelIndex(editingLabelIndex - 1)
        }
    }

    if (isLoading) return <div className="flex justify-center p-8"><Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" /></div>

    function renderVisibilityBadge(showOnWebsite?: boolean) {
        return showOnWebsite === false
            ? <span className="rounded-full bg-rose-50 px-2 py-1 text-[11px] font-semibold text-rose-700">Hidden</span>
            : <span className="rounded-full bg-indigo-50 px-2 py-1 text-[11px] font-semibold text-indigo-700">Visible</span>
    }

    function renderVisibilityStateBadge(state: boolean | "indeterminate") {
        if (state === "indeterminate") return <span className="rounded-full bg-amber-50 px-2 py-1 text-[11px] font-semibold text-amber-700">Partial</span>
        return state ? renderVisibilityBadge(false) : renderVisibilityBadge(true)
    }

    function hasCatalogVisibilityChanges() {
        return [
            ...catalogBrands.map((item) => ({ type: "brand" as WebsiteCatalogType, item })),
            ...catalogCategories.map((item) => ({ type: "category" as WebsiteCatalogType, item })),
            ...catalogProducts.map((item) => ({ type: "product" as WebsiteCatalogType, item })),
        ].some(({ type, item }) => (item.showOnWebsite === false) !== (hiddenCatalogItems[type] || []).includes(item._id))
    }

    function renderProductVisibilityRow(product: WebsiteCatalogProduct) {
        const hidden = isCatalogHidden("product", product._id)
        return (
            <label key={product._id} className="flex cursor-pointer items-center gap-3 rounded-xl border border-[#cacbdf] bg-white p-3">
                <Checkbox checked={hidden} onCheckedChange={() => toggleCatalogHidden("product", product._id)} />
                <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-slate-900">{product.name}</p>
                    <p className="truncate text-xs text-slate-500">{product.sku || product.slug} • Stock {product.stock ?? 0}</p>
                </div>
                {renderVisibilityBadge(hidden ? false : true)}
            </label>
        )
    }

    function renderCatalogVisibilityTree() {
        const hasChanges = hasCatalogVisibilityChanges()
        const totalProducts = catalogTree.reduce((sum, brand) => sum + brand.categories.reduce((inner, category) => inner + category.products.length, 0) + brand.uncategorizedProducts.length, 0)
        return (
            <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)]">
                <CardHeader>
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                        <div>
                            <CardTitle className="text-slate-900">Catalog Tree</CardTitle>
                            <CardDescription className="mt-1 text-slate-500">
                                Check a brand to hide/show the brand, all its categories, and all products. Check a category to hide/show its products.
                            </CardDescription>
                            <p className="mt-2 text-xs text-slate-500">{catalogTree.length} brands • {catalogCategories.length} categories • {totalProducts} products loaded from MongoDB</p>
                        </div>
                        <div className="flex gap-2">
                            <Button type="button" variant="outline" size="sm" disabled={isSavingVisibility || !hasChanges} onClick={updateCatalogVisibility}>
                                {isSavingVisibility ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}Update Website Visibility
                            </Button>
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="space-y-4">
                    <Input
                        value={catalogSearch}
                        onChange={(e) => setCatalogSearch(e.target.value)}
                        placeholder="Search brand, category, product, or SKU..."
                        className="max-w-2xl border-[#cacbdf] bg-white text-slate-900 placeholder:text-slate-400"
                    />
                    {filteredCatalogTree.length === 0 ? (
                        <div className="rounded-2xl border border-dashed border-[#cacbdf] bg-[#f3f3fa] p-4 text-sm text-slate-500">No matching catalog items found.</div>
                    ) : filteredCatalogTree.map((brand) => {
                        const brandExpanded = expandedCatalogBrands.includes(brand._id) || Boolean(catalogSearch.trim())
                        const brandState = getBrandHiddenState(brand)
                        const brandProductCount = brand.categories.reduce((sum, category) => sum + category.products.length, 0) + brand.uncategorizedProducts.length
                        return (
                            <div key={brand._id} className="overflow-hidden rounded-2xl border border-[#cacbdf] bg-[#f3f3fa]">
                                <div className="flex items-center gap-3 border-b border-[#cacbdf] bg-white p-4">
                                    <Checkbox checked={brandState} onCheckedChange={() => toggleBrandVisibility(brand)} />
                                    <button type="button" onClick={() => toggleCatalogBrandExpanded(brand._id)} className="flex min-w-0 flex-1 items-center gap-2 text-left">
                                        {brandExpanded ? <ChevronDown className="h-4 w-4 text-slate-500" /> : <ChevronRight className="h-4 w-4 text-slate-500" />}
                                        <div className="min-w-0">
                                            <p className="truncate text-sm font-semibold text-slate-900">{brand.name}</p>
                                            <p className="truncate text-xs text-slate-500">{brand.categories.length} categories • {brandProductCount} products • {brand.slug}</p>
                                        </div>
                                    </button>
                                    {renderVisibilityStateBadge(brandState)}
                                </div>
                                {brandExpanded ? (
                                    <div className="space-y-3 p-3">
                                        {brand.categories.length === 0 && brand.uncategorizedProducts.length === 0 ? (
                                            <div className="rounded-xl border border-dashed border-[#cacbdf] bg-white p-3 text-sm text-slate-500">No categories or products found for this brand.</div>
                                        ) : null}
                                        {brand.categories.map((category) => {
                                            const categoryExpanded = expandedCatalogCategories.includes(category._id) || Boolean(catalogSearch.trim())
                                            const categoryState = getCategoryHiddenState(category)
                                            return (
                                                <div key={category._id} className="overflow-hidden rounded-xl border border-[#cacbdf] bg-white">
                                                    <div className="flex items-center gap-3 bg-[#f7f7fc] p-3">
                                                        <Checkbox checked={categoryState} onCheckedChange={() => toggleCategoryVisibility(category)} />
                                                        <button type="button" onClick={() => toggleCatalogCategoryExpanded(category._id)} className="flex min-w-0 flex-1 items-center gap-2 text-left">
                                                            {categoryExpanded ? <ChevronDown className="h-4 w-4 text-slate-500" /> : <ChevronRight className="h-4 w-4 text-slate-500" />}
                                                            <div className="min-w-0">
                                                                <p className="truncate text-sm font-semibold text-slate-900">{category.name}</p>
                                                                <p className="truncate text-xs text-slate-500">{category.products.length} products • {category.slug}</p>
                                                            </div>
                                                        </button>
                                                        {renderVisibilityStateBadge(categoryState)}
                                                    </div>
                                                    {categoryExpanded ? (
                                                        <div className="space-y-2 border-t border-[#cacbdf] bg-[#f3f3fa] p-3">
                                                            {category.products.length === 0 ? (
                                                                <div className="rounded-xl border border-dashed border-[#cacbdf] bg-white p-3 text-sm text-slate-500">No products found in this category.</div>
                                                            ) : category.products.map(renderProductVisibilityRow)}
                                                        </div>
                                                    ) : null}
                                                </div>
                                            )
                                        })}
                                        {brand.uncategorizedProducts.length > 0 ? (
                                            <div className="space-y-2 rounded-xl border border-[#cacbdf] bg-[#f3f3fa] p-3">
                                                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Products without category</p>
                                                {brand.uncategorizedProducts.map(renderProductVisibilityRow)}
                                            </div>
                                        ) : null}
                                    </div>
                                ) : null}
                            </div>
                        )
                    })}
                </CardContent>
            </Card>
        )
    }

    return (
        <div className="space-y-6">
            <div>
                <h1 className="flex items-center gap-3 text-3xl font-bold text-slate-900"><Globe className="h-7 w-7 text-[#818cf8]" />Manage Website</h1>
                <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-500">Each hero card controls one page banner. Admin can only update image.</p>
            </div>

            <Tabs value={activeTab} onValueChange={(value) => setActiveTab(value as "hero" | "labels" | "categories" | "featured" | "catalog")} className="w-full">
                <TabsList className="flex h-auto w-full flex-wrap items-center justify-start gap-1 border border-[#d0d1e3] bg-white/90 p-1">
                    <TabsTrigger value="hero" className="min-h-10 flex-1 basis-[150px] whitespace-nowrap px-3 text-center text-slate-500 data-[state=active]:bg-[#eaeaf6] data-[state=active]:text-slate-900">Hero Section</TabsTrigger>
                    <TabsTrigger value="labels" className="min-h-10 flex-1 basis-[110px] whitespace-nowrap px-3 text-center text-slate-500 data-[state=active]:bg-[#eaeaf6] data-[state=active]:text-slate-900">Labels</TabsTrigger>
                    <TabsTrigger value="catalog" className="min-h-10 flex-1 basis-[170px] whitespace-nowrap px-3 text-center text-slate-500 data-[state=active]:bg-[#eaeaf6] data-[state=active]:text-slate-900">Catalog Visibility</TabsTrigger>
                    <TabsTrigger value="categories" className="min-h-10 flex-1 basis-[210px] whitespace-nowrap px-3 text-center text-slate-500 data-[state=active]:bg-[#eaeaf6] data-[state=active]:text-slate-900">Category Section Text</TabsTrigger>
                    <TabsTrigger value="featured" className="min-h-10 flex-1 basis-[210px] whitespace-nowrap px-3 text-center text-slate-500 data-[state=active]:bg-[#eaeaf6] data-[state=active]:text-slate-900">Featured Section Text</TabsTrigger>
                </TabsList>

                <TabsContent value="hero" className="mt-4">
                    <div className="grid grid-cols-1 xl:grid-cols-12 gap-6 items-start">
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-8">
                            <CardHeader>
                                <CardTitle className="flex items-center gap-2 text-slate-900">
                                    <span className="inline-block w-2 h-2 rounded-full bg-[#818cf8]" />
                                    Page Hero Banners
                                </CardTitle>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                {heroCards.map((item, index) => (
                                    <div key={index} className="space-y-3 rounded-2xl border border-[#d0d1e3] bg-[#f3f3fa] p-4">
                                        <div className="flex items-center justify-between">
                                            <p className="text-sm font-semibold text-slate-900">Card {index + 1} - {HERO_CARD_PAGE_LABELS[index]}</p>
                                            <span className="rounded-full border border-[#cacbdf] bg-white px-2 py-1 text-[11px] text-slate-600">{HERO_CARD_PAGE_LABELS[index]}</span>
                                        </div>
                                        <div className="grid grid-cols-1 md:grid-cols-[1fr_170px] gap-3 items-start">
                                            <Input value={item.image} onChange={(e) => setHeroCards((prev) => prev.map((h, i) => i === index ? { ...h, image: e.target.value } : h))} className="border-[#cacbdf] bg-white text-slate-900" />
                                            <div className="h-24 overflow-hidden rounded-xl border border-[#cacbdf] bg-white">
                                                {item.image ? (
                                                    <img
                                                        src={previewSrc(item.image)}
                                                        alt={`Hero preview ${index + 1}`}
                                                        className="w-full h-full object-cover"
                                                        onError={(e) => {
                                                            (e.target as HTMLImageElement).src = `https://placehold.co/400x220/0b0f16/9ca3af?text=Hero+${index + 1}`;
                                                        }}
                                                    />
                                                ) : (
                                                    <div className="flex h-full w-full items-center justify-center text-xs text-slate-400">No image</div>
                                                )}
                                            </div>
                                        </div>
                                        <div className="flex justify-end">
                                            <input id={`hero-upload-${index}`} type="file" className="hidden" accept="image/*" onChange={(e) => uploadImage(e, "hero", index)} />
                                            <Button type="button" variant="outline" className="border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8] hover:text-slate-900" onClick={() => document.getElementById(`hero-upload-${index}`)?.click()} disabled={uploading === `hero-${index}`}>
                                                {uploading === `hero-${index}` ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <Upload className="h-4 w-4 mr-2" />}Upload Image
                                            </Button>
                                        </div>
                                    </div>
                                ))}
                                <Button onClick={saveHeroCards} disabled={isSavingHero} className="w-full bg-gradient-to-r from-[#818cf8] to-[#5d61ca] text-black hover:opacity-95">{isSavingHero ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <Save className="h-4 w-4 mr-2" />}Save Page Hero Images</Button>
                            </CardContent>
                        </Card>
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-4 xl:sticky xl:top-24">
                            <CardHeader>
                                <CardTitle className="text-lg text-slate-900">Page Banner Preview</CardTitle>
                                <CardDescription className="text-slate-500">Preview of each page-specific hero banner.</CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="space-y-3 max-h-[70vh] overflow-y-auto pr-1">
                                    {heroCards.map((item, i) => (
                                        <div key={i} className="overflow-hidden rounded-2xl border border-[#d0d1e3] bg-[#f3f3fa]">
                                            <div className="relative h-28">
                                                {item.image ? (
                                                    <img
                                                        src={previewSrc(item.image)}
                                                        alt={`Card ${i + 1}`}
                                                        className="w-full h-full object-cover"
                                                        onError={(e) => {
                                                            (e.target as HTMLImageElement).src = `https://placehold.co/600x260/0b0f16/9ca3af?text=Hero+${i + 1}`;
                                                        }}
                                                    />
                                                ) : (
                                                    <div className="flex h-full w-full items-center justify-center text-xs text-slate-400">No Image</div>
                                                )}
                                                <div className="absolute inset-0 bg-gradient-to-t from-black/70 to-transparent" />
                                                <div className="absolute top-2 left-2 text-[11px] px-2 py-1 rounded-full bg-black/60 text-white border border-white/20">{HERO_CARD_PAGE_LABELS[i]}</div>
                                            </div>
                                            <div className="p-2 flex items-center justify-between">
                                                <p className="truncate text-xs text-slate-500">Card {i + 1} - {HERO_CARD_PAGE_LABELS[i]}</p>
                                                <span className="text-[10px] font-semibold uppercase tracking-[0.16em] text-[#818cf8]">Fixed</span>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </CardContent>
                        </Card>
                    </div>
                </TabsContent>

                <TabsContent value="labels" className="mt-4">
                    <div className="grid grid-cols-1 xl:grid-cols-12 gap-6 items-start">
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-8">
                            <CardHeader>
                                <CardTitle className="text-slate-900">Product Labels</CardTitle>
                                <CardDescription className="text-slate-500">
                                    These labels come directly from the `WebsiteSettings.labels` schema and are used in product detail surfaces.
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-5">
                                <div>
                                    <label className="mb-2 block text-sm font-medium text-slate-900">Label Text</label>
                                    <Input
                                        value={draftLabel.title}
                                        onChange={(event) => setDraftLabel((prev) => ({ ...prev, title: event.target.value }))}
                                        placeholder="e.g. Verified Seller"
                                        className="border-[#cacbdf] bg-white text-slate-900"
                                    />
                                </div>

                                <div className="space-y-3">
                                    <label className="block text-sm font-medium text-slate-900">Visual Type</label>
                                    <div className="flex rounded-2xl border border-[#d0d1e3] bg-[#eaeaf6] p-1">
                                        <button
                                            type="button"
                                            className={`flex-1 rounded-xl px-4 py-2 text-sm font-medium transition-colors ${draftLabel.sourceType === "icon" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-900"}`}
                                            onClick={() => setDraftLabel((prev) => ({ ...prev, sourceType: "icon" }))}
                                        >
                                            Icon
                                        </button>
                                        <button
                                            type="button"
                                            className={`flex-1 rounded-xl px-4 py-2 text-sm font-medium transition-colors ${draftLabel.sourceType === "image" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-900"}`}
                                            onClick={() => setDraftLabel((prev) => ({ ...prev, sourceType: "image" }))}
                                        >
                                            Image
                                        </button>
                                    </div>
                                </div>

                                {draftLabel.sourceType === "image" ? (
                                    <div className="space-y-4">
                                        <div>
                                            <label className="mb-2 block text-sm font-medium text-slate-900">Image URL</label>
                                            <Input
                                                value={draftLabel.image}
                                                onChange={(event) => setDraftLabel((prev) => ({ ...prev, image: event.target.value }))}
                                                placeholder="https://example.com/label-logo.png"
                                                className="border-[#cacbdf] bg-white text-slate-900"
                                            />
                                        </div>
                                        <div className="flex flex-wrap items-center gap-3">
                                            <label className="inline-flex">
                                                <input
                                                    type="file"
                                                    accept="image/*"
                                                    className="hidden"
                                                    onChange={uploadLabelImage}
                                                    disabled={uploading === "label-draft"}
                                                />
                                                <Button
                                                    type="button"
                                                    variant="outline"
                                                    className="border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8] hover:text-slate-900"
                                                    disabled={uploading === "label-draft"}
                                                    asChild
                                                >
                                                    <span>
                                                        {uploading === "label-draft" ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Upload className="mr-2 h-4 w-4" />}
                                                        Upload Logo
                                                    </span>
                                                </Button>
                                            </label>
                                            <span className="text-xs text-slate-500">Square transparent logos work best here.</span>
                                        </div>
                                    </div>
                                ) : (
                                    <div className="space-y-3">
                                        <label className="block text-sm font-medium text-slate-900">Choose Icon</label>
                                        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-4">
                                            {ICON_OPTIONS.map((option) => {
                                                const SelectedIcon = option.Icon
                                                const isSelected = draftLabel.icon === option.value

                                                return (
                                                    <button
                                                        key={option.value}
                                                        type="button"
                                                        onClick={() => setDraftLabel((prev) => ({ ...prev, icon: option.value }))}
                                                        className={`min-h-[132px] rounded-[24px] border px-4 py-5 text-center transition-colors ${isSelected ? "is-active" : "border-[#d0d1e3] bg-white text-slate-500 hover:border-[#adaed1] hover:text-slate-900"}`}
                                                    >
                                                        <SelectedIcon className={`mx-auto mb-4 h-11 w-11 ${isSelected ? "text-[#5a5daa]" : "text-slate-400"}`} />
                                                        <div className="text-sm font-medium leading-snug">{option.label}</div>
                                                    </button>
                                                )
                                            })}
                                        </div>
                                    </div>
                                )}

                                <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
                                    {editingLabelIndex !== null && (
                                        <Button
                                            type="button"
                                            variant="outline"
                                            onClick={resetDraftLabel}
                                            className="border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8] hover:text-slate-900"
                                        >
                                            Cancel Edit
                                        </Button>
                                    )}
                                    <Button
                                        type="button"
                                        onClick={() => { void saveDraftLabel() }}
                                        className="is-active hover:bg-[#818cf8]/90"
                                        disabled={isSavingLabels}
                                    >
                                        {isSavingLabels && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                                        Save Label
                                    </Button>
                                </div>
                            </CardContent>
                        </Card>

                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-4 xl:sticky xl:top-24">
                            <CardHeader>
                                <CardTitle className="text-lg text-slate-900">Labels Preview</CardTitle>
                                <CardDescription className="text-slate-500">Saved website labels from the same schema document.</CardDescription>
                            </CardHeader>
                            <CardContent>
                                {labels.length === 0 ? (
                                    <div className="rounded-2xl border border-dashed border-[#d0d1e3] p-8 text-center text-sm text-slate-500">
                                        No labels saved yet.
                                    </div>
                                ) : (
                                    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
                                        {labels
                                            .filter((label) => label.title.trim() && hasLabelVisual(label))
                                            .map((label, index) => {
                                                const IconComponent = iconMap[label.icon] || BadgeCheck

                                                return (
                                                    <div key={`${label.title}-${index}`} className="rounded-2xl border border-[#d0d1e3] bg-[#f3f3fa] p-3">
                                                        <div className="mb-2 rounded-[16px] bg-[#eef8fb] p-3">
                                                            <div className="rounded-[12px] bg-[#dff1f4] p-3">
                                                                <div className="flex aspect-square flex-col items-center justify-center text-center">
                                                                    <div className="mb-2 flex items-center justify-center">
                                                                        {label.sourceType === "image" && label.image ? (
                                                                            <img src={label.image} alt={label.title} className="h-14 w-14 object-contain" />
                                                                        ) : (
                                                                            <IconComponent className="h-14 w-14 text-[#2d5f67]" />
                                                                        )}
                                                                    </div>
                                                                    <p className="line-clamp-2 text-xs font-medium leading-tight text-[#2d5f67]">{label.title}</p>
                                                                </div>
                                                            </div>
                                                        </div>
                                                        <div className="flex justify-end gap-1">
                                                            <Button
                                                                type="button"
                                                                variant="ghost"
                                                                size="icon"
                                                                className="h-7 w-7 text-blue-400 hover:text-blue-300"
                                                                onClick={() => startEditLabel(index)}
                                                            >
                                                                <Pencil className="h-3.5 w-3.5" />
                                                            </Button>
                                                            <Button
                                                                type="button"
                                                                variant="ghost"
                                                                size="icon"
                                                                className="h-7 w-7 text-red-400 hover:bg-red-500/10 hover:text-red-300"
                                                                onClick={() => { void removeLabel(index) }}
                                                            >
                                                                <Trash2 className="h-3.5 w-3.5" />
                                                            </Button>
                                                        </div>
                                                    </div>
                                                )
                                            })}
                                    </div>
                                )}
                            </CardContent>
                        </Card>
                    </div>
                </TabsContent>

                <TabsContent value="catalog" className="mt-4">
                    <div className="mb-4 flex items-center justify-between rounded-2xl border border-[#d0d1e3] bg-[#f3f3fa] p-4">
                        <div>
                            <h2 className="text-lg font-semibold text-slate-900">Website Catalog Visibility</h2>
                            <p className="text-sm text-slate-500">Hide brands, categories, or products from the website only. The app and admin catalog remain unchanged.</p>
                        </div>
                        <Button type="button" variant="outline" onClick={loadCatalogVisibility} disabled={isSavingVisibility}>
                            <RefreshCcw className="mr-2 h-4 w-4" />Refresh
                        </Button>
                    </div>
                    {renderCatalogVisibilityTree()}
                </TabsContent>

                <TabsContent value="categories" className="mt-4">
                    <div className="grid grid-cols-1 gap-6 xl:grid-cols-12 xl:items-start">
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-8">
                            <CardHeader>
                                <CardTitle className="text-slate-900">Category Section Text</CardTitle>
                                <CardDescription className="text-slate-500">
                                    Website category and brand cards now come from the live catalog. Edit only the section heading, description, and button text here.
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                <div className="space-y-3 rounded-lg border border-[#d0d1e3] bg-[#f3f3fa] p-4">
                                    <p className="text-sm font-semibold text-slate-900">Section Content</p>
                                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                                        <Input value={categoriesSection.eyebrow || ""} onChange={(e) => setCategoriesSection((prev) => ({ ...prev, eyebrow: e.target.value }))} placeholder="Eyebrow text" className="border-[#cacbdf] bg-white text-slate-900" />
                                        <Input value={categoriesSection.title || ""} onChange={(e) => setCategoriesSection((prev) => ({ ...prev, title: e.target.value }))} placeholder="Section title" className="border-[#cacbdf] bg-white text-slate-900" />
                                    </div>
                                    <Textarea value={categoriesSection.description || ""} onChange={(e) => setCategoriesSection((prev) => ({ ...prev, description: e.target.value }))} placeholder="Section description" className="min-h-[90px] border-[#cacbdf] bg-white text-slate-900" />
                                    <Input value={categoriesSection.buttonText || ""} onChange={(e) => setCategoriesSection((prev) => ({ ...prev, buttonText: e.target.value }))} placeholder="Card button text" className="border-[#cacbdf] bg-white text-slate-900" />
                                </div>
                                <div className="rounded-2xl border border-[#cacbdf] bg-white p-4 text-sm leading-6 text-slate-600">
                                    Cards are generated automatically from visible brands and general product categories. Use <span className="font-semibold text-slate-900">Catalog Visibility</span> to hide or show brands, categories, and products.
                                </div>
                                <Button onClick={saveCategories} disabled={isSavingCategories} className="w-full">
                                    {isSavingCategories ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <Save className="h-4 w-4 mr-2" />}
                                    Save Category Section Text
                                </Button>
                            </CardContent>
                        </Card>
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-4 xl:sticky xl:top-24">
                            <CardHeader>
                                <CardTitle className="text-lg text-slate-900">Live Preview</CardTitle>
                                <CardDescription className="text-slate-500">Preview of the section text only.</CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="rounded-2xl border border-[#d0d1e3] bg-[#f3f3fa] p-4">
                                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#ff8a32]">{categoriesSection.eyebrow || "PRODUCT CATEGORIES"}</p>
                                    <p className="mt-2 text-xl font-bold text-slate-900">{categoriesSection.title || "The Heart of Modern Farming"}</p>
                                    <p className="mt-2 text-xs leading-5 text-slate-500">{categoriesSection.description || "Section description"}</p>
                                    <button className="mt-4 rounded-lg border border-[#cacbdf] bg-white px-4 py-2 text-xs font-semibold text-slate-700">
                                        {categoriesSection.buttonText || "View Products"}
                                    </button>
                                </div>
                            </CardContent>
                        </Card>
                    </div>
                </TabsContent>

                <TabsContent value="featured" className="mt-4">
                    <div className="grid grid-cols-1 gap-6 xl:grid-cols-12 xl:items-start">
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-8">
                            <CardHeader>
                                <CardTitle className="text-slate-900">Featured Section Text</CardTitle>
                                <CardDescription className="text-slate-500">
                                    Featured product cards are randomly selected from the live catalog. Edit only the section copy here.
                                </CardDescription>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                <div className="space-y-3 rounded-lg border border-[#d0d1e3] bg-[#f3f3fa] p-4">
                                    <p className="text-sm font-semibold text-slate-900">Section Content</p>
                                    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                                        <Input value={featuredSection.eyebrow || ""} onChange={(e) => setFeaturedSection((prev) => ({ ...prev, eyebrow: e.target.value }))} placeholder="Eyebrow text" className="border-[#cacbdf] bg-white text-slate-900" />
                                        <Input value={featuredSection.title || ""} onChange={(e) => setFeaturedSection((prev) => ({ ...prev, title: e.target.value }))} placeholder="Section title" className="border-[#cacbdf] bg-white text-slate-900" />
                                    </div>
                                    <Textarea value={featuredSection.sideText || ""} onChange={(e) => setFeaturedSection((prev) => ({ ...prev, sideText: e.target.value }))} placeholder="Right side section text" className="min-h-[90px] border-[#cacbdf] bg-white text-slate-900" />
                                    <Input value={featuredSection.buttonText || ""} onChange={(e) => setFeaturedSection((prev) => ({ ...prev, buttonText: e.target.value }))} placeholder="Card button text" className="border-[#cacbdf] bg-white text-slate-900" />
                                </div>
                                <div className="rounded-2xl border border-[#cacbdf] bg-white p-4 text-sm leading-6 text-slate-600">
                                    Product cards are picked automatically from products that are visible on the website. Use <span className="font-semibold text-slate-900">Catalog Visibility</span> to control the pool.
                                </div>
                                <Button onClick={saveProducts} disabled={isSavingProducts} className="w-full">
                                    {isSavingProducts ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <Save className="h-4 w-4 mr-2" />}
                                    Save Featured Section Text
                                </Button>
                            </CardContent>
                        </Card>
                        <Card className="border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] xl:col-span-4 xl:sticky xl:top-24">
                            <CardHeader>
                                <CardTitle className="text-lg text-slate-900">Live Preview</CardTitle>
                                <CardDescription className="text-slate-500">Preview of the section text only.</CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="rounded-2xl border border-[#d0d1e3] bg-[#f3f3fa] p-4">
                                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[#ff8a32]">{featuredSection.eyebrow || "PRECISION ENGINEERING"}</p>
                                    <p className="mt-2 text-xl font-bold text-slate-900">{featuredSection.title || "Our Popular Product"}</p>
                                    <p className="mt-2 text-xs leading-5 text-slate-500">{featuredSection.sideText || "Section side description"}</p>
                                    <button className="mt-4 rounded-lg border border-[#cacbdf] bg-white px-4 py-2 text-xs font-semibold text-slate-700">
                                        {featuredSection.buttonText || "Get Quote"}
                                    </button>
                                </div>
                            </CardContent>
                        </Card>
                    </div>
                </TabsContent>

            </Tabs>
        </div>
    )
}
