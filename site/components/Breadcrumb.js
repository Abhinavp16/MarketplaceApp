import Link from 'next/link';

export default function Breadcrumb({ items }) {
    return (
        <nav className="flex items-center gap-2 text-sm text-text-secondary mb-6">
            <Link href="/" className="hover:text-brand-primary transition-colors">
                Home
            </Link>
            {items.map((item, i) => (
                <span key={i} className="flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="m9 18 6-6-6-6" />
                    </svg>
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
