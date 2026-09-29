'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { CONTACT_EMAIL, CONTACT_PHONE, CONTACT_PHONE_HREF } from '@/lib/site-config';

const contactItems = [
    {
        label: 'Email',
        value: CONTACT_EMAIL,
        href: `mailto:${CONTACT_EMAIL}`,
        color: 'text-[#1e1b4b]',
        icon: (
            <svg xmlns="http://www.w3.org/2000/svg" width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M4 4h16v16H4z" />
                <path d="m4 7 8 6 8-6" />
            </svg>
        ),
    },
    {
        label: 'Phone',
        value: CONTACT_PHONE,
        href: CONTACT_PHONE_HREF,
        color: 'text-[#0d9488]',
        icon: (
            <svg xmlns="http://www.w3.org/2000/svg" width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.78 19.78 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.78 19.78 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.32 1.77.59 2.61a2 2 0 0 1-.45 2.11L8 9.69a16 16 0 0 0 6.31 6.31l1.25-1.25a2 2 0 0 1 2.11-.45c.84.27 1.71.47 2.61.59A2 2 0 0 1 22 16.92Z" />
            </svg>
        ),
    },
];

const socialItems = [
    {
        label: 'Instagram',
        href: '/contact',
        icon: (
            <svg xmlns="http://www.w3.org/2000/svg" width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="3" width="18" height="18" rx="5" />
                <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z" />
                <path d="M17.5 6.5h.01" />
            </svg>
        ),
    },
    {
        label: 'Facebook',
        href: '/contact',
        icon: (
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" />
            </svg>
        ),
    },
];

export default function ContactMorphButton() {
    const [open, setOpen] = useState(false);
    const [closing, setClosing] = useState(false);
    const containerRef = useRef(null);

    const closePanel = () => {
        setClosing(true);

        window.setTimeout(() => {
            setOpen(false);
            setClosing(false);
        }, 440);
    };

    useEffect(() => {
        if (!open || closing) return undefined;

        const handlePointerDown = (event) => {
            if (!containerRef.current?.contains(event.target)) {
                closePanel();
            }
        };

        document.addEventListener('pointerdown', handlePointerDown);
        return () => document.removeEventListener('pointerdown', handlePointerDown);
    }, [open, closing]);

    return (
        <div ref={containerRef} className={`contact-morph relative z-40 h-14 w-[178px] ${open ? 'is-open' : ''}`}>
            <button
                type="button"
                onClick={() => setOpen(true)}
                className={`group flex h-14 w-[178px] items-center justify-between rounded-full bg-white p-1 pl-6 text-[15px] font-medium text-[#16143a] shadow-[0_16px_36px_rgba(0,0,0,0.18)] transition-all duration-300 ${open ? `pointer-events-none ${closing ? 'opacity-100' : 'scale-95 opacity-0 blur-sm'}` : 'opacity-100 hover:-translate-y-0.5'}`}
                aria-expanded={open}
                aria-label="Open contact options"
            >
                        Quick Contact
                <span className="ml-4 flex h-12 w-12 items-center justify-center rounded-full border border-[#1e1b4b]/20 bg-[#f5f6ff] text-[#1e1b4b] transition-colors group-hover:bg-[#1e1b4b] group-hover:text-white">
                    <svg xmlns="http://www.w3.org/2000/svg" width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M5 12h14" />
                        <path d="M13 6l6 6-6 6" />
                    </svg>
                </span>
            </button>

            {open && (
                <div className={`contact-morph-panel absolute right-0 top-0 h-[332px] w-[384px] overflow-hidden rounded-[2rem] bg-white p-4 text-[#16143a] shadow-[0_24px_70px_rgba(0,0,0,0.28)] ${closing ? 'is-closing' : ''}`}>
                    <div className="flex h-full flex-col">
                        <div className="flex items-start justify-between gap-4 rounded-[1.45rem] bg-[#f1f3ff] p-4">
                            <div>
                                <p className="text-[11px] font-black uppercase tracking-[0.22em] text-[#4f56a0]">Reach Us</p>
                                <h3 className="mt-1 text-2xl font-medium tracking-[-0.02em] text-[#1e1b4b]">Quick Contact</h3>
                            </div>
                            <button
                                type="button"
                                onClick={closePanel}
                                className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-[#1e1b4b] shadow-sm transition-transform hover:scale-95"
                                aria-label="Close contact options"
                            >
                                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M18 6 6 18M6 6l12 12" />
                                </svg>
                            </button>
                        </div>

                        <div className="mt-4 grid gap-2.5">
                            {contactItems.map((item) => (
                                <a key={item.label} href={item.href} target={item.href.startsWith('http') ? '_blank' : undefined} rel={item.href.startsWith('http') ? 'noopener noreferrer' : undefined} className="contact-morph-item flex items-center gap-3 rounded-2xl bg-white px-3 py-2.5 text-left">
                                    <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#eaedff] ${item.color}`}>{item.icon}</span>
                                    <span className="min-w-0">
                                        <span className="block text-xs font-bold uppercase tracking-[0.14em] text-[#6b7194]">{item.label}</span>
                                        <span className="block truncate text-sm font-semibold text-[#1e1b4b]">{item.value}</span>
                                    </span>
                                </a>
                            ))}
                        </div>

                        <div className="mt-auto flex items-center gap-2 pt-4">
                            {socialItems.map((item) => (
                                <Link key={item.label} href={item.href} className="contact-morph-item flex flex-1 items-center justify-center gap-2 rounded-full bg-[#1e1b4b] px-3 py-3 text-xs font-bold text-white">
                                    {item.icon}
                                    {item.label}
                                </Link>
                            ))}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
