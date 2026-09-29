import * as React from 'react'

import { cn } from '@/lib/utils'

function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        'file:text-foreground placeholder:text-slate-400 selection:bg-blue-600 selection:text-white h-9 w-full min-w-0 rounded-md border border-blue-200 bg-white px-3 py-1 text-base text-slate-900 shadow-xs transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm dark:border-input dark:bg-input/30 dark:text-foreground dark:placeholder:text-muted-foreground',
        'focus-visible:border-blue-500 focus-visible:ring-blue-200 focus-visible:ring-[3px] dark:focus-visible:border-ring dark:focus-visible:ring-ring/50',
        'aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive',
        type === 'number' && '[appearance:textfield] [-moz-appearance:textfield] [&::-webkit-inner-spin-button]:m-0 [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:m-0 [&::-webkit-outer-spin-button]:appearance-none',
        className,
      )}
      {...props}
    />
  )
}

export { Input }
