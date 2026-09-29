"use client"

import { useState, useEffect, useCallback, useRef } from "react"
import { useRouter } from "next/navigation"
import { Plus, Pencil, Trash2, Building2, Loader2, ImageIcon, LayoutGrid, List, Upload, Search, Tag, GripVertical, FolderTree } from "@/components/hugeicons"
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
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table"
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
import {
    EMPTY_DISCOUNT_FORM,
    formatDiscountSummary,
    hasDiscountFields,
    toDiscountFormValues,
    toDiscountPayload,
    validateDiscountValues,
    type DiscountFormValues,
} from "@/lib/discount"

interface Company {
    _id: string
    name: string
    slug: string
    logo?: { url?: string; publicId?: string }
    description?: string
    order: number
    createdAt: string
    customerDiscountPercent?: number | null
    wholesalerDiscountPercent?: number | null
}

export default function BrandsPage() {
    const router = useRouter()
    const [companies, setCompanies] = useState<Company[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isLoadingMore, setIsLoadingMore] = useState(false)
    const [isDialogOpen, setIsDialogOpen] = useState(false)
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [editingCompany, setEditingCompany] = useState<Company | null>(null)
    const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null)
    const [viewMode, setViewMode] = useState<'list' | 'card'>('card')

    // Search & Pagination state
    const [searchQuery, setSearchQuery] = useState("")
    const [page, setPage] = useState(1)
    const [totalPages, setTotalPages] = useState(1)
    const [totalBrands, setTotalBrands] = useState(0)
    const [hasMore, setHasMore] = useState(false)
    const [loadedSearchQuery, setLoadedSearchQuery] = useState("")
    const [isReordering, setIsReordering] = useState(false)
    const fetchGeneration = useRef(0)
    const reorderInFlight = useRef(false)

    // Form state
    const [name, setName] = useState("")
    const [description, setDescription] = useState("")
    const [logoUrl, setLogoUrl] = useState("")
    const [logoPublicId, setLogoPublicId] = useState("")
    const [previewImageUrl, setPreviewImageUrl] = useState("")
    const [isUploadingLogo, setIsUploadingLogo] = useState(false)
    const [discounts, setDiscounts] = useState<DiscountFormValues>(EMPTY_DISCOUNT_FORM)
    const [discountsUnavailable, setDiscountsUnavailable] = useState(false)
    const sensors = useSensors(
        useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
        useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
    )

    const fetchCompanies = useCallback(async (pageNum: number = 1, reset: boolean = false, requestedSearch: string = "") => {
        const requestGeneration = ++fetchGeneration.current
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

            // Authenticated so the admin-only discount fields are included.
            const res = await apiFetch(`/companies?${params.toString()}`)
            if (requestGeneration !== fetchGeneration.current) return
            if (res.ok) {
                const data = await res.json()
                const items = data.data || []
                const pagination = data.pagination || {}

                if (reset || pageNum === 1) {
                    setCompanies(items)
                } else {
                    setCompanies(prev => [...prev, ...items])
                }

                setTotalPages(pagination.totalPages || 1)
                setTotalBrands(pagination.total || items.length)
                setHasMore((pagination.page || 1) < (pagination.totalPages || 1))
                setLoadedSearchQuery(requestedSearch.trim())
            }
        } catch (error) {
            console.error("Failed to fetch companies:", error)
            toast.error("Failed to load brands")
        } finally {
            if (requestGeneration === fetchGeneration.current) {
                setIsLoading(false)
                setIsLoadingMore(false)
            }
        }
    }, [])

    useEffect(() => {
        const timeout = window.setTimeout(() => fetchCompanies(1, true, ""), 0)
        return () => window.clearTimeout(timeout)
    }, [fetchCompanies])

    const handleSearch = useCallback((e: React.FormEvent) => {
        e.preventDefault()
        fetchCompanies(1, true, searchQuery)
    }, [fetchCompanies, searchQuery])

    const loadMore = useCallback(() => {
        if (hasMore && !isLoadingMore) {
            const nextPage = page + 1
            setPage(nextPage)
            fetchCompanies(nextPage, false, loadedSearchQuery)
        }
    }, [fetchCompanies, hasMore, isLoadingMore, loadedSearchQuery, page])

    function openCreateDialog() {
        setEditingCompany(null)
        setName("")
        setDescription("")
        setLogoUrl("")
        setLogoPublicId("")
        setDiscounts(EMPTY_DISCOUNT_FORM)
        setDiscountsUnavailable(false)
        setIsDialogOpen(true)
    }

    function openEditDialog(company: Company) {
        setEditingCompany(company)
        setName(company.name)
        setDescription(company.description || "")
        setLogoUrl(company.logo?.url || "")
        setLogoPublicId(company.logo?.publicId || "")
        setDiscounts(toDiscountFormValues(company))
        setDiscountsUnavailable(!hasDiscountFields(company))
        setIsDialogOpen(true)
    }

    async function handleLogoUpload(e: React.ChangeEvent<HTMLInputElement>) {
        const file = e.target.files?.[0]
        if (!file) return

        setIsUploadingLogo(true)
        const formData = new FormData()
        formData.append('image', file)

        try {
            const response = await apiFetch('/upload/image?folder=brands', {
                method: 'POST',
                body: formData,
            })

            if (!response.ok) {
                const error = await response.json()
                throw new Error(error.message || 'Upload failed')
            }

            const data = await response.json()
            
            if (data.success && data.data) {
                setLogoUrl(data.data.url)
                setLogoPublicId(data.data.publicId)
                toast.success('Logo uploaded successfully')
            }
        } catch (error: any) {
            console.error('Upload error:', error)
            toast.error(error.message || 'Failed to upload logo')
        } finally {
            setIsUploadingLogo(false)
            e.target.value = ''
        }
    }

    async function handleSubmit() {
        if (!name.trim()) {
            toast.error("Brand name is required")
            return
        }
        const discountError = validateDiscountValues(discounts)
        if (discountError) {
            toast.error(discountError)
            return
        }

        setIsSubmitting(true)

        try {
            const payload = {
                name: name.trim(),
                description: description.trim() || undefined,
                logo: logoUrl.trim() ? { url: logoUrl.trim(), publicId: logoPublicId || undefined } : undefined,
                ...(discountsUnavailable ? {} : toDiscountPayload(discounts)),
            }

            const endpoint = editingCompany
                ? `/companies/${editingCompany._id}`
                : "/companies"

            const res = await apiFetch(endpoint, {
                method: editingCompany ? "PUT" : "POST",
                body: JSON.stringify(payload),
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to save brand")
            }

            toast.success(editingCompany ? "Brand updated successfully" : "Brand created successfully")
            setIsDialogOpen(false)
            fetchCompanies(1, true, loadedSearchQuery)
        } catch (error: any) {
            toast.error(error.message || "Failed to save brand")
        } finally {
            setIsSubmitting(false)
        }
    }

    async function handleDelete(id: string) {
        try {
            const res = await apiFetch(`/companies/${id}`, {
                method: "DELETE",
            })

            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || "Failed to delete brand")
            }

            toast.success("Brand deleted successfully")
            setDeleteConfirmId(null)
            fetchCompanies(1, true, loadedSearchQuery)
        } catch (error: any) {
            toast.error(error.message || "Failed to delete brand")
        }
    }

    const canReorder = !searchQuery.trim() && !loadedSearchQuery && !hasMore && companies.length === totalBrands && !isReordering

    function openBrandCategories(company: Company) {
        router.push(`/categories?company=${encodeURIComponent(company._id)}`)
    }

    async function handleDragEnd(event: DragEndEvent) {
        if (!canReorder || reorderInFlight.current) return
        const { active, over } = event
        if (!over || active.id === over.id) return

        const oldIndex = companies.findIndex((company) => company._id === active.id)
        const newIndex = companies.findIndex((company) => company._id === over.id)
        if (oldIndex === -1 || newIndex === -1) return

        const moved = arrayMove(companies, oldIndex, newIndex).map((company, index) => ({
            ...company,
            order: index + 1,
        }))
        setCompanies(moved)
        reorderInFlight.current = true
        setIsReordering(true)

        try {
            const res = await apiFetch('/companies/reorder', {
                method: 'POST',
                body: JSON.stringify({
                    updates: moved.map((company) => ({
                        companyId: company._id,
                        order: company.order,
                    })),
                }),
            })
            if (!res.ok) {
                const error = await res.json()
                throw new Error(error.message || 'Failed to reorder brands')
            }
            toast.success('Brands reordered successfully')
        } catch (error: any) {
            console.error('Brand reorder error:', error)
            toast.error(error.message || 'Failed to reorder brands')
            fetchCompanies(1, true, "")
        } finally {
            reorderInFlight.current = false
            setIsReordering(false)
        }
    }

    function SortableBrandRow({ company, index }: { company: Company; index: number }) {
        const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
            id: company._id,
            disabled: !canReorder,
        })
        const style = { transform: CSS.Transform.toString(transform), transition }

        return (
            <TableRow
                ref={setNodeRef}
                style={style}
                onClick={() => !isDragging && openBrandCategories(company)}
                className={`cursor-pointer border-[#333] transition-colors ${
                    isDragging ? 'bg-[#818cf8]/10 ring-2 ring-[#818cf8]' : 'hover:bg-[#1A1A1A]'
                }`}
            >
                <TableCell
                    {...attributes}
                    {...listeners}
                    onClick={(event) => event.stopPropagation()}
                    className={canReorder ? 'touch-none cursor-grab text-gray-400 active:cursor-grabbing' : 'text-gray-600'}
                >
                    <div className="flex items-center gap-2">
                        <GripVertical className="h-4 w-4" />
                        <span className="font-bold text-[#818cf8]">#{index + 1}</span>
                    </div>
                </TableCell>
                <TableCell>
                    {company.logo?.url ? (
                        <img src={company.logo.url} alt={company.name} className="h-10 w-10 rounded-lg bg-[#0D0D0D] object-cover" />
                    ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-[#0D0D0D]">
                            <Building2 className="h-5 w-5 text-gray-500" />
                        </div>
                    )}
                </TableCell>
                <TableCell className="font-medium text-white">{company.name}</TableCell>
                <TableCell className="text-gray-400">{company.slug}</TableCell>
                <TableCell className="max-w-[200px] truncate text-gray-400">{company.description || '-'}</TableCell>
                <TableCell>
                    {formatDiscountSummary(company) ? <DiscountBadge summary={formatDiscountSummary(company)} /> : <span className="text-gray-600">-</span>}
                </TableCell>
                <TableCell className="text-right">
                    <div className="flex justify-end gap-2" onClick={(event) => event.stopPropagation()} onPointerDown={(event) => event.stopPropagation()}>
                        <Button size="icon" variant="ghost" className="h-8 w-8 text-blue-400 hover:text-blue-300" onClick={() => openEditDialog(company)} aria-label="Edit brand">
                            <Pencil className="h-4 w-4" />
                        </Button>
                        <Button size="icon" variant="ghost" className="h-8 w-8 text-red-400 hover:bg-red-400/10 hover:text-red-300" onClick={() => setDeleteConfirmId(company._id)}>
                            <Trash2 className="h-4 w-4" />
                        </Button>
                    </div>
                </TableCell>
            </TableRow>
        )
    }

    function SortableBrandCard({ company, index }: { company: Company; index: number }) {
        const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
            id: company._id,
            disabled: !canReorder,
        })
        const style = { transform: CSS.Transform.toString(transform), transition }

        return (
            <div
                ref={setNodeRef}
                style={style}
                onClick={() => !isDragging && openBrandCategories(company)}
                className={`relative cursor-pointer overflow-hidden rounded-xl border border-[#333] bg-[#161616] transition-all ${
                    isDragging ? 'opacity-50 ring-2 ring-[#818cf8]' : 'hover:border-[#818cf8]/50'
                }`}
            >
                <div className="flex h-12 items-center justify-between border-b border-blue-500/50 bg-blue-600/20 px-4 transition-colors hover:bg-blue-600/30">
                    <div
                        {...attributes}
                        {...listeners}
                        onClick={(event) => event.stopPropagation()}
                        className={`flex flex-1 items-center gap-3 ${canReorder ? 'cursor-grab active:cursor-grabbing touch-none' : 'text-gray-500'}`}
                    >
                        <GripVertical className="h-4 w-4" />
                        <span className="text-sm font-bold text-white">#{index + 1}</span>
                    </div>
                    <div className="flex gap-1" onClick={(event) => event.stopPropagation()} onPointerDown={(event) => event.stopPropagation()}>
                        <Button size="icon" variant="ghost" className="h-7 w-7 text-blue-300 hover:bg-blue-400/20 hover:text-blue-200" onClick={() => openEditDialog(company)} aria-label="Edit brand">
                            <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button size="icon" variant="ghost" className="h-7 w-7 text-red-400 hover:bg-red-400/20 hover:text-red-300" onClick={() => setDeleteConfirmId(company._id)}>
                            <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                    </div>
                </div>
                <div className="space-y-3 p-4">
                    {company.logo?.url ? (
                        <img src={company.logo.url} alt={company.name} className="h-16 w-16 rounded-xl bg-[#0D0D0D] object-cover" />
                    ) : (
                        <div className="flex h-16 w-16 items-center justify-center rounded-xl bg-[#0D0D0D]">
                            <Building2 className="h-8 w-8 text-gray-500" />
                        </div>
                    )}
                    <div>
                        <h3 className="text-lg font-semibold text-white">{company.name}</h3>
                        <p className="text-sm text-gray-500">/{company.slug}</p>
                    </div>
                    <DiscountBadge summary={formatDiscountSummary(company)} />
                    {company.description && <p className="line-clamp-2 text-sm text-gray-400">{company.description}</p>}
                    <div className="flex items-center gap-2 border-t border-[#333] pt-3 text-xs font-medium text-[#818cf8]">
                        <FolderTree className="h-4 w-4" />
                        View categories
                    </div>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <Tag className="h-8 w-8 text-[#818cf8]" />
                    <div>
                        <h1 className="text-3xl font-bold text-white">Brands</h1>
                        <p className="text-gray-400 text-sm">{totalBrands > 0 && `(${totalBrands} brands)`}</p>
                    </div>
                </div>
                <div className="flex items-center gap-3">
                    {/* View Toggle */}
                    <div className="flex items-center bg-[#161616] rounded-lg p-1 border border-[#333]">
                        <button
                            onClick={() => setViewMode('list')}
                            className={`p-2 rounded-md transition-colors ${viewMode === 'list' ? 'is-active' : 'text-gray-400 hover:text-white'}`}
                        >
                            <List className="h-4 w-4" />
                        </button>
                        <button
                            onClick={() => setViewMode('card')}
                            className={`p-2 rounded-md transition-colors ${viewMode === 'card' ? 'is-active' : 'text-gray-400 hover:text-white'}`}
                        >
                            <LayoutGrid className="h-4 w-4" />
                        </button>
                    </div>
                    <Button 
                        onClick={openCreateDialog}
                        className="is-active hover:bg-[#818cf8]/90"
                    >
                        <Plus className="h-4 w-4 mr-2" />
                        Add Brand
                    </Button>
                </div>
            </div>

            {/* Search Bar */}
            <form onSubmit={handleSearch} className="flex items-center gap-3">
                <div className="relative flex-1 max-w-md">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                    <Input
                        type="text"
                        placeholder="Search brands by name..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="pl-10 bg-[#161616] border-[#333] text-white placeholder:text-gray-500 focus-visible:ring-[#818cf8]"
                    />
                </div>
                <Button
                    type="submit"
                    variant="outline"
                    className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]"
                >
                    Search
                </Button>
                {searchQuery && (
                    <Button
                        type="button"
                        variant="ghost"
                        onClick={() => {
                            setSearchQuery("")
                            fetchCompanies(1, true, "")
                        }}
                        className="text-gray-400 hover:text-white"
                    >
                        Clear
                    </Button>
                )}
            </form>

            {/* Brands Content */}
            {isLoading ? (
                <div className="bg-[#161616] rounded-xl border border-[#333] flex justify-center items-center h-48">
                    <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
                </div>
            ) : companies.length === 0 ? (
                <div className="bg-[#161616] rounded-xl border border-[#333] flex flex-col items-center justify-center h-48 text-gray-400">
                    <Building2 className="h-12 w-12 mb-4 opacity-50" />
                    <p>No brands found</p>
                    <p className="text-sm">Create your first brand to get started</p>
                </div>
            ) : (
                <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
                    <SortableContext
                        items={companies.map((company) => company._id)}
                        strategy={viewMode === 'list' ? verticalListSortingStrategy : rectSortingStrategy}
                    >
                        {viewMode === 'list' ? (
                            <div className="overflow-hidden rounded-xl border border-[#333] bg-[#161616]">
                                <Table>
                                    <TableHeader>
                                        <TableRow className="border-[#333] hover:bg-transparent">
                                            <TableHead className="text-gray-400">Order</TableHead>
                                            <TableHead className="text-gray-400">Logo</TableHead>
                                            <TableHead className="text-gray-400">Name</TableHead>
                                            <TableHead className="text-gray-400">Slug</TableHead>
                                            <TableHead className="text-gray-400">Description</TableHead>
                                            <TableHead className="text-gray-400">Discount</TableHead>
                                            <TableHead className="text-right text-gray-400">Actions</TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {companies.map((company, index) => (
                                            <SortableBrandRow key={company._id} company={company} index={index} />
                                        ))}
                                    </TableBody>
                                </Table>
                            </div>
                        ) : (
                            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
                                {companies.map((company, index) => (
                                    <SortableBrandCard key={company._id} company={company} index={index} />
                                ))}
                            </div>
                        )}
                    </SortableContext>
                </DndContext>
            )}

            {!canReorder && companies.length > 0 && (
                <p className="text-xs text-gray-500">Clear the search and load all brands to rearrange them.</p>
            )}

            {/* Create/Edit Dialog */}
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
                <DialogContent className="max-h-[90vh] overflow-y-auto bg-[#161616] border-[#333]">
                    <DialogHeader>
                        <DialogTitle className="text-white">
                            {editingCompany ? "Edit Brand" : "Add New Brand"}
                        </DialogTitle>
                        <DialogDescription className="text-gray-400">
                            {editingCompany 
                                ? "Update the brand information below."
                                : "Create a new brand/company to associate with products."
                            }
                        </DialogDescription>
                    </DialogHeader>
                    
                    <div className="space-y-4 py-4">
                        <div>
                            <label className="text-sm font-medium text-white mb-2 block">
                                Brand Name *
                            </label>
                            <Input
                                placeholder="e.g., John Deere, Mahindra"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                        </div>
                        
                        <div>
                            <label className="mb-2 block text-sm font-medium text-white">
                                Brand Logo
                            </label>
                            <div className="flex items-center gap-3">
                                <label className="flex h-20 flex-1 cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-[#333] bg-[#0D0D0D] transition-colors hover:bg-[#1a1a1a]">
                                    <div className="flex flex-col items-center justify-center">
                                        {isUploadingLogo ? (
                                            <>
                                                <Loader2 className="mb-1 h-5 w-5 animate-spin text-[#818cf8]" />
                                                <p className="text-xs text-gray-400">Uploading...</p>
                                            </>
                                        ) : (
                                            <>
                                                <Upload className="mb-1 h-5 w-5 text-gray-400" />
                                                <p className="text-xs text-gray-400">
                                                    <span className="text-[#818cf8]">Click to upload</span>
                                                </p>
                                            </>
                                        )}
                                    </div>
                                    <input
                                        type="file"
                                        className="hidden"
                                        accept="image/jpeg,image/png,image/gif,image/webp"
                                        onChange={handleLogoUpload}
                                        disabled={isUploadingLogo}
                                    />
                                </label>
                                {logoUrl && (
                                    <button
                                        type="button"
                                        onClick={() => setPreviewImageUrl(logoUrl)}
                                        className="h-20 w-20 shrink-0 overflow-hidden rounded-lg border border-[#333] bg-[#0D0D0D] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#818cf8]"
                                        aria-label="Enlarge brand logo"
                                    >
                                        <img
                                            src={logoUrl}
                                            alt="Brand logo preview"
                                            className="h-full w-full cursor-zoom-in object-cover"
                                        />
                                    </button>
                                )}
                            </div>
                            <p className="mt-1 text-xs text-gray-500">
                                PNG, JPG, GIF, WebP (max 5MB). Click the preview to enlarge it.
                            </p>
                        </div>
                        
                        <div>
                            <label className="text-sm font-medium text-white mb-2 block">
                                Description
                            </label>
                            <Textarea
                                placeholder="Brief description of the brand..."
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                className="bg-[#0D0D0D] border-[#333] text-white min-h-[80px]"
                            />
                        </div>

                        <DiscountFields
                            value={discounts}
                            onChange={setDiscounts}
                            unavailable={discountsUnavailable}
                            helperText="Applies to every product of this brand and overrides category discounts. Leave empty to use category discounts."
                        />
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
                            {editingCompany ? "Update Brand" : "Create Brand"}
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
                        <DialogTitle>Brand logo preview</DialogTitle>
                    </DialogHeader>
                    {previewImageUrl && (
                        <img
                            src={previewImageUrl}
                            alt="Enlarged brand logo"
                            className="max-h-[80vh] w-full object-contain"
                        />
                    )}
                </DialogContent>
            </Dialog>

            {/* Delete Confirmation Dialog */}
            <Dialog open={!!deleteConfirmId} onOpenChange={() => setDeleteConfirmId(null)}>
                <DialogContent className="bg-[#161616] border-[#333]">
                    <DialogHeader>
                        <DialogTitle className="text-white">Delete Brand</DialogTitle>
                        <DialogDescription className="text-gray-400">
                            Are you sure you want to delete this brand? This action cannot be undone.
                            Products associated with this brand will no longer have a brand assigned.
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
                            Delete Brand
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Load More Button */}
            {hasMore && companies.length > 0 && (
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
                            `Load More (${companies.length}/${totalBrands})`
                        )}
                    </Button>
                </div>
            )}
        </div>
    )
}
