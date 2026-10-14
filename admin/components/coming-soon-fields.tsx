"use client"

import type { Control } from "react-hook-form"
import { Clock } from "@/components/hugeicons"
import { Checkbox } from "@/components/ui/checkbox"
import { FormControl, FormDescription, FormField, FormItem, FormLabel } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Switch } from "@/components/ui/switch"

// Form fields this card uses (flat, so react-hook-form can bind them).
export interface ComingSoonFormValues {
    comingSoonEnabled: boolean
    comingSoonShowPrice: boolean
    comingSoonExpectedDate: string
    comingSoonAutoLaunch: boolean
}

interface ComingSoonFieldsProps {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    control: Control<any>
    enabled: boolean
    hasDate: boolean
    // People who tapped "Notify me" (edit mode).
    notifyCount: number
    wasComingSoon: boolean
}

/** "2026-10-15" for a date input, from a stored date. */
export function toDateInputValue(value?: string | Date | null) {
    if (!value) return ""
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return ""
    return date.toISOString().slice(0, 10)
}

/** Payload for the API from the flat form values. */
export function comingSoonPayload(values: ComingSoonFormValues) {
    return {
        enabled: values.comingSoonEnabled,
        showPrice: values.comingSoonShowPrice,
        expectedDate: values.comingSoonEnabled && values.comingSoonExpectedDate
            ? new Date(`${values.comingSoonExpectedDate}T00:00:00`).toISOString()
            : null,
        autoLaunch: values.comingSoonEnabled && Boolean(values.comingSoonExpectedDate) && values.comingSoonAutoLaunch,
    }
}

// Listed in the app with a "Coming Soon" badge but not for sale yet.
export function ComingSoonFields({ control, enabled, hasDate, notifyCount, wasComingSoon }: ComingSoonFieldsProps) {
    return (
        <div className="space-y-3 rounded-lg border border-sky-500/30 bg-sky-500/5 p-3" data-testid="coming-soon-card">
            <FormField
                control={control}
                name="comingSoonEnabled"
                render={({ field }) => (
                    <FormItem className="flex items-center justify-between">
                        <div className="space-y-0.5">
                            <FormLabel className="text-white flex items-center gap-2">
                                <Clock className="h-4 w-4 text-sky-400" />
                                Coming Soon
                            </FormLabel>
                            <FormDescription className="text-xs text-gray-500">
                                Show in the app with a Coming Soon badge. It can&apos;t be ordered yet; buyers can tap &quot;Notify me&quot;.
                            </FormDescription>
                        </div>
                        <FormControl>
                            <Switch aria-label="Coming Soon" checked={field.value} onCheckedChange={field.onChange} />
                        </FormControl>
                    </FormItem>
                )}
            />

            {enabled && (
                <div className="space-y-3 border-t border-sky-500/20 pt-3">
                    <FormField
                        control={control}
                        name="comingSoonShowPrice"
                        render={({ field }) => (
                            <FormItem className="flex items-center justify-between">
                                <div className="space-y-0.5">
                                    <FormLabel className="text-white">Show price</FormLabel>
                                    <FormDescription className="text-xs text-gray-500">
                                        Off: buyers see &quot;Price coming soon&quot;.
                                    </FormDescription>
                                </div>
                                <FormControl>
                                    <Switch aria-label="Show price" checked={field.value} onCheckedChange={field.onChange} />
                                </FormControl>
                            </FormItem>
                        )}
                    />
                    <FormField
                        control={control}
                        name="comingSoonExpectedDate"
                        render={({ field }) => (
                            <FormItem>
                                <FormLabel className="text-white">Expected date (optional)</FormLabel>
                                <FormControl>
                                    <Input
                                        type="date"
                                        aria-label="Expected date"
                                        {...field}
                                        className="bg-[#0D0D0D] border-[#333] text-white"
                                    />
                                </FormControl>
                                <FormDescription className="text-xs text-gray-500">
                                    Shown to buyers as &quot;Expected …&quot;.
                                </FormDescription>
                            </FormItem>
                        )}
                    />
                    <FormField
                        control={control}
                        name="comingSoonAutoLaunch"
                        render={({ field }) => (
                            <FormItem className="flex items-start gap-2">
                                <FormControl>
                                    <Checkbox
                                        aria-label="Go live automatically on this date"
                                        checked={field.value && hasDate}
                                        disabled={!hasDate}
                                        onCheckedChange={(checked) => field.onChange(checked === true)}
                                    />
                                </FormControl>
                                <div className="space-y-0.5">
                                    <FormLabel className="text-white text-sm">Go live automatically on this date</FormLabel>
                                    <FormDescription className="text-xs text-gray-500">
                                        {hasDate ? "Becomes orderable by itself; everyone waiting is notified." : "Pick an expected date first."}
                                    </FormDescription>
                                </div>
                            </FormItem>
                        )}
                    />
                </div>
            )}

            {(wasComingSoon || notifyCount > 0) && (
                <p className="text-xs text-sky-300" data-testid="notify-count">
                    {notifyCount === 1 ? "1 person asked" : `${notifyCount} people asked`} to be notified when it launches
                    {wasComingSoon && !enabled && notifyCount > 0 ? " — they'll be notified when you save." : "."}
                </p>
            )}
        </div>
    )
}
