"use client"

import { useState, useEffect, useCallback, useMemo, useRef } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Plus, Pencil, Trash2, FolderTree, Loader2, LayoutGrid, List, Upload, Package, Search, GripVertical } from "@/components/hugeicons"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import {
    DndContext,
    closestCenter,
    KeyboardSensor,
    PointerSensor,
    useSensor,
    useSensors,
    DragEndEvent,
} from "@dnd-kit/core"
import {
    arrayMove,
    SortableContext,
    sortableKeyboardCoordinates,
    verticalListSortingStrategy,
    rectSortingStrategy,
    useSortable,
} from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table"
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { apiFetch } from "@/lib/api"
import { toast } from "sonner"
import { DiscountBadge, DiscountFields } from "@/components/discount-fields"
import { HINDI_AUTO_NOTE, HindiNameBatchButtons, SuggestHindiButton } from "@/components/hindi-name-tools"
import {
    EMPTY_DISCOUNT_FORM,
    buildCategoryDiscountNotes,
    formatDiscountSummary,
    hasDiscountFields,
    toDiscountFormValues,
    toDiscountPayload,
    validateDiscountValues,
    type DiscountFormValues,
} from "@/lib/discount"

interface Category {
    _id: string
    name: string
    nameHindi?: string
    slug: string
    description?: string
    image?: { url?: string; publicId?: string }
    company?: { _id: string; name: string; slug: string } | string | null
    parent?: { _id: string; name: string; nameHindi?: string; slug: string } | null
    order: number
    isActive: boolean
    productCount: number
    createdAt: string
    customerDiscountPercent?: number | null
    wholesalerDiscountPercent?: number | null
}

interface Company {
    _id: string
    name: string
    slug: string
    customerDiscountPercent?: number | null
    wholesalerDiscountPercent?: number | null
}

type UploadStatus = 'idle' | 'converting' | 'uploading' | 'done'

