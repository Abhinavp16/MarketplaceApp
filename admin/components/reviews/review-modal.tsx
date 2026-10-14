"use client"

import { useEffect, useState } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogFooter,
} from "@/components/ui/dialog"
import {
    Form,
    FormControl,
    FormField,
    FormItem,
    FormLabel,
    FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { Switch } from "@/components/ui/switch"
import { Loader2 } from "@/components/hugeicons"
import { apiFetch } from "@/lib/api"
import { toast } from "sonner"

const reviewSchema = z.object({
    name: z.string().min(1, "Name is required"),
    role: z.string().min(1, "Role/Location is required"),
    review: z.string().min(10, "Review must be at least 10 characters"),
    rating: z.coerce.number().min(1).max(5),
    isActive: z.boolean().default(true),
})

type ReviewFormValues = z.infer<typeof reviewSchema>

interface ReviewModalProps {
    isOpen: boolean
    onClose: () => void
    onSuccess: () => void
    review?: any | null
}

export function ReviewModal({ isOpen, onClose, onSuccess, review }: ReviewModalProps) {
    const [isLoading, setIsLoading] = useState(false)

    const form = useForm<ReviewFormValues>({
        resolver: zodResolver(reviewSchema),
        defaultValues: {
            name: "",
            role: "",
            review: "",
            rating: 5,
            isActive: true,
        },
    })

    useEffect(() => {
        if (review) {
            form.reset({
                name: review.name,
                role: review.role,
                review: review.review,
                rating: review.rating,
                isActive: review.isActive,
            })
        } else {
            form.reset({
                name: "",
                role: "",
                review: "",
                rating: 5,
                isActive: true,
            })
        }
    }, [review, form, isOpen])

    async function onSubmit(values: ReviewFormValues) {
        setIsLoading(true)
        try {
            const url = review ? `/admin/reviews/${review._id}` : "/admin/reviews"
            const method = review ? "PUT" : "POST"

            const res = await apiFetch(url, {
                method,
                body: JSON.stringify(values),
            })

            if (res.ok) {
                toast.success(review ? "Review updated" : "Review created")
                onSuccess()
                onClose()
            } else {
                toast.error("Something went wrong")
            }
        } catch (error) {
            toast.error("Failed to save review")
        } finally {
            setIsLoading(false)
        }
    }

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent className="bg-[#161616] border-[#333] text-white">
                <DialogHeader>
                    <DialogTitle>{review ? "Edit Review" : "Add New Review"}</DialogTitle>
                </DialogHeader>

                <Form {...form}>
                    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                        <FormField
                            control={form.control}
                            name="name"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Customer Name</FormLabel>
                                    <FormControl>
                                        <Input {...field} className="bg-[#0D0D0D] border-[#333]" placeholder="e.g. Rajesh Kumar" />
                                    </FormControl>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />

                        <FormField
                            control={form.control}
                            name="role"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Role / Location</FormLabel>
                                    <FormControl>
                                        <Input {...field} className="bg-[#0D0D0D] border-[#333]" placeholder="e.g. Progressive Farmer, Punjab" />
                                    </FormControl>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />

                        <FormField
                            control={form.control}
                            name="rating"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Rating (1-5)</FormLabel>
                                    <FormControl>
                                        <Input type="number" {...field} className="bg-[#0D0D0D] border-[#333]" min="1" max="5" step="0.5" />
                                    </FormControl>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />

                        <FormField
                            control={form.control}
                            name="review"
                            render={({ field }) => (
                                <FormItem>
                                    <FormLabel>Review Content</FormLabel>
                                    <FormControl>
                                        <Textarea {...field} className="bg-[#0D0D0D] border-[#333] min-h-[100px]" placeholder="Write the customer's testimonial here..." />
                                    </FormControl>
                                    <FormMessage />
                                </FormItem>
                            )}
                        />

                        <FormField
                            control={form.control}
                            name="isActive"
                            render={({ field }) => (
                                <FormItem className="flex items-center justify-between rounded-lg border border-[#333] p-3 shadow-sm">
                                    <div className="space-y-0.5">
                                        <FormLabel>Show on Website</FormLabel>
                                        <div className="text-[0.8rem] text-gray-500">
                                            Toggle to show/hide this review from the homepage.
                                        </div>
                                    </div>
                                    <FormControl>
                                        <Switch
                                            checked={field.value}
                                            onCheckedChange={field.onChange}
                                        />
                                    </FormControl>
                                </FormItem>
                            )}
                        />

                        <DialogFooter className="pt-4">
                            <Button type="button" variant="ghost" onClick={onClose} className="hover:bg-[#333] text-white">
                                Cancel
                            </Button>
                            <Button type="submit" disabled={isLoading} className="is-active hover:bg-[#86efac]/90">
                                {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                                {review ? "Save Changes" : "Create Review"}
                            </Button>
                        </DialogFooter>
                    </form>
                </Form>
            </DialogContent>
        </Dialog>
    )
}
