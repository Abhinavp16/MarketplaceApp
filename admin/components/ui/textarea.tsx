import * as React from 'react'

import { cn } from '@/lib/utils'

function Textarea({ className, ...props }: React.ComponentProps<'textarea'>) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        'border border-blue-200 bg-white px-3 py-2 text-base text-slate-900 placeholder:text-slate-400 focus-visible:border-blue-500 focus-visible:ring-blue-200 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:border-input dark:bg-input/30 dark:text-foreground dark:placeholder:text-muted-foreground dark:focus-visible:border-ring dark:focus-visible:ring-ring/50 flex field-sizing-content min-h-16 w-full rounded-md shadow-xs transition-[color,box-shadow] outline-none focus-visible:ring-[3px] disabled:cursor-not-allowed disabled:opacity-50 md:text-sm',
        className,
      )}
      {...props}
    />
  )
}

export { Textarea }
