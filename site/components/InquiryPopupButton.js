'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { DEMO_CONTACT_HINT, DEMO_INQUIRY_CONFIRMATION } from '@/lib/inquiry';

export default function InquiryPopupButton({
    productName,
    price = '',
    details = [],
    className = '',
    ariaLabel,
    children,
}) {
    const [open, setOpen] = useState(false);
    const [name, setName] = useState('');
    const [phone, setPhone] = useState('');
    const [showToast, setShowToast] = useState(false);
    const [mounted, setMounted] = useState(false);
    const fieldId = useId();
    const timerRef = useRef(null);

    useEffect(() => {
        // eslint-disable-next-line react-hooks/set-state-in-effect -- portal must only render after mount
        setMounted(true);
        return () => {
            if (timerRef.current) {
                clearTimeout(timerRef.current);
            }
        };
    }, []);

    const handleSend = (e) => {
        e.preventDefault();

        if (!name.trim() || !phone.trim()) {
            return;
        }

        // Demo: nothing is sent or stored. Just clear the form and confirm.
        setName('');
        setPhone('');
        setOpen(false);
        setShowToast(true);
        if (timerRef.current) {
            clearTimeout(timerRef.current);
        }
        timerRef.current = setTimeout(() => {
            setShowToast(false);
        }, 5000);
    };

    return (
        <>
            <button
                type="button"
                onClick={() => setOpen(true)}
                className={className}
                aria-label={ariaLabel}
            >
                {children}
            </button>

            {mounted && createPortal(
                <>
                    {open && (
                        <div className="fixed inset-0 z-[9999]">
                            <div className="absolute inset-0 bg-black/60 backdrop-blur-md" onClick={() => setOpen(false)} />

                            <div className="absolute left-1/2 top-1/2 w-[min(92vw,560px)] -translate-x-1/2 -translate-y-1/2">
                                <div className="rounded-[28px] bg-gradient-to-br from-white/80 via-white/40 to-white/80 p-[1px] shadow-[0_35px_90px_rgba(0,0,0,0.45)]">
                                    <div className="relative max-h-[84vh] overflow-y-auto rounded-[27px] bg-white p-6 md:p-7">
                                        <div className="absolute right-4 top-4">
                                            <button
                                                type="button"
                                                onClick={() => setOpen(false)}
                                                className="w-8 h-8 rounded-lg border border-gray-200 text-text-secondary hover:bg-gray-50"
                                                aria-label="Close inquiry popup"
                                            >
                                                x
                                            </button>
                                        </div>

                                        <div className="text-center">
                                            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-teal-100 bg-teal-50 px-3 py-1 text-[11px] font-bold text-teal-700">
                                                Demo Inquiry
                                            </div>
                                            <h3 className="text-3xl font-extrabold text-text-primary">Product Inquiry</h3>
                                            <p className="mt-1 text-sm text-text-secondary">Fill in sample details to see the inquiry flow. Nothing is sent or stored in this demo.</p>
                                        </div>

                                        <form onSubmit={handleSend} className="mt-5 space-y-3.5 text-center">
                                            <div className="mx-auto max-w-md">
                                                <label htmlFor={`${fieldId}-name`} className="mb-1.5 block text-center text-sm font-semibold text-text-primary">
                                                    Name
                                                </label>
                                                <input
                                                    id={`${fieldId}-name`}
                                                    type="text"
                                                    value={name}
                                                    onChange={(e) => setName(e.target.value)}
                                                    placeholder="Enter your name"
                                                    required
                                                    className="w-full rounded-xl border border-gray-200 px-4 py-2.5 text-center outline-none focus:ring-2 focus:ring-brand-primary/30"
                                                />
                                            </div>

                                            <div className="mx-auto max-w-md">
                                                <label htmlFor={`${fieldId}-phone`} className="mb-1.5 block text-center text-sm font-semibold text-text-primary">
                                                    Mobile Number
                                                </label>
                                                <input
                                                    id={`${fieldId}-phone`}
                                                    type="tel"
                                                    value={phone}
                                                    onChange={(e) => setPhone(e.target.value)}
                                                    placeholder="Enter mobile number"
                                                    required
                                                    className="w-full rounded-xl border border-gray-200 px-4 py-2.5 text-center outline-none focus:ring-2 focus:ring-brand-primary/30"
                                                />
                                            </div>

                                            <div className="mx-auto max-w-md">
                                                <label className="mb-1.5 block text-center text-sm font-semibold text-text-primary">Product</label>
                                                <input
                                                    type="text"
                                                    value={productName}
                                                    readOnly
                                                    className="w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-2.5 text-center text-text-secondary"
                                                />
                                            </div>

                                            {price && (
                                                <div className="mx-auto max-w-md">
                                                    <label className="mb-1.5 block text-center text-sm font-semibold text-text-primary">Price</label>
                                                    <input
                                                        type="text"
                                                        value={price}
                                                        readOnly
                                                        className="w-full rounded-xl border border-gray-200 bg-gray-50 px-4 py-2.5 text-center text-text-secondary"
                                                    />
                                                </div>
                                            )}

                                            {details.length > 0 && (
                                                <div className="mx-auto max-w-md">
                                                    <label className="mb-1.5 block text-center text-sm font-semibold text-text-primary">Product Details</label>
                                                    <textarea
                                                        rows={3}
                                                        value={details.map((item) => `- ${item}`).join('\n')}
                                                        readOnly
                                                        className="w-full resize-none rounded-xl border border-gray-200 bg-gray-50 px-4 py-2.5 text-center text-text-secondary"
                                                    />
                                                </div>
                                            )}

                                            <button
                                                type="submit"
                                                className="mx-auto w-full max-w-md rounded-xl bg-gradient-to-r from-brand-primary to-brand-dark py-3 font-bold text-white shadow-lg shadow-brand-primary/30 transition-all hover:brightness-110"
                                            >
                                                Submit Demo Inquiry
                                            </button>
                                            <p className="mx-auto max-w-md text-xs text-text-secondary">{DEMO_CONTACT_HINT}</p>
                                        </form>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}

                    {showToast && (
                        <div className="fixed left-1/2 top-5 z-[10000] -translate-x-1/2 rounded-lg bg-teal-600 px-4 py-3 text-white shadow-lg">
                            {DEMO_INQUIRY_CONFIRMATION}
                        </div>
                    )}
                </>,
                document.body
            )}
        </>
    );
}
