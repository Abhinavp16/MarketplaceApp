import { HugeiconsIcon } from '@hugeicons/react';

// Site-wide icon: a Hugeicons icon in the current text colour.
// Usage: <Icon icon={ArrowRight02Icon} size={18} />
export default function Icon({ icon, size = 20, strokeWidth = 1.8, className = '', ...props }) {
    return (
        <HugeiconsIcon
            icon={icon}
            size={size}
            strokeWidth={strokeWidth}
            color="currentColor"
            className={className}
            aria-hidden="true"
            {...props}
        />
    );
}
