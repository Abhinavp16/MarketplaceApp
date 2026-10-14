'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Icon from '@/components/Icon';
import {
    ArrowRight02Icon,
    Call02Icon,
    Cancel01Icon,
    Facebook01Icon,
    InstagramIcon,
    Mail01Icon,
} from '@hugeicons/core-free-icons';
import { CONTACT_EMAIL, CONTACT_PHONE, CONTACT_PHONE_HREF } from '@/lib/site-config';

const contactItems = [
    {
        label: 'Email',
        value: CONTACT_EMAIL,
        href: `mailto:${CONTACT_EMAIL}`,
        color: 'text-[#1e1b4b]',
        icon: (
            <Icon icon={Mail01Icon} size={19} />
        ),
    },
    {
        label: 'Phone',
        value: CONTACT_PHONE,
        href: CONTACT_PHONE_HREF,
        color: 'text-[#0d9488]',
        icon: (
            <Icon icon={Call02Icon} size={19} />
        ),
    },
];

const socialItems = [
    {
        label: 'Instagram',
        href: '/contact',
        icon: (
            <Icon icon={InstagramIcon} size={19} />
        ),
    },
    {
        label: 'Facebook',
        href: '/contact',
        icon: (
            <Icon icon={Facebook01Icon} size={18} />
        ),
    },
];

// compact: smaller dark-green version for the floating navbar.
export default function ContactMorphButton({ compact = false }) {
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
        <div ref={containerRef} className={`contact-morph relative z-40 transition-[width,height] duration-300 ${compact ? 'h-11 w-[164px]' : 'h-14 w-[188px]'} ${open ? 'is-open' : ''}`}>
            <button
                type="button"
                onClick={() => setOpen(true)}
                className={`group flex h-full w-full items-center justify-between whitespace-nowrap rounded-full p-1 font-medium transition-all duration-300 ${compact ? 'bg-[#1e1b4b] pl-5 text-sm text-white shadow-[0_10px_24px_-8px_rgba(30,27,75,0.6)]' : 'bg-white pl-6 text-[15px] text-[#17153b] shadow-[0_16px_36px_rgba(0,0,0,0.18)]'} ${open ? `pointer-events-none ${closing ? 'opacity-100' : 'scale-95 opacity-0 blur-sm'}` : 'opacity-100 hover:-translate-y-0.5'}`}
                aria-expanded={open}
                aria-label="Open contact options"
            >
                Quick Contact
                <span className={`ml-3 flex shrink-0 items-center justify-center rounded-full transition-colors ${compact ? 'h-9 w-9 bg-white/15 text-white group-hover:bg-white group-hover:text-[#1e1b4b]' : 'h-12 w-12 border border-[#1e1b4b]/20 bg-[#f5f6ff] text-[#1e1b4b] group-hover:bg-[#1e1b4b] group-hover:text-white'}`}>
                    <Icon icon={ArrowRight02Icon} size={19} strokeWidth={1.7} />
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
                                <Icon icon={Cancel01Icon} size={18} />
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
