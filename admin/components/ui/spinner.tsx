import { Loader2Icon } from "@/components/hugeicons"

import { cn } from '@/lib/utils'

type SpinnerProps = Omit<React.ComponentProps<'svg'>, 'strokeWidth'> & {
  strokeWidth?: number
}

function Spinner({ className, ...props }: SpinnerProps) {
  return (
    <Loader2Icon
      role="status"
      aria-label="Loading"
      className={cn('size-4 animate-spin', className)}
      {...props}
    />
  )
}

export { Spinner }
