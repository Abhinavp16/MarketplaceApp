'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import ContactMorphButton from '@/components/ContactMorphButton';

const navLinks = [
    { href: '/about', label: 'About Us' },
    { href: '/products', label: 'Products' },
    { href: '/dealership', label: 'Dealership' },
    { href: '/contact', label: 'Contact Us' },
];

function isLinkActive(pathname, href) {
    if (href === '/products') {
        return pathname === '/products'
            || pathname.startsWith('/products/')
            || pathname.startsWith('/category/')
            || pathname.startsWith('/brand/');
    }
    return pathname === href;
}

export default function SiteNavbar() {
    const [mobileOpen, setMobileOpen] = useState(false);
    const pathname = usePathname();

    return (
        <div className="pointer-events-none fixed inset-x-0 top-0 z-50 px-4 pt-[72px] sm:px-6 sm:pt-20 lg:px-7 lg:pt-[92px]">
            <nav className="pointer-events-auto relative z-20 flex w-full items-center justify-between px-5 text-white sm:px-8 lg:px-10">
                <Link href="/" className="group flex items-center gap-3">
                    <span className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-full bg-[#ffffff] text-[#1e1b4b] shadow-[0_10px_30px_rgba(0,0,0,0.18)] sm:h-14 sm:w-14">
                        <img src="/logo-mark.png" alt="TradeHub Demo" className="h-10 w-10 rounded-full object-cover sm:h-11 sm:w-11" />
                    </span>
                    <span className="text-xl font-semibold tracking-[-0.04em] text-white drop-shadow-[0_2px_12px_rgba(0,0,0,0.45)] sm:text-2xl">TradeHub Demo</span>
                </Link>

                <div className="hidden items-center gap-8 text-[15px] font-medium lg:flex">
                    {navLinks.map((link) => {
                        const active = isLinkActive(pathname, link.href);
                        return (
                            <Link
                                key={`${link.href}-${link.label}`}
                                href={link.href}
                                aria-current={active ? 'page' : undefined}
                                className={`transition-colors ${active ? 'text-white underline decoration-white/70 decoration-2 underline-offset-8' : 'text-white/85 hover:text-white'}`}
                            >
                                {link.label}
                            </Link>
                        );
                    })}
                </div>

                <div className="hidden items-center lg:flex">
                    <ContactMorphButton />
                </div>

                <button
                    type="button"
                    onClick={() => setMobileOpen((open) => !open)}
                    className="flex h-12 w-12 items-center justify-center rounded-full bg-white/95 text-[#1e1b4b] shadow-[0_16px_36px_rgba(0,0,0,0.18)] lg:hidden"
                    aria-label="Toggle menu"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                        {mobileOpen ? <path d="M18 6 6 18M6 6l12 12" /> : <path d="M4 7h16M4 12h16M4 17h16" />}
                    </svg>
                </button>

                {mobileOpen && (
                    <div className="absolute left-0 right-0 top-[4.25rem] z-30 rounded-[1.6rem] border border-white/20 bg-[#f5f6ff]/95 p-3 shadow-2xl backdrop-blur-xl sm:top-24 lg:hidden">
                        {navLinks.map((link) => {
                            const active = isLinkActive(pathname, link.href);
                            return (
                                <Link
                                    key={`${link.href}-${link.label}-mobile`}
                                    href={link.href}
                                    onClick={() => setMobileOpen(false)}
                                    className={`block rounded-2xl px-4 py-3 text-sm font-semibold ${active ? 'bg-[#1e1b4b] text-white' : 'text-[#1e1b4b] hover:bg-[#e0e7ff]'}`}
                                >
                                    {link.label}
                                </Link>
                            );
                        })}
                    </div>
                )}
            </nav>
        </div>
    );
}
