'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import ContactMorphButton from '@/components/ContactMorphButton';
import Icon from '@/components/Icon';
import { Cancel01Icon, Menu01Icon } from '@hugeicons/core-free-icons';

const navLinks = [
    { href: '/', label: 'Home' },
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

// Pages with a light top (no dark hero image) need dark navbar text.
const LIGHT_TOP_PREFIXES = ['/insights/'];

export default function SiteNavbar() {
    const [mobileOpen, setMobileOpen] = useState(false);
    const pathname = usePathname();
    const [hidden, setHidden] = useState(false);
    const [atTop, setAtTop] = useState(true);
    const progressRef = useRef(null);
    // Mid-page the navbar floats as a light glass pill with dark text.
    const floating = !atTop;
    const darkText = floating || LIGHT_TOP_PREFIXES.some((prefix) => pathname.startsWith(prefix));

    // Hide while scrolling down, show again on a small scroll up.
    useEffect(() => {
        let lastY = window.scrollY;
        const update = () => {
            const y = window.scrollY;
            const scrollable = document.documentElement.scrollHeight - window.innerHeight;
            if (progressRef.current) {
                progressRef.current.style.transform = `scaleX(${scrollable > 0 ? Math.min(y / scrollable, 1) : 0})`;
            }
            setAtTop(y < 40);
            if (y < 80) {
                setHidden(false);
            } else if (y > lastY + 6) {
                setHidden(true);
                setMobileOpen(false);
            } else if (y < lastY - 6) {
                setHidden(false);
            } else {
                return;
            }
            lastY = y;
        };
        update();
        window.addEventListener('scroll', update, { passive: true });
        return () => window.removeEventListener('scroll', update);
    }, []);

    return (
        <div
            className={`pointer-events-none fixed inset-x-0 top-0 z-50 transition-[transform,padding] duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] motion-reduce:transition-none ${hidden ? '-translate-y-[130%]' : 'translate-y-0'} ${floating ? 'px-3 pt-3 sm:px-5 sm:pt-4' : 'px-4 pt-[72px] sm:px-6 sm:pt-20 lg:px-7 lg:pt-[92px]'}`}
        >
            <nav
                className={`pointer-events-auto relative z-20 mx-auto flex w-full items-center justify-between transition-[max-width,padding,background-color,box-shadow] duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] ${darkText ? 'text-[#1e1b4b]' : 'text-white'} ${floating
                    ? 'max-w-[1120px] rounded-full border border-white/70 bg-[#f5f6ff]/80 py-1.5 pl-2 pr-1.5 shadow-[0_20px_50px_-18px_rgba(30,27,75,0.45),inset_0_1px_0_rgba(255,255,255,0.8)] ring-1 ring-[#1e1b4b]/[0.06] backdrop-blur-xl backdrop-saturate-150 sm:pl-2.5 sm:pr-2'
                    : 'max-w-[2400px] px-5 sm:px-8 lg:px-10'}`}
            >
                <Link href="/" className="group flex items-center gap-2.5 sm:gap-3">
                    <span className={`flex items-center justify-center overflow-hidden rounded-full bg-[#f1f3ff] text-[#312e81] transition-all duration-500 ${floating ? 'h-10 w-10 shadow-[0_4px_14px_rgba(30,27,75,0.18)] ring-1 ring-[#1e1b4b]/10' : 'h-12 w-12 shadow-[0_10px_30px_rgba(0,0,0,0.18)] sm:h-14 sm:w-14'}`}>
                        <img src="/logo-mark.png" alt="DemoMart" className={`rounded-full object-cover transition-all duration-500 ${floating ? 'h-8 w-8' : 'h-10 w-10 sm:h-11 sm:w-11'}`} />
                    </span>
                    <span className={`font-semibold tracking-[-0.04em] transition-all duration-500 ${floating ? 'text-lg' : 'text-xl sm:text-2xl'} ${darkText ? 'text-[#1e1b4b]' : 'text-white drop-shadow-[0_2px_12px_rgba(0,0,0,0.45)]'}`}>DemoMart</span>
                </Link>

                <div className={`hidden items-center text-[15px] font-medium lg:flex ${floating ? 'gap-1 rounded-full bg-[#1e1b4b]/[0.05] p-1' : 'gap-8'}`}>
                    {navLinks.map((link) => {
                        const active = isLinkActive(pathname, link.href);
                        let tone;
                        if (floating) {
                            tone = active
                                ? 'rounded-full bg-[#1e1b4b] px-4 py-2 text-white shadow-[0_6px_16px_-6px_rgba(30,27,75,0.7)]'
                                : 'rounded-full px-4 py-2 text-[#1e1b4b]/75 hover:bg-white hover:text-[#1e1b4b] hover:shadow-sm';
                        } else if (darkText) {
                            tone = active ? 'text-[#1e1b4b] underline decoration-[#1e1b4b]/60 decoration-2 underline-offset-8' : 'text-[#1e1b4b]/75 hover:text-[#1e1b4b]';
                        } else {
                            tone = active ? 'text-white underline decoration-white/70 decoration-2 underline-offset-8' : 'text-white/85 hover:text-white';
                        }
                        return (
                            <Link
                                key={`${link.href}-${link.label}`}
                                href={link.href}
                                aria-current={active ? 'page' : undefined}
                                className={`transition-all duration-200 ${tone}`}
                            >
                                {link.label}
                            </Link>
                        );
                    })}
                </div>

                <div className="hidden items-center lg:flex">
                    <ContactMorphButton compact={floating} />
                </div>

                <button
                    type="button"
                    onClick={() => setMobileOpen((open) => !open)}
                    className={`flex items-center justify-center rounded-full transition-all duration-300 lg:hidden ${floating ? 'h-10 w-10 bg-[#1e1b4b] text-white' : 'h-12 w-12 bg-white/95 text-[#1e1b4b] shadow-[0_16px_36px_rgba(0,0,0,0.18)]'}`}
                    aria-label="Toggle menu"
                >
                    <Icon icon={mobileOpen ? Cancel01Icon : Menu01Icon} size={22} />
                </button>

                {mobileOpen && (
                    <div className="absolute left-0 right-0 top-[calc(100%+0.6rem)] z-30 rounded-[1.6rem] border border-[#1e1b4b]/10 bg-[#f5f6ff] p-3 shadow-[0_24px_60px_-20px_rgba(30,27,75,0.5)] lg:hidden">
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

                {/* Scroll progress, shown on the floating pill. */}
                <span aria-hidden="true" className={`pointer-events-none absolute inset-x-8 bottom-0 h-[2px] overflow-hidden rounded-full transition-opacity duration-300 ${floating ? 'opacity-100' : 'opacity-0'}`}>
                    <span
                        ref={progressRef}
                        className="block h-full origin-left rounded-full bg-gradient-to-r from-[#4f46e5] via-[#1e1b4b] to-[#14b8a6]"
                        style={{ transform: 'scaleX(0)' }}
                    />
                </span>
            </nav>
        </div>
    );
}
