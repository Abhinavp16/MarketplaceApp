"use client"

import { useEffect, useState } from "react"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Loader2, Plus, Edit2, Trash2, Star, Eye, EyeOff } from "@/components/hugeicons"
import { toast } from "sonner"
import { ReviewModal } from "@/components/reviews/review-modal"
import { apiFetch } from "@/lib/api"

interface Review {
    _id: string
    name: string
    role: string
    review: string
    rating: number
    isActive: boolean
    createdAt: string
}

export default function ReviewsPage() {
    const [reviews, setReviews] = useState<Review[]>([])
    const [isLoading, setIsLoading] = useState(true)
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [editingReview, setEditingReview] = useState<Review | null>(null)

    useEffect(() => {
        fetchReviews()
    }, [])

    async function fetchReviews() {
        try {
            const res = await apiFetch('/admin/reviews')
            const data = await res.json()
            if (res.ok) {
                const list = Array.isArray(data.data) ? data.data : (data.data?.reviews ?? data.reviews ?? [])
                setReviews(list)
            } else {
                toast.error(data?.message || "Failed to fetch reviews")
            }
        } catch (error) {
            console.error(error)
            toast.error("Error connecting to server")
        } finally {
            setIsLoading(false)
        }
    }

    async function toggleActive(review: Review) {
        try {
            const res = await apiFetch(`/admin/reviews/${review._id}`, {
                method: 'PUT',
                body: JSON.stringify({ isActive: !review.isActive })
            })
            if (res.ok) {
                setReviews(prev => prev.map(r =>
                    r._id === review._id ? { ...r, isActive: !r.isActive } : r
                ))
                toast.success(`Review ${!review.isActive ? 'activated' : 'deactivated'}`)
            }
        } catch (error) {
            toast.error("Failed to update status")
        }
    }

    async function deleteReview(id: string) {
        if (!confirm("Are you sure you want to delete this review?")) return
        try {
            const res = await apiFetch(`/admin/reviews/${id}`, { method: 'DELETE' })
            if (res.ok) {
                setReviews(prev => prev.filter(r => r._id !== id))
                toast.success("Review deleted")
            }
        } catch (error) {
            toast.error("Failed to delete review")
        }
    }

    return (
        <div className="flex flex-col gap-6">
            <div className="flex justify-between items-center">
                <div className="flex items-center gap-3">
                    <Star className="h-8 w-8 text-[#86efac]" />
                    <h1 className="text-3xl font-bold text-white">Customer Reviews</h1>
                </div>
                <Button
                    onClick={() => {
                        setEditingReview(null)
                        setIsModalOpen(true)
                    }}
                    className="bg-[#86efac] text-black hover:bg-[#86efac]/90"
                >
                    <Plus className="h-4 w-4 mr-2" /> Add Review
                </Button>
            </div>

            <Card className="bg-[#161616] border-[#333]">
                <CardHeader>
                    <CardTitle className="text-white text-lg">Manage Homepage Testimonials</CardTitle>
                </CardHeader>
                <CardContent>
                    {isLoading ? (
                        <div className="flex justify-center p-8">
                            <Loader2 className="h-8 w-8 animate-spin text-[#86efac]" />
                        </div>
                    ) : reviews.length === 0 ? (
                        <div className="text-center text-gray-500 py-10">No reviews found. Click &quot;Add Review&quot; to create one.</div>
                    ) : (
                        <Table>
                            <TableHeader>
                                <TableRow className="border-[#333] hover:bg-transparent">
                                    <TableHead className="text-gray-400 w-[250px]">Customer</TableHead>
                                    <TableHead className="text-gray-400">Review</TableHead>
                                    <TableHead className="text-gray-400">Rating</TableHead>
                                    <TableHead className="text-gray-400">Status</TableHead>
                                    <TableHead className="text-gray-400 text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {reviews.map((review) => (
                                    <TableRow key={review._id} className="border-[#333] hover:bg-[#1A1A1A]">
                                        <TableCell className="text-white">
                                            <div className="font-semibold">{review.name}</div>
                                            <div className="text-xs text-[#86efac]">{review.role}</div>
                                        </TableCell>
                                        <TableCell className="text-gray-400">
                                            <p className="line-clamp-2 italic text-sm">&quot;{review.review}&quot;</p>
                                        </TableCell>
                                        <TableCell>
                                            <div className="flex items-center gap-1 text-[#F59E0B]">
                                                <span className="font-bold text-sm">{review.rating}</span>
                                                <Star className="h-3 w-3 fill-current" />
                                            </div>
                                        </TableCell>
                                        <TableCell>
                                            <Badge variant="outline" className={review.isActive ? "text-green-400 border-green-400" : "text-red-400 border-red-400"}>
                                                {review.isActive ? 'Visible' : 'Hidden'}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <div className="flex justify-end gap-2">
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                                                    onClick={() => toggleActive(review)}
                                                    title={review.isActive ? "Hide" : "Show"}
                                                >
                                                    {review.isActive ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4 text-gray-500" />}
                                                </Button>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 text-white hover:bg-[#333]"
                                                    onClick={() => {
                                                        setEditingReview(review)
                                                        setIsModalOpen(true)
                                                    }}
                                                >
                                                    <Edit2 className="h-4 w-4" />
                                                </Button>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="h-8 w-8 p-0 text-red-400 hover:bg-red-400/10 hover:text-red-400"
                                                    onClick={() => deleteReview(review._id)}
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

            <ReviewModal
                isOpen={isModalOpen}
                onClose={() => setIsModalOpen(false)}
                onSuccess={fetchReviews}
                review={editingReview}
            />
        </div>
    )
}
