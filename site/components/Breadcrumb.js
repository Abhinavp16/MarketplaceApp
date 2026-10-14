import Link from 'next/link';
import Icon from '@/components/Icon';
import { ArrowRight01Icon } from '@hugeicons/core-free-icons';

export default function Breadcrumb({ items }) {
    return (
        <nav className="flex items-center gap-2 text-sm text-text-secondary mb-6">
            <Link href="/" className="hover:text-brand-primary transition-colors">
                Home
            </Link>
            {items.map((item, i) => (
                <span key={i} className="flex items-center gap-2">
                    <Icon icon={ArrowRight01Icon} size={14} strokeWidth={2} />
                    {item.href ? (
                        <Link href={item.href} className="hover:text-brand-primary transition-colors">
                            {item.label}
                        </Link>
                    ) : (
                        <span className="text-brand-primary font-semibold">{item.label}</span>
                    )}
                </span>
            ))}
        </nav>
    );
}