export default function CategoriesPage() {
    const router = useRouter()
    const searchParams = useSearchParams()
    const companyFilter = searchParams?.get('company') || ''
    const [categories, setCategories] = useState<Category[]>([])
    // Drill-down navigation: null = top level, set = viewing subcategories of parent
    const [selectedParentId, setSelectedParentId] = useState<string | null>(null)
    const [scope, setScope] = useState<'parents' | 'subs' | 'all'>(() => {
        const s = searchParams?.get('scope')
        if (s === 'subcategories' || s === 'subs') return 'subs'
        if (s === 'all') return 'all'
        return 'parents'
    })
    // Inactive (retired merge leftovers) are hidden everywhere here -
    // they stay in the database but have no use in this view.
    const [companies, setCompanies] = useState<Company[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isLoadingMore, setIsLoadingMore] = useState(false)
    const categoryFetchGeneration = useRef(0)
    const [isDialogOpen, setIsDialogOpen] = useState(false)
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [editingCategory, setEditingCategory] = useState<Category | null>(null)
    const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null)
    const [viewMode, setViewMode] = useState<'list' | 'card'>('card')

    // Search & Pagination state
    const [searchQuery, setSearchQuery] = useState("")
    const [page, setPage] = useState(1)
    const [totalPages, setTotalPages] = useState(1)
    const [totalCategories, setTotalCategories] = useState(0)
    const [hasMore, setHasMore] = useState(false)
    const [loadedSearchQuery, setLoadedSearchQuery] = useState("")
    const [isReordering, setIsReordering] = useState(false)
    const reorderInFlight = useRef(false)

    // Form state
    const [name, setName] = useState("")
    const [nameHindi, setNameHindi] = useState("")
    const [description, setDescription] = useState("")
    const [imageUrl, setImageUrl] = useState("")
    const [imagePublicId, setImagePublicId] = useState("")
    const [parentId, setParentId] = useState<string>("none")
    const [companyId, setCompanyId] = useState<string>("")
    const [order, setOrder] = useState("0")
    const [isActive, setIsActive] = useState(true)
    const [discounts, setDiscounts] = useState<DiscountFormValues>(EMPTY_DISCOUNT_FORM)
    const [discountsUnavailable, setDiscountsUnavailable] = useState(false)
    const [previewImageUrl, setPreviewImageUrl] = useState("")
    const [isUploadingImage, setIsUploadingImage] = useState(false)
    const [uploadStatus, setUploadStatus] = useState<UploadStatus>('idle')

    // Subcategory management state
    const [isSubcategoryDialogOpen, setIsSubcategoryDialogOpen] = useState(false)
    const [subcategoryName, setSubcategoryName] = useState("")
    const [subcategoryNameHindi, setSubcategoryNameHindi] = useState("")
    const [subcategoryDescription, setSubcategoryDescription] = useState("")
    const [subcategoryOrder, setSubcategoryOrder] = useState("0")
    const [subcategoryImageUrl, setSubcategoryImageUrl] = useState("")
    const [subcategoryImagePublicId, setSubcategoryImagePublicId] = useState("")
    const [isUploadingSubcategoryImage, setIsUploadingSubcategoryImage] = useState(false)
    const [isSubmittingSubcategory, setIsSubmittingSubcategory] = useState(false)
    const [editingSubcategory, setEditingSubcategory] = useState<Category | null>(null)
    const [subcategoryDiscounts, setSubcategoryDiscounts] = useState<DiscountFormValues>(EMPTY_DISCOUNT_FORM)
    const [subcategoryDiscountsUnavailable, setSubcategoryDiscountsUnavailable] = useState(false)
    
    // Product assignment state
    const [isProductAssignmentOpen, setIsProductAssignmentOpen] = useState(false)
    const [selectedSubcategoryForProducts, setSelectedSubcategoryForProducts] = useState<Category | null>(null)

    useEffect(() => {
        setSelectedParentId(null)
        setCategories([])
        fetchCategories(1, true)
        fetchCompanies()
    }, [companyFilter])

    // Sync scope from sidebar link (?scope=subcategories)
    useEffect(() => {
        const s = searchParams?.get('scope')
        if (s === 'subcategories' || s === 'subs') {
            setScope('subs')
            setSelectedParentId(null)
        } else if (s === 'all') {
            setScope('all')
            setSelectedParentId(null)
        } else if (s === 'parents') {
            setScope('parents')
            setSelectedParentId(null)
        }
    }, [searchParams])

    async function fetchCompanies() {
        try {
            const res = await apiFetch('/companies?page=1&limit=500')
            if (res.ok) {
                const data = await res.json()
                setCompanies(Array.isArray(data.data) ? data.data : [])
            }
        } catch (error) {
            console.error("Failed to fetch brands:", error)
        }
    }

    function getCategoryCompanyId(category: Category) {
        return typeof category.company === 'object' && category.company
            ? category.company._id
            : String(category.company || '')
    }

    function getCompanyById(id: string | null | undefined) {
        return companies.find((company) => company._id === id) || null
    }

    function getCategoryCompanyName(category: Category) {
        if (typeof category.company === 'object' && category.company) return category.company.name
        return companies.find(company => company._id === category.company)?.name || 'Unassigned'
    }

    // ---- Hierarchy helpers: parents vs subcategories ----
    const parentCategories = useMemo(
        () => categories.filter((c) => !c.parent?._id),
        [categories]
    )
    const allSubcategories = useMemo(
        () => categories.filter((c) => !!c.parent?._id),
        [categories]
    )
    const selectedParent = useMemo(
        () => categories.find((c) => c._id === selectedParentId) || null,
        [categories, selectedParentId]
    )
    const filteredCompany = useMemo(
        () => companies.find((company) => company._id === companyFilter) || null,
        [companies, companyFilter]
    )
    const subcategoriesOfSelected = useMemo(
        () => categories.filter((c) => c.parent?._id === selectedParentId),
        [categories, selectedParentId]
    )
    const subcategoryCountByParent = useMemo(() => {
        const map = new Map<string, number>()
        for (const c of categories) {
            const pid = c.parent?._id
            if (pid) map.set(pid, (map.get(pid) || 0) + 1)
        }
        return map
    }, [categories])
    const subcategoryProductCountByParent = useMemo(() => {
        const map = new Map<string, number>()
        for (const category of categories) {
            const parentId = category.parent?._id
            if (parentId) {
                map.set(parentId, (map.get(parentId) || 0) + category.productCount)
            }
        }
        return map
    }, [categories])

    function getDisplayedProductCount(category: Category) {
        return category.productCount + (category.parent?._id
            ? 0
            : subcategoryProductCountByParent.get(category._id) || 0)
    }

    const visibleCategories = useMemo(() => {
        // Drill-down takes precedence: show subs of selected parent
        const scoped = selectedParentId
            ? subcategoriesOfSelected
            : scope === 'parents'
              ? parentCategories
              : scope === 'subs'
                ? allSubcategories
                : categories
        return scoped.filter((c) => c.isActive !== false)
    }, [selectedParentId, subcategoriesOfSelected, scope, parentCategories, allSubcategories, categories])
    const canReorder = !searchQuery.trim() && !loadedSearchQuery && !hasMore && !isReordering

    function handleCategoryClick(category: Category) {
        // Parent (no parent ref): drill into its subcategories in-place
        if (!category.parent?._id) {
            const subcategoryCount = subcategoryCountByParent.get(category._id) || 0
            if (subcategoryCount === 0 && category.productCount > 0) {
                router.push(`/categories/${category._id}/products`)
                return
            }
            setSelectedParentId(category._id)
            setScope('parents')
            return
        }
        // Subcategory: open its products
        router.push(`/categories/${category._id}/products`)
    }

    async function fetchCategories(pageNum: number = 1, reset: boolean = false, requestedSearch: string = searchQuery) {
        const requestGeneration = ++categoryFetchGeneration.current
        if (reset) {
            setIsLoading(true)
            setPage(1)
        } else {
            setIsLoadingMore(true)
        }

        try {
            const params = new URLSearchParams()
            params.append('page', pageNum.toString())
            params.append('limit', '500')
            if (requestedSearch.trim()) {
                params.append('search', requestedSearch.trim())
            }
            if (companyFilter) {
                params.append('company', companyFilter)
            }

            // Authenticated so the admin-only discount fields are included.
            const res = await apiFetch(`/categories?${params.toString()}`)
            if (requestGeneration !== categoryFetchGeneration.current) return
            if (res.ok) {
                const data = await res.json()
                const items = data.data || []
                const pagination = data.pagination || {}

                if (reset || pageNum === 1) {
                    setCategories(items)
                } else {
                    setCategories(prev => [...prev, ...items])
                }

                setTotalPages(pagination.totalPages || 1)
                setTotalCategories(pagination.total || items.length)
                setHasMore((pagination.page || 1) < (pagination.totalPages || 1))
                setLoadedSearchQuery(requestedSearch.trim())
            } else if (reset) {
                setCategories([])
            }
        } catch (error) {
            console.error("Failed to fetch categories:", error)
            toast.error("Failed to load categories")
            if (reset && requestGeneration === categoryFetchGeneration.current) {
                setCategories([])
            }
        } finally {
            if (requestGeneration === categoryFetchGeneration.current) {
                setIsLoading(false)
                setIsLoadingMore(false)
            }
        }
    }

    const handleSearch = useCallback((e: React.FormEvent) => {
        e.preventDefault()
        fetchCategories(1, true)
    }, [searchQuery, companyFilter])

    const loadMore = useCallback(() => {
        if (hasMore && !isLoadingMore) {
            const nextPage = page + 1
            setPage(nextPage)
            fetchCategories(nextPage, false)
        }
    }, [hasMore, isLoadingMore, page, searchQuery, companyFilter])

    function openCreateDialog() {
        setEditingCategory(null)
        setName("")
        setNameHindi("")
        setDescription("")
        setImageUrl("")
        setImagePublicId("")
        setParentId("none")
        setCompanyId(companyFilter || companies[0]?._id || "")
        // New categories go AFTER existing cards, not to the front.
        setOrder(String(maxCategoryOrder(parentCategories) + 1))
        setIsActive(true)
        setDiscounts(EMPTY_DISCOUNT_FORM)
        setDiscountsUnavailable(false)
        setIsDialogOpen(true)
    }

    // Highest saved order in a list - new items append after it.
    function maxCategoryOrder(list: Category[]) {
        return list.reduce((max, c) => Math.max(max, Number(c.order) || 0), 0)
    }

    function openEditDialog(category: Category) {
        setEditingCategory(category)
        setName(category.name)
        setNameHindi(category.nameHindi || "")
        setDescription(category.description || "")
        setImageUrl(category.image?.url || "")
        setImagePublicId(category.image?.publicId || "")
        setParentId(category.parent?._id || "none")
        setCompanyId(getCategoryCompanyId(category))
        setOrder(String(category.order || 0))
        setIsActive(category.isActive)
        setDiscounts(toDiscountFormValues(category))
        setDiscountsUnavailable(!hasDiscountFields(category))
        setIsDialogOpen(true)
    }

    const formatBytes = (bytes: number) => {
        if (bytes === 0) return '0 B'
        const k = 1024
        const sizes = ['B', 'KB', 'MB']
        const i = Math.floor(Math.log(bytes) / Math.log(k))
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
    }

    async function handleImageUpload(e: React.ChangeEvent<HTMLInputElement>) {
        const file = e.target.files?.[0]
        if (!file) return

        setIsUploadingImage(true)
        setUploadStatus('converting')
        const formData = new FormData()
        formData.append('image', file)

        try {
            await new Promise(r => setTimeout(r, 300))
            setUploadStatus('uploading')

            const response = await apiFetch('/upload/image?folder=categories', {
                method: 'POST',
                body: formData,
            })

            if (!response.ok) {
                const error = await response.json()
                throw new Error(error.message || 'Upload failed')
            }

            const data = await response.json()
            setUploadStatus('done')
            
            if (data.success && data.data) {
                setImageUrl(data.data.url)
                setImagePublicId(data.data.publicId)
                const orig = data.data.originalSize || 0
                const conv = data.data.convertedSize || 0
                if (orig > 0 && conv > 0) {
                    toast.success(`Image converted to WebP & uploaded! Saved ${formatBytes(orig - conv)} (${data.data.savings} smaller)`)
                } else {
                    toast.success('Image uploaded successfully')
                }
            }

            await new Promise(r => setTimeout(r, 1000))
        } catch (error: any) {
            console.error('Upload error:', error)
            toast.error(error.message || 'Failed to upload image')
        } finally {
            setIsUploadingImage(false)
            setUploadStatus('idle')
            e.target.value = ''
        }
    }

    async function handleSubmit() {
        if (!name.trim()) {
            toast.error("Category name is required")
            return
        }

        if (!companyId) {
            toast.error("Brand is required")
            return
        }
        const discountError = validateDiscountValues(discounts)
        if (discountError) {
            toast.error(discountError)
            return
        }

        setIsSubmitting(true)

        try {
            const payload: any = {
                name: name.trim(),
                company: companyId,
                nameHindi: nameHindi.trim() || undefined,
                description: description.trim() || undefined,
                image: imageUrl.trim() ? { url: imageUrl.trim(), publicId: imagePublicId || undefined } : undefined,
                parent: parentId !== "none" ? parentId : null,
                order: Number(order) || 0,
                isActive,
                ...(discountsUnavailable ? {} : toDiscountPayload(discounts)),
            }

            const endpoint = editingCategory
                ? `/categories/${editingCategory._id}`
                : "/categories"

            const res = await apiFetch(endpoint, {
                method: editingCategory ? "PUT" : "POST",
                body: JSON.stringify(payload),
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to save category")
            }

            toast.success(editingCategory ? "Category updated successfully" : "Category created successfully")
            setIsDialogOpen(false)
            fetchCategories()
        } catch (error: any) {
            toast.error(error.message || "Failed to save category")
        } finally {
            setIsSubmitting(false)
        }
    }

    async function handleAddSubcategory() {
        if (!subcategoryName.trim()) {
            toast.error("Subcategory name is required")
            return
        }

        if (!editingCategory) {
            toast.error("Please select a parent category first")
            return
        }
        const discountError = validateDiscountValues(subcategoryDiscounts)
        if (discountError) {
            toast.error(discountError)
            return
        }

        setIsSubmittingSubcategory(true)

        try {
            const payload: any = {
                name: subcategoryName.trim(),
                nameHindi: subcategoryNameHindi.trim() || undefined,
                description: subcategoryDescription.trim() || undefined,
                image: subcategoryImageUrl.trim() ? { url: subcategoryImageUrl.trim(), publicId: subcategoryImagePublicId || undefined } : undefined,
                company: editingCategory.company instanceof Object 
                    ? editingCategory.company._id 
                    : editingCategory.company,
                parent: editingCategory._id,
                order: Number(subcategoryOrder) || 0,
                isActive: true,
                ...(subcategoryDiscountsUnavailable ? {} : toDiscountPayload(subcategoryDiscounts)),
            }

            const endpoint = editingSubcategory
                ? `/categories/${editingSubcategory._id}`
                : "/categories"

            const res = await apiFetch(endpoint, {
                method: editingSubcategory ? "PUT" : "POST",
                body: JSON.stringify(payload),
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to save subcategory")
            }

            toast.success(editingSubcategory ? "Subcategory updated successfully" : "Subcategory created successfully")
            setSubcategoryName("")
            setSubcategoryNameHindi("")
            setSubcategoryDescription("")
            setSubcategoryOrder("0")
            setSubcategoryImageUrl("")
            setSubcategoryImagePublicId("")
            setEditingSubcategory(null)
            setIsSubcategoryDialogOpen(false)
            fetchCategories()
        } catch (error: any) {
            toast.error(error.message || "Failed to save subcategory")
        } finally {
            setIsSubmittingSubcategory(false)
        }
    }

    async function handleDeleteSubcategory(subcategoryId: string) {
        try {
            const res = await apiFetch(`/categories/${subcategoryId}`, {
                method: "DELETE",
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to delete subcategory")
            }

            toast.success("Subcategory deleted successfully")
            fetchCategories()
        } catch (error: any) {
            toast.error(error.message || "Failed to delete subcategory")
        }
    }

    function openEditSubcategoryDialog(subcategory: Category) {
        setEditingSubcategory(subcategory)
        setSubcategoryName(subcategory.name)
        setSubcategoryNameHindi(subcategory.nameHindi || "")
        setSubcategoryDescription(subcategory.description || "")
        setSubcategoryOrder(String(subcategory.order || 0))
        setSubcategoryImageUrl(subcategory.image?.url || "")
        setSubcategoryImagePublicId(subcategory.image?.publicId || "")
        setSubcategoryDiscounts(toDiscountFormValues(subcategory))
        setSubcategoryDiscountsUnavailable(!hasDiscountFields(subcategory))
        setIsSubcategoryDialogOpen(true)
    }

    function openAddSubcategoryDialog(parent: Category | null = editingCategory) {
        setEditingSubcategory(null)
        setSubcategoryName("")
        setSubcategoryNameHindi("")
        setSubcategoryDescription("")
        // New subcategories go after existing sibling cards.
        const siblings = parent
            ? categories.filter(c => c.parent?._id === parent._id)
            : allSubcategories
        setSubcategoryOrder(String(maxCategoryOrder(siblings) + 1))
        setSubcategoryImageUrl("")
        setSubcategoryImagePublicId("")
        setSubcategoryDiscounts(EMPTY_DISCOUNT_FORM)
        setSubcategoryDiscountsUnavailable(false)
        setIsSubcategoryDialogOpen(true)
    }

    async function handleSubcategoryImageUpload(e: React.ChangeEvent<HTMLInputElement>) {
        const file = e.target.files?.[0]
        if (!file) return

        setIsUploadingSubcategoryImage(true)
        const formData = new FormData()
        formData.append('image', file)

        try {
            const response = await apiFetch('/upload/image?folder=categories', {
                method: 'POST',
                body: formData,
            })

            if (!response.ok) {
                const error = await response.json()
                throw new Error(error.message || 'Upload failed')
            }

            const data = await response.json()
            if (data.success && data.data) {
                setSubcategoryImageUrl(data.data.url)
                setSubcategoryImagePublicId(data.data.publicId)
                toast.success('Image uploaded successfully')
            }
        } catch (error: any) {
            console.error('Upload error:', error)
            toast.error(error.message || 'Failed to upload image')
        } finally {
            setIsUploadingSubcategoryImage(false)
            e.target.value = ''
        }
    }

    async function handleDelete(id: string) {
        try {
            const res = await apiFetch(`/categories/${id}`, {
                method: "DELETE",
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to delete category")
            }

            toast.success("Category deleted successfully")
            setDeleteConfirmId(null)
            fetchCategories()
        } catch (error: any) {
            toast.error(error.message || "Failed to delete category")
        }
    }

    // Drag and Drop Reorder Handler
    // NOTE: reorder within the CURRENTLY VISIBLE scope only (parents,
    // subs, or all). Reordering the full mixed array scrambled saved
    // orders across scopes, so #N badges never matched Display Order.
    async function handleDragEnd(event: DragEndEvent) {
        if (!canReorder || reorderInFlight.current) return
        const { active, over } = event

        if (!over || active.id === over.id) return

        const visible = visibleCategories
        const oldIndex = visible.findIndex(c => c._id === active.id)
        const newIndex = visible.findIndex(c => c._id === over.id)

        if (oldIndex === -1 || newIndex === -1) return

        const moved = arrayMove(visible, oldIndex, newIndex)

        // Assign sequential order numbers starting from 1 (backend requires >= 1)
        const updates = moved.map((cat, index) => ({
            categoryId: cat._id,
            order: index + 1,
        }))

        // Optimistic update for the moved ids only
        const orderById = new Map(updates.map(u => [u.categoryId, u.order] as const))
        setCategories(prev => prev.map(cat =>
            orderById.has(cat._id) ? { ...cat, order: orderById.get(cat._id)! } : cat
        ))
        reorderInFlight.current = true
        setIsReordering(true)

        // Send to backend
        try {
            const res = await apiFetch("/categories/reorder", {
                method: "POST",
                body: JSON.stringify({ updates }),
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to reorder categories")
            }

            toast.success("Categories reordered successfully")
            fetchCategories(1, true)
        } catch (error: any) {
            console.error("Reorder error:", error)
            toast.error(error.message || "Failed to reorder categories")
            // Refresh to get correct state from backend
            fetchCategories(1, true)
        } finally {
            reorderInFlight.current = false
            setIsReordering(false)
        }
    }

    async function handleReorderSubcategories(subcategoryIds: string[]) {
        if (!editingCategory) return

        try {
            const res = await apiFetch("/categories/reorder-subcategories", {
                method: "POST",
                body: JSON.stringify({
                    parentId: editingCategory._id,
                    subcategoryIds: subcategoryIds,
                }),
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to reorder subcategories")
            }

            toast.success("Subcategories reordered successfully")
            fetchCategories()
        } catch (error: any) {
            console.error("Subcategory reorder error:", error)
            toast.error(error.message || "Failed to reorder subcategories")
        }
    }

    // Setup sensors for drag and drop
    // distance constraint: plain clicks (e.g. edit/delete buttons)
    // must not start a drag and swallow the click.
    const sensors = useSensors(
        useSensor(PointerSensor, {
            activationConstraint: { distance: 6 },
        }),
        useSensor(KeyboardSensor, {
            coordinateGetter: sortableKeyboardCoordinates,
        })
    )

    // Get parent categories for the dropdown (exclude the category being edited)
    const parentOptions = categories.filter(c => 
        (!editingCategory || c._id !== editingCategory._id) &&
        (!companyId || getCategoryCompanyId(c) === companyId)
    )

    // Draggable Table Row Component
    function DraggableTableRow({ category, index }: { category: Category; index: number }) {
        const {
            attributes,
            listeners,
            setNodeRef,
            transform,
            transition,
            isDragging,
        } = useSortable({ id: category._id, disabled: !canReorder })

        const style = {
            transform: CSS.Transform.toString(transform),
            transition,
        }

        return (
            <TableRow
                ref={setNodeRef}
                style={style}
                className={`cursor-pointer border-[#333] transition-colors ${
                    isDragging ? 'bg-[#818cf8]/10 ring-2 ring-[#818cf8]' : 'hover:bg-[#1A1A1A]'
                }`}
                onClick={() => handleCategoryClick(category)}
            >
                <TableCell
                    {...attributes}
                    {...listeners}
                    className={canReorder ? "touch-none cursor-grab text-gray-400 active:cursor-grabbing" : "text-gray-600"}
                >
                    <div className="flex items-center gap-2">
                        <GripVertical className="h-4 w-4" />
                        <span className="font-bold text-[#818cf8]">#{index + 1}</span>
                    </div>
                </TableCell>
                <TableCell>
                    {category.image?.url ? (
                        <img 
                            src={category.image.url} 
                            alt={category.name}
                            className="w-10 h-10 rounded-lg object-cover bg-[#0D0D0D]"
                        />
                    ) : (
                        <div className="w-10 h-10 rounded-lg bg-[#0D0D0D] flex items-center justify-center">
                            <FolderTree className="h-5 w-5 text-gray-500" />
                        </div>
                    )}
                </TableCell>
                <TableCell className="font-medium text-white">
                    <div>
                        <div>{category.name}</div>
                        {category.nameHindi ? (
                            <div className="text-xs font-normal text-gray-400">{category.nameHindi}</div>
                        ) : null}
                        <DiscountBadge summary={formatDiscountSummary(category)} className="mt-1" />
                    </div>
                </TableCell>
                <TableCell className="text-gray-400">
                    {getCategoryCompanyName(category)}
                </TableCell>
                <TableCell className="text-gray-400">
                    {category.slug}
                </TableCell>
                <TableCell className="text-gray-400">
                    {category.parent?.name || "—"}
                </TableCell>
                <TableCell>
                    <span className="flex items-center gap-1 text-gray-400">
                        <Package className="h-3 w-3" />
                        {getDisplayedProductCount(category)}
                    </span>
                </TableCell>
                <TableCell>
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                        category.isActive 
                            ? 'bg-green-500/20 text-green-400' 
                            : 'bg-gray-500/20 text-gray-400'
                    }`}>
                        {category.isActive ? 'Active' : 'Inactive'}
                    </span>
                </TableCell>
                <TableCell className="text-right">
                    <div className="flex justify-end gap-2" onClick={(event) => event.stopPropagation()}>
                        <Button 
                            size="icon" 
                            variant="ghost" 
                            className="h-8 w-8 text-blue-400 hover:text-blue-300"
                            onClick={() => openEditDialog(category)}
                        >
                            <Pencil className="h-4 w-4" />
                        </Button>
                        <Button 
                            size="icon" 
                            variant="ghost" 
                            className="h-8 w-8 text-red-400 hover:text-red-300 hover:bg-red-400/10"
                            onClick={() => setDeleteConfirmId(category._id)}
                        >
                            <Trash2 className="h-4 w-4" />
                        </Button>
                    </div>
                </TableCell>
            </TableRow>
        )
    }
    function DraggableCard({ category, index }: { category: Category; index: number }) {
        const {
            attributes,
            listeners,
            setNodeRef,
            transform,
            transition,
            isDragging,
        } = useSortable({ id: category._id, disabled: !canReorder })

        const style = {
            transform: CSS.Transform.toString(transform),
            transition,
        }

        return (
            <div
                ref={setNodeRef}
                style={style}
                onClick={() => !isDragging && handleCategoryClick(category)}
                title={category.isActive ? undefined : "Inactive: hidden from app & website, kept for records. Click to manage or reactivate."}
                className={`relative bg-[#161616] rounded-xl overflow-hidden transition-all cursor-pointer border border-[#333] ${
                    isDragging ? 'opacity-50 ring-2 ring-[#818cf8] shadow-lg shadow-[#818cf8]/20' : 'hover:border-[#818cf8]/50'
                } ${category.isActive ? '' : 'opacity-60'}`}
            >
                {/* Drag Handle - Top bar with card number and controls.
                    Edit/delete buttons live OUTSIDE the sortable listeners
                    so drag never swallows their clicks. */}
                <div
                    className="w-full h-12 px-4 py-0 flex items-center justify-between bg-blue-600/20 hover:bg-blue-600/30 transition-colors duration-200 border-b border-blue-500/50 group"
                >
                    <div
                        {...attributes}
                        {...listeners}
                        className={canReorder
                            ? "flex flex-1 touch-none cursor-grab items-center gap-3 active:cursor-grabbing"
                            : "flex flex-1 items-center gap-3 text-gray-600"}
                    >
                        <span className="text-white font-bold text-sm">#{index + 1}</span>
                    </div>
                    <div
                        className="flex gap-1"
                        onClick={(event) => event.stopPropagation()}
                        onPointerDown={(event) => event.stopPropagation()}
                    >
                        <Button 
                            size="icon" 
                            variant="ghost" 
                            className="h-7 w-7 text-blue-300 hover:text-blue-200 hover:bg-blue-400/20 transition-all"
                            onClick={() => openEditDialog(category)}
                        >
                            <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button 
                            size="icon" 
                            variant="ghost" 
                            className="h-7 w-7 text-red-400 hover:text-red-300 hover:bg-red-400/20 transition-all"
                            onClick={() => setDeleteConfirmId(category._id)}
                        >
                            <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                    </div>
                </div>

                <div className="p-4 space-y-3">
                    <div className="flex items-start justify-between">
                        {category.image?.url ? (
                            <img 
                                src={category.image.url} 
                                alt={category.name}
                                className="w-14 h-14 rounded-lg object-cover bg-[#0D0D0D]"
                            />
                        ) : (
                            <div className="w-14 h-14 rounded-lg bg-[#0D0D0D] flex items-center justify-center border border-[#333]">
                                <FolderTree className="h-6 w-6 text-gray-500" />
                            </div>
                        )}
                    </div>
                    <div>
                        <h3 className="font-semibold text-white text-sm leading-tight">{category.name}</h3>
                        {category.nameHindi ? (
                            <p className="text-[#818cf8] text-xs mt-0.5">{category.nameHindi}</p>
                        ) : null}
                    </div>
                    <p className="text-gray-500 text-xs">/{category.slug}</p>
                    <p className="text-[#818cf8] text-xs font-medium">{getCategoryCompanyName(category)}</p>
                    <div className="flex items-center gap-2 flex-wrap text-xs">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded-full font-medium ${
                            category.isActive 
                                ? 'bg-green-500/20 text-green-400' 
                                : 'bg-gray-500/20 text-gray-400'
                        }`}>
                            {category.isActive ? 'Active' : 'Inactive'}
                        </span>
                        {!category.isActive && (
                            <span className="text-gray-500">Hidden from app</span>
                        )}
                        <span className="flex items-center gap-1 text-gray-400">
                            <Package className="h-3 w-3" />
                            {getDisplayedProductCount(category)}
                        </span>
                        {!category.parent?._id && (
                            <span className="inline-flex items-center gap-1 rounded-full bg-blue-500/15 px-2 py-0.5 font-medium text-blue-300">
                                <FolderTree className="h-3 w-3" />
                                {subcategoryCountByParent.get(category._id) || 0} subs
                            </span>
                        )}
                        <DiscountBadge summary={formatDiscountSummary(category)} />
                    </div>
                    {category.parent?.name && (
                        <p className="text-gray-500 text-xs pt-2 border-t border-[#333]">Parent: {category.parent.name}</p>
                    )}
                    {category.description && (
                        <p className="text-gray-400 text-xs line-clamp-2 pt-2 border-t border-[#333]">{category.description}</p>
                    )}
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div className="flex min-w-0 items-center gap-3">
                    <FolderTree className="h-7 w-7 shrink-0 text-[#818cf8] sm:h-8 sm:w-8" />
                    <div>
                        <h1 className="text-2xl font-bold text-white sm:text-3xl">
                            {selectedParent
                                ? selectedParent.name
                                : scope === 'subs'
                                    ? filteredCompany ? `${filteredCompany.name} Subcategories` : 'Subcategories'
                                    : filteredCompany ? `${filteredCompany.name} Categories` : 'Categories'}
                        </h1>
                        <p className="text-gray-400 text-sm">
                            {selectedParent
                                ? `Subcategories of ${selectedParent.name} (${visibleCategories.length})`
                                : scope === 'subs'
                                    ? `(${allSubcategories.length} subcategories)`
                                    : scope === 'all'
                                        ? `(${totalCategories} total)`
                                        : `(${parentCategories.length} categories)`}
                        </p>
                        {selectedParent && (
                            <button
                                type="button"
                                onClick={() => setSelectedParentId(null)}
                                className="mt-1 text-xs text-[#818cf8] hover:underline"
                            >
                                ← Back to all categories
                            </button>
                        )}
                        {!selectedParent && companyFilter && (
                            <button
                                type="button"
                                onClick={() => router.push('/brands')}
                                className="mt-1 text-xs text-[#818cf8] hover:underline"
                            >
                                ← Back to brands
                            </button>
                        )}
                    </div>
                </div>
                <div className="flex flex-wrap items-center gap-2 sm:gap-3">
                    <HindiNameBatchButtons
                        endpoint="/categories/hindi-names/generate-missing"
                        entityLabel="categories"
                        onDone={() => fetchCategories(1, true)}
                        buttonClassName="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] sm:w-auto"
                    />
                    {/* View Toggle */}
                    <div className="flex items-center rounded-lg border border-[#333] bg-[#161616] p-1">
                        <button
                            onClick={() => setViewMode('list')}
                            className={`rounded-md p-2 transition-colors ${viewMode === 'list' ? 'is-active' : 'text-gray-400 hover:text-white'}`}
                        >
                            <List className="h-4 w-4" />
                        </button>
                        <button
                            onClick={() => setViewMode('card')}
                            className={`rounded-md p-2 transition-colors ${viewMode === 'card' ? 'is-active' : 'text-gray-400 hover:text-white'}`}
                        >
                            <LayoutGrid className="h-4 w-4" />
                        </button>
                    </div>
                    <Button 
                        onClick={openCreateDialog}
                        className="h-10 min-w-0 bg-[#818cf8] px-3 text-black hover:bg-[#818cf8]/90 sm:px-4"
                    >
                        <Plus className="mr-2 h-4 w-4 shrink-0" />
                        <span className="truncate">Add Category</span>
                    </Button>
                </div>
            </div>

            {/* Search Bar */}
            <form onSubmit={handleSearch} className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <div className="relative w-full sm:max-w-md sm:flex-1">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                    <Input
                        type="text"
                        placeholder="Search categories by name..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="pl-10 bg-[#161616] border-[#333] text-white placeholder:text-gray-500 focus-visible:ring-[#818cf8]"
                    />
                </div>
                <Button
                    type="submit"
                    variant="outline"
                    className="w-full border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] sm:w-auto"
                >
                    Search
                </Button>
                {searchQuery && (
                    <Button
                        type="button"
                        variant="ghost"
                        onClick={() => {
                            setSearchQuery("")
                            fetchCategories(1, true, "")
                        }}
                        className="w-full text-gray-400 hover:text-white sm:w-auto"
                    >
                        Clear
                    </Button>
                )}
            </form>

            {/* Scope tabs + breadcrumb */}
            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-center gap-1 rounded-lg border border-[#333] bg-[#161616] p-1 text-sm">
                    {([
                        { key: 'parents', label: `Categories (${parentCategories.filter((c) => c.isActive !== false).length})` },
                        { key: 'subs', label: `Subcategories (${allSubcategories.filter((c) => c.isActive !== false).length})` },
                        { key: 'all', label: `All (${categories.filter((c) => c.isActive !== false).length})` },
                    ] as const).map((tab) => (
                        <button
                            key={tab.key}
                            type="button"
                            onClick={() => {
                                setScope(tab.key)
                                setSelectedParentId(null)
                            }}
                            className={`rounded-md px-3 py-1.5 transition-colors ${
                                !selectedParentId && scope === tab.key
                                    ? 'bg-[#818cf8] font-semibold text-black'
                                    : 'text-gray-400 hover:text-white'
                            }`}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>
                {selectedParent ? (
                    <div className="flex items-center gap-2 text-sm text-gray-400">
                        <span>Categories</span>
                        <span>/</span>
                        <span className="font-medium text-white">{selectedParent.name}</span>
                        <Button
                            type="button"
                            size="sm"
                            onClick={() => {
                                setEditingCategory(selectedParent)
                                openAddSubcategoryDialog(selectedParent)
                            }}
                            className="ml-2 h-8 bg-[#818cf8] text-black hover:bg-[#818cf8]/90"
                        >
                            <Plus className="mr-1 h-3.5 w-3.5" />
                            Add Subcategory
                        </Button>
                    </div>
                ) : (
                    <p className="text-xs text-gray-500">Click a category card to open its subcategories. Click a subcategory to open its products.</p>
                )}
            </div>

            {/* Categories Content */}
            {isLoading ? (
                <div className="bg-[#161616] rounded-xl border border-[#333] flex justify-center items-center h-48">
                    <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
                </div>
            ) : visibleCategories.length === 0 ? (
                <div className="bg-[#161616] rounded-xl border border-[#333] flex flex-col items-center justify-center h-48 text-gray-400">
                    <FolderTree className="h-12 w-12 mb-4 opacity-50" />
                    <p>{selectedParent ? `No subcategories under ${selectedParent.name}` : scope === 'subs' ? 'No subcategories found' : 'No categories found'}</p>
                    <p className="text-sm">{selectedParent ? 'Add your first subcategory' : 'Create your first category to get started'}</p>
                    {selectedParent && (
                        <Button
                            type="button"
                            onClick={() => {
                                setEditingCategory(selectedParent)
                                openAddSubcategoryDialog(selectedParent)
                            }}
                            className="mt-4 bg-[#818cf8] text-black hover:bg-[#818cf8]/90"
                        >
                            <Plus className="mr-2 h-4 w-4" />
                            Add Subcategory
                        </Button>
                    )}
                </div>
            ) : viewMode === 'list' ? (
                /* List View with Drag and Drop */
                <DndContext
                    sensors={sensors}
                    collisionDetection={closestCenter}
                    onDragEnd={handleDragEnd}
                >
                    <SortableContext
                        items={visibleCategories.map(c => c._id)}
                        strategy={verticalListSortingStrategy}
                    >
                        <div className="bg-[#161616] rounded-xl border border-[#333] overflow-hidden">
                            <Table>
                                <TableHeader>
                                    <TableRow className="border-[#333] hover:bg-transparent">
                                        <TableHead className="text-gray-400 w-20">Order</TableHead>
                                        <TableHead className="text-gray-400">Image</TableHead>
                                        <TableHead className="text-gray-400">Name</TableHead>
                                        <TableHead className="text-gray-400">Brand</TableHead>
                                        <TableHead className="text-gray-400">Slug</TableHead>
                                        <TableHead className="text-gray-400">Parent</TableHead>
                                        <TableHead className="text-gray-400">Products</TableHead>
                                        <TableHead className="text-gray-400">Status</TableHead>
                                        <TableHead className="text-gray-400 text-right">Actions</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {visibleCategories.map((category, index) => (
                                        <DraggableTableRow key={category._id} category={category} index={index} />
                                    ))}
                                </TableBody>
                            </Table>
                        </div>
                    </SortableContext>
                </DndContext>
            ) : (
                /* Card View with Drag and Drop */
                <DndContext
                    sensors={sensors}
                    collisionDetection={closestCenter}
                    onDragEnd={handleDragEnd}
                >
                    <SortableContext
                        items={visibleCategories.map(c => c._id)}
                        strategy={rectSortingStrategy}
                    >
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                            {visibleCategories.map((category, index) => (
                                <DraggableCard key={category._id} category={category} index={index} />
                            ))}
                        </div>
                    </SortableContext>
                </DndContext>
            )}

            {/* Create/Edit Dialog */}
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
                <DialogContent className="max-h-[90vh] max-w-xl gap-3 overflow-y-auto border-[#333] bg-[#161616] p-5">
                    <DialogHeader>
                        <DialogTitle className="text-white">
                            {editingCategory ? "Edit Category" : "Add New Category"}
                        </DialogTitle>
                        <DialogDescription className="text-gray-400">
                            {editingCategory 
                                ? "Update the category information below."
                                : "Create a new category to organize your products."
                            }
                        </DialogDescription>
                    </DialogHeader>
                    
                    <div className="flex flex-wrap gap-y-3 py-3">
                        <div className="order-1 w-1/2 pr-2">
                            <label className="text-sm font-medium text-white mb-2 block">
                                Brand *
                            </label>
                            <Select
                                value={companyId}
                                onValueChange={(value) => {
                                    setCompanyId(value)
                                    setParentId("none")
                                }}
                            >
                                <SelectTrigger className="bg-[#0D0D0D] border-[#333] text-white">
                                    <SelectValue placeholder="Select brand" />
                                </SelectTrigger>
                                <SelectContent className="bg-[#0D0D0D] border-[#333]">
                                    {companies.map((company) => (
                                        <SelectItem key={company._id} value={company._id}>
                                            {company.name}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                            <p className="text-xs text-gray-500 mt-1">
                                Category names are unique only inside the selected brand.
                            </p>
                        </div>

                        <div className="order-3 w-1/2 pr-2">
                            <label className="text-sm font-medium text-white mb-2 block">
                                Category Name *
                            </label>
                            <Input
                                placeholder="e.g., Machinery, Seeds, Fertilizers"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                        </div>

                        <div className="order-4 w-1/2 pl-2">
                            <div className="mb-2 flex items-center justify-between gap-2">
                                <label className="block text-sm font-medium text-white">
                                    Category Name (Hindi)
                                </label>
                                <SuggestHindiButton text={name} onSuggest={setNameHindi} className="h-7 border-[#333] bg-[#0D0D0D] text-xs text-white hover:bg-[#1A1A1A]" />
                            </div>
                            <Input
                                placeholder="Leave empty to fill automatically"
                                value={nameHindi}
                                onChange={(e) => setNameHindi(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                            <p className="mt-1 text-[11px] text-gray-500">{HINDI_AUTO_NOTE}</p>
                        </div>

                        {/* Image Upload */}
                        <div className="order-5 w-full">
                            <label className="mb-2 block text-sm font-medium text-white">
                                Category Image
                            </label>
                            <div className="flex items-center gap-3">
                                <label className={`flex flex-1 flex-col items-center justify-center rounded-lg border-2 border-dashed transition-colors ${
                                    isUploadingImage
                                        ? 'h-24 cursor-wait border-[#818cf8]/50 bg-[#818cf8]/5'
                                        : 'h-20 cursor-pointer border-[#333] bg-[#0D0D0D] hover:bg-[#1a1a1a]'
                                }`}>
                                    <div className="flex flex-col items-center justify-center py-3">
                                        {isUploadingImage ? (
                                            <div className="flex w-full flex-col items-center gap-1.5 px-4">
                                                <div className="flex items-center gap-1 text-[10px]">
                                                    <span className={`rounded-full px-1.5 py-0.5 ${
                                                        uploadStatus === 'converting'
                                                            ? 'bg-yellow-500/20 text-yellow-400'
                                                            : 'bg-green-500/20 text-green-400'
                                                    }`}>
                                                        {uploadStatus === 'converting' ? '⟳ Converting' : '✓ Converted'}
                                                    </span>
                                                    <span className="text-gray-600">→</span>
                                                    <span className={`rounded-full px-1.5 py-0.5 ${
                                                        uploadStatus === 'uploading'
                                                            ? 'bg-blue-500/20 text-blue-400'
                                                            : uploadStatus === 'done'
                                                                ? 'bg-green-500/20 text-green-400'
                                                                : 'bg-gray-500/20 text-gray-500'
                                                    }`}>
                                                        {uploadStatus === 'uploading' ? '⟳ Uploading' : uploadStatus === 'done' ? '✓ Done' : '○ Upload'}
                                                    </span>
                                                </div>
                                                <div className="h-1 w-full rounded-full bg-[#333]">
                                                    <div className={`h-1 rounded-full transition-all duration-500 ${
                                                        uploadStatus === 'converting' ? 'w-1/3 bg-yellow-500'
                                                        : uploadStatus === 'uploading' ? 'w-2/3 bg-blue-500'
                                                        : 'w-full bg-green-500'
                                                    }`} />
                                                </div>
                                            </div>
                                        ) : (
                                            <>
                                                <Upload className="mb-1 h-5 w-5 text-gray-400" />
                                                <p className="text-xs text-gray-400">
                                                    <span className="text-[#818cf8]">Click to upload</span> — auto WebP
                                                </p>
                                            </>
                                        )}
                                    </div>
                                    <input
                                        type="file"
                                        className="hidden"
                                        accept="image/jpeg,image/png,image/gif,image/webp"
                                        onChange={handleImageUpload}
                                        disabled={isUploadingImage}
                                    />
                                </label>
                                {imageUrl && (
                                    <button
                                        type="button"
                                        onClick={() => setPreviewImageUrl(imageUrl)}
                                        className="h-20 w-20 shrink-0 overflow-hidden rounded-lg border border-[#333] bg-[#0D0D0D] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#818cf8]"
                                        aria-label="Enlarge category image"
                                    >
                                        <img
                                            src={imageUrl}
                                            alt="Category image preview"
                                            className="h-full w-full cursor-zoom-in object-cover"
                                        />
                                    </button>
                                )}
                            </div>
                            <p className="mt-1 text-xs text-gray-500">
                                PNG, JPG, GIF, WebP (max 5MB) — auto-converted to WebP. Click the preview to enlarge it.
                            </p>
                        </div>

                        {/* Parent Category */}
                        <div className="order-2 w-1/2 pl-2">
                            <label className="text-sm font-medium text-white mb-2 block">
                                Parent Category
                            </label>
                            <Select value={parentId} onValueChange={setParentId}>
                                <SelectTrigger className="bg-[#0D0D0D] border-[#333] text-white">
                                    <SelectValue placeholder="Select parent category" />
                                </SelectTrigger>
                                <SelectContent className="bg-[#0D0D0D] border-[#333]">
                                    <SelectItem value="none">None (Root Category)</SelectItem>
                                    {parentOptions.map((cat) => (
                                        <SelectItem key={cat._id} value={cat._id}>
                                            {cat.name}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                            <p className="text-xs text-gray-500 mt-1">
                                Leave as &quot;None&quot; for a top-level category
                            </p>
                        </div>

                        {/* Description */}
                        <div className="order-6 w-full">
                            <label className="text-sm font-medium text-white mb-2 block">
                                Description
                            </label>
                            <Textarea
                                placeholder="Brief description of the category..."
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white min-h-[80px]"
                            />
                        </div>

                        {/* Order & Active */}
                        <div className="order-7 flex w-full gap-4">
                            <div className="flex-1">
                                <label className="text-sm font-medium text-white mb-2 block">
                                    Display Order
                                </label>
                                <Input
                                    type="number"
                                    placeholder="0"
                                    value={order}
                                    onChange={(e) => setOrder(e.target.value)}
                                    className="bg-[#0D0D0D] border-[#333] text-white"
                                />
                                <p className="text-xs text-gray-500 mt-1">
                                    {editingCategory
                                        ? `Currently #${visibleCategories.findIndex(c => c._id === editingCategory._id) + 1} of ${visibleCategories.length} in this view. Lower numbers show first; dragging cards updates this number.`
                                        : "New categories appear after existing cards. Lower numbers show first."}
                                </p>
                            </div>
                            <div className="flex-1">
                                <label className="text-sm font-medium text-white mb-2 block">
                                    Active
                                </label>
                                <div className="flex items-center gap-3 h-10 px-3 rounded-md border border-[#333] bg-[#0D0D0D]">
                                    <Switch
                                        checked={isActive}
                                        onCheckedChange={setIsActive}
                                    />
                                    <span className={`text-sm ${isActive ? 'text-green-400' : 'text-gray-500'}`}>
                                        {isActive ? 'Active' : 'Inactive'}
                                    </span>
                                </div>
                            </div>
                        </div>

                        <div className="order-7 w-full">
                            <DiscountFields
                                value={discounts}
                                onChange={setDiscounts}
                                unavailable={discountsUnavailable}
                                helperText={parentId !== "none"
                                    ? "Leave empty to use the parent category's discount. A brand discount overrides this."
                                    : "Applies to this category and its subcategories (unless a subcategory sets its own). A brand discount overrides this."}
                                {...buildCategoryDiscountNotes({
                                    brand: getCompanyById(companyId),
                                    parentId: parentId !== "none" ? parentId : null,
                                    categories,
                                    values: discounts,
                                })}
                            />
                        </div>

                        {/* Subcategories Section - Only show when editing */}
                        {editingCategory && (
                            <div className="order-8 w-full border-t border-[#333] pt-4">
                                <div className="flex items-center justify-between mb-3">
                                    <label className="text-sm font-medium text-white">
                                        Subcategories
                                    </label>
                                    <Button
                                        type="button"
                                        onClick={() => openAddSubcategoryDialog()}
                                        size="sm"
                                        className="gap-1 is-active hover:bg-[#818cf8]/90"
                                    >
                                        <Plus className="h-3.5 w-3.5" />
                                        Add Subcategory
                                    </Button>
                                </div>

                                {/* Subcategories List */}
                                <div className="space-y-2 max-h-48 overflow-y-auto">
                                    {(() => {
                                        const subcats = categories.filter(c => c.parent?._id === editingCategory._id).sort((a, b) => (a.order || 0) - (b.order || 0))
                                        return subcats.length === 0 ? (
                                            <p className="text-xs text-gray-500 italic">No subcategories yet</p>
                                        ) : (
                                            <div className="space-y-1">
                                                {subcats.map((subcat, idx) => (
                                                    <div key={subcat._id} className="flex items-center justify-between p-2 rounded bg-[#0D0D0D] border border-[#333] group hover:border-[#555] transition-colors">
                                                        <div className="flex items-center gap-2 flex-1 min-w-0">
                                                            <GripVertical className="h-4 w-4 text-gray-600 group-hover:text-gray-400 cursor-grab active:cursor-grabbing shrink-0" />
                                                            <span className="text-xs text-gray-500 min-w-[20px]">#{idx + 1}</span>
                                                            <div className="flex-1 min-w-0">
                                                                <p className="text-sm text-white truncate">{subcat.name}</p>
                                                                {subcat.nameHindi && (
                                                                    <p className="text-xs text-gray-400 truncate">{subcat.nameHindi}</p>
                                                                )}
                                                            </div>
                                                        </div>
                                                        <div className="flex items-center gap-1 ml-2 shrink-0">
                                                            <span className="text-xs text-gray-500">
                                                                {subcat.productCount} products
                                                            </span>
                                                            <Button
                                                                type="button"
                                                                size="icon-xs"
                                                                variant="outline"
                                                                onClick={() => {
                                                                    setSelectedSubcategoryForProducts(subcat)
                                                                    setIsProductAssignmentOpen(true)
                                                                }}
                                                                className="border-[#333] bg-[#0D0D0D] text-gray-400 hover:text-blue-400 h-6 w-6"
                                                                title="Assign products to subcategory"
                                                            >
                                                                <Package className="h-3.5 w-3.5" />
                                                            </Button>
                                                            <Button
                                                                type="button"
                                                                size="icon-xs"
                                                                variant="outline"
                                                                onClick={() => openEditSubcategoryDialog(subcat)}
                                                                className="border-[#333] bg-[#0D0D0D] text-gray-400 hover:text-white h-6 w-6"
                                                                title="Edit subcategory"
                                                            >
                                                                <Pencil className="h-3.5 w-3.5" />
                                                            </Button>
                                                            <Button
                                                                type="button"
                                                                size="icon-xs"
                                                                variant="outline"
                                                                onClick={() => handleDeleteSubcategory(subcat._id)}
                                                                className="border-[#333] bg-[#0D0D0D] text-gray-400 hover:text-red-400 h-6 w-6"
                                                                title="Delete subcategory"
                                                            >
                                                                <Trash2 className="h-3.5 w-3.5" />
                                                            </Button>
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        )
                                    })()}
                                </div>
                            </div>
                        )}
                    </div>
                    
                    <DialogFooter>
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => setIsDialogOpen(false)}
                            className="border-[#333] bg-[#1A1A1A] text-gray-300 hover:text-white hover:bg-[#333]"
                        >
                            Cancel
                        </Button>
                        <Button
                            onClick={handleSubmit}
                            disabled={isSubmitting}
                            className="is-active hover:bg-[#818cf8]/90"
                        >
                            {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                            {editingCategory ? "Update Category" : "Create Category"}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            <Dialog
                open={Boolean(previewImageUrl)}
                onOpenChange={(open) => {
                    if (!open) setPreviewImageUrl("")
                }}
            >
                <DialogContent className="max-w-4xl border-[#333] bg-[#161616] p-3">
                    <DialogHeader className="sr-only">
                        <DialogTitle>Category image preview</DialogTitle>
                    </DialogHeader>
                    {previewImageUrl && (
                        <img
                            src={previewImageUrl}
                            alt="Enlarged category image"
                            className="max-h-[80vh] w-full object-contain"
                        />
                    )}
                </DialogContent>
            </Dialog>

            {/* Add/Edit Subcategory Dialog */}
            <Dialog open={isSubcategoryDialogOpen} onOpenChange={setIsSubcategoryDialogOpen}>
                <DialogContent className="max-h-[90vh] max-w-md overflow-y-auto border-[#333] bg-[#161616] gap-3">
                    <DialogHeader>
                        <DialogTitle className="text-white">
                            {editingSubcategory ? "Edit Subcategory" : "Add Subcategory"}
                        </DialogTitle>
                        <DialogDescription className="text-gray-400">
                            {editingSubcategory 
                                ? `Update subcategory "${editingSubcategory.name}"`
                                : `Add a new subcategory to "${editingCategory?.name}"`
                            }
                        </DialogDescription>
                    </DialogHeader>

                    <div className="space-y-3">
                        <div>
                            <label className="text-sm font-medium text-white mb-2 block">
                                Subcategory Name *
                            </label>
                            <Input
                                placeholder="e.g., Tractors, Harvesters"
                                value={subcategoryName}
                                onChange={(e) => setSubcategoryName(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                        </div>

                        <div>
                            <div className="mb-2 flex items-center justify-between gap-2">
                                <label className="block text-sm font-medium text-white">
                                    Subcategory Name (Hindi)
                                </label>
                                <SuggestHindiButton text={subcategoryName} onSuggest={setSubcategoryNameHindi} className="h-7 border-[#333] bg-[#0D0D0D] text-xs text-white hover:bg-[#1A1A1A]" />
                            </div>
                            <Input
                                placeholder="Leave empty to fill automatically"
                                value={subcategoryNameHindi}
                                onChange={(e) => setSubcategoryNameHindi(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                        </div>

                        <div>
                            <label className="text-sm font-medium text-white mb-2 block">
                                Description
                            </label>
                            <Textarea
                                placeholder="Brief description..."
                                value={subcategoryDescription}
                                onChange={(e) => setSubcategoryDescription(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white min-h-[60px]"
                            />
                        </div>

                        <div>
                            <label className="text-sm font-medium text-white mb-2 block">
                                Subcategory Image
                            </label>
                            <div className="flex items-center gap-3">
                                <label className="flex h-20 flex-1 cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-[#333] bg-[#0D0D0D] transition-colors hover:bg-[#1a1a1a]">
                                    <div className="flex flex-col items-center justify-center py-3">
                                        {isUploadingSubcategoryImage ? (
                                            <Loader2 className="h-5 w-5 animate-spin text-gray-400" />
                                        ) : (
                                            <>
                                                <Upload className="mb-1 h-5 w-5 text-gray-400" />
                                                <p className="text-xs text-gray-400">
                                                    <span className="text-[#818cf8]">Click to upload</span> — auto WebP
                                                </p>
                                            </>
                                        )}
                                    </div>
                                    <input
                                        type="file"
                                        className="hidden"
                                        accept="image/jpeg,image/png,image/gif,image/webp"
                                        onChange={handleSubcategoryImageUpload}
                                        disabled={isUploadingSubcategoryImage}
                                    />
                                </label>
                                {subcategoryImageUrl && (
                                    <img
                                        src={subcategoryImageUrl}
                                        alt="Subcategory preview"
                                        className="h-20 w-20 shrink-0 rounded-lg border border-[#333] bg-[#0D0D0D] object-cover"
                                    />
                                )}
                            </div>
                        </div>

                        <div>
                            <label className="text-sm font-medium text-white mb-2 block">
                                Display Order
                            </label>
                            <Input
                                type="number"
                                placeholder="0"
                                value={subcategoryOrder}
                                onChange={(e) => setSubcategoryOrder(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                            <p className="text-xs text-gray-500 mt-1">
                                New subcategories appear after existing ones. Lower numbers show first.
                            </p>
                        </div>

                        <DiscountFields
                            value={subcategoryDiscounts}
                            onChange={setSubcategoryDiscounts}
                            unavailable={subcategoryDiscountsUnavailable}
                            helperText="Leave empty to use the parent category's discount. A brand discount overrides this."
                            {...buildCategoryDiscountNotes({
                                brand: editingCategory ? getCompanyById(getCategoryCompanyId(editingCategory)) : null,
                                parentId: editingCategory?._id ?? null,
                                categories,
                                values: subcategoryDiscounts,
                            })}
                        />
                    </div>

                    <DialogFooter>
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => {
                                setIsSubcategoryDialogOpen(false)
                                setEditingSubcategory(null)
                            }}
                            className="border-[#333] bg-[#1A1A1A] text-gray-300 hover:text-white hover:bg-[#333]"
                        >
                            Cancel
                        </Button>
                        <Button
                            onClick={handleAddSubcategory}
                            disabled={isSubmittingSubcategory}
                            className="is-active hover:bg-[#818cf8]/90"
                        >
                            {isSubmittingSubcategory && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                            {editingSubcategory ? "Update Subcategory" : "Add Subcategory"}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Product Assignment Dialog */}
            <Dialog open={isProductAssignmentOpen} onOpenChange={setIsProductAssignmentOpen}>
                <DialogContent className="max-w-2xl border-[#333] bg-[#161616] gap-3 max-h-[80vh] overflow-y-auto">
                    <DialogHeader>
                        <DialogTitle className="text-white">
                            Assign Products to Subcategory
                        </DialogTitle>
                        <DialogDescription className="text-gray-400">
                            Currently viewing products for "{selectedSubcategoryForProducts?.name}"
                            <br />
                            <span className="text-xs mt-1">
                                This subcategory has {selectedSubcategoryForProducts?.productCount || 0} products assigned
                            </span>
                        </DialogDescription>
                    </DialogHeader>

                    <div className="space-y-3">
                        <div className="text-sm text-gray-300">
                            <p className="mb-2 font-medium">To assign products to this subcategory:</p>
                            <ol className="list-decimal list-inside space-y-1 text-xs text-gray-400">
                                <li>Go to the Products section in the admin panel</li>
                                <li>Edit the product you want to assign</li>
                                <li>Select this subcategory from the category dropdown</li>
                                <li>Save the product</li>
                            </ol>
                        </div>

                        <div className="bg-[#0D0D0D] border border-[#333] rounded-lg p-3">
                            <div className="flex items-start gap-2">
                                <div className="text-blue-400 text-sm mt-1">ℹ</div>
                                <div className="text-xs text-gray-400">
                                    <p className="font-medium text-gray-300 mb-1">Quick Info:</p>
                                    <p>Products are assigned to subcategories by updating the product's category field. This modal shows the current assignment status and provides quick links.</p>
                                </div>
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-2 pt-2">
                            <div className="bg-[#0D0D0D] border border-[#333] rounded p-2">
                                <div className="text-xs text-gray-500 mb-1">Subcategory</div>
                                <div className="text-sm text-white font-medium truncate">
                                    {selectedSubcategoryForProducts?.name}
                                </div>
                            </div>
                            <div className="bg-[#0D0D0D] border border-[#333] rounded p-2">
                                <div className="text-xs text-gray-500 mb-1">Products Count</div>
                                <div className="text-sm text-white font-medium">
                                    {selectedSubcategoryForProducts?.productCount || 0}
                                </div>
                            </div>
                        </div>
                    </div>

                    <DialogFooter>
                        <Button
                            type="button"
                            onClick={() => {
                                setIsProductAssignmentOpen(false)
                                setSelectedSubcategoryForProducts(null)
                            }}
                            className="is-active hover:bg-[#818cf8]/90"
                        >
                            Done
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Delete Confirmation Dialog */}
            <Dialog open={!!deleteConfirmId} onOpenChange={() => setDeleteConfirmId(null)}>
                <DialogContent className="bg-[#161616] border-[#333]">
                    <DialogHeader>
                        <DialogTitle className="text-white">Delete Category</DialogTitle>
                        <DialogDescription className="text-gray-400">
                            Are you sure you want to delete this category? This action cannot be undone.
                            Categories with subcategories or products cannot be deleted.
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter>
                        <Button
                            variant="outline"
                            onClick={() => setDeleteConfirmId(null)}
                            className="border-[#333] bg-[#1A1A1A] text-gray-300 hover:text-white hover:bg-[#333]"
                        >
                            Cancel
                        </Button>
                        <Button
                            variant="destructive"
                            onClick={() => deleteConfirmId && handleDelete(deleteConfirmId)}
                            className="bg-red-600 hover:bg-red-700"
                        >
                            Delete Category
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Load More Button */}
            {hasMore && categories.length > 0 && (
                <div className="flex justify-center pt-4">
                    <Button
                        onClick={loadMore}
                        disabled={isLoadingMore}
                        variant="outline"
                        className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] min-w-[200px]"
                    >
                        {isLoadingMore ? (
                            <>
                                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                Loading...
                            </>
                        ) : (
                            `Load More (${categories.length}/${totalCategories})`
                        )}
                    </Button>
                </div>
            )}
        </div>
    )
}
