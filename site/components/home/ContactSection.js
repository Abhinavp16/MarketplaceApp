'use client';
import { useState } from 'react';
import DemoFormStatus from '@/components/DemoFormStatus';
import ScrollReveal from '@/components/ScrollReveal';
import { ADDRESS, CONTACT_EMAIL, CONTACT_PHONE } from '@/lib/site-config';

export default function ContactSection() {
    const [submitted, setSubmitted] = useState(false);

    // Demo: nothing is sent anywhere; the form is cleared and a confirmation is shown.
    const handleSubmit = (e) => {
        e.preventDefault();
        e.currentTarget.reset();
        setSubmitted(true);
    };

    return (
        <section id="contact" className="overflow-hidden bg-[#e0e7ff] px-4 py-16 sm:px-6 sm:py-24 lg:px-7">
            <div className="relative mx-auto max-w-7xl rounded-[2.4rem] bg-[#17153b] p-5 shadow-[0_28px_80px_rgba(30,27,75,0.18)] sm:p-8 lg:p-12">
                <div className="grid grid-cols-1 items-center gap-10 lg:grid-cols-2 lg:gap-16">
                    <ScrollReveal>
                        <div className="mb-5 inline-flex rounded-full border border-white/15 bg-white/5 px-4 py-2 text-xs font-semibold text-white/80 sm:mb-6">
                            Connect with Experts
                        </div>
                        <h2 className="mb-7 max-w-[12ch] break-words text-4xl font-semibold leading-[1.04] tracking-[-0.024em] text-white sm:text-5xl lg:text-6xl">
                            Ready to place your next demo order?
                        </h2>

                        <div className="space-y-6 sm:space-y-8">
                            <div className="flex items-start gap-4 sm:gap-6">
                                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white/8 text-white sm:h-14 sm:w-14">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
                                    </svg>
                                </div>
                                <div>
                                    <p className="mb-1 text-sm font-bold uppercase text-white/45">Sales Helpline (demo)</p>
                                    <div className="space-y-1">
                                        <p className="break-words text-xl font-bold leading-tight text-white sm:text-2xl">{CONTACT_PHONE}</p>
                                        <p className="text-sm font-semibold text-white/50">Placeholder number</p>
                                    </div>
                                </div>
                            </div>
                            <div className="flex items-start gap-4 sm:gap-6">
                                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white/8 text-white sm:h-14 sm:w-14">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <rect width="20" height="16" x="2" y="4" rx="2" />
                                        <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                                    </svg>
                                </div>
                                <div>
                                    <p className="mb-1 text-sm font-bold uppercase text-white/45">Email</p>
                                    <p className="break-all text-lg font-bold text-white underline decoration-white/25 decoration-2 underline-offset-8 sm:text-2xl">
                                        {CONTACT_EMAIL}
                                    </p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4 sm:gap-6">
                                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-white/8 text-white sm:h-14 sm:w-14">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" />
                                        <circle cx="12" cy="10" r="3" />
                                    </svg>
                                </div>
                                <div>
                                    <p className="mb-1 text-sm font-bold uppercase text-white/45">Address</p>
                                    <p className="text-base font-medium text-white/75 sm:text-lg">
                                        {ADDRESS}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </ScrollReveal>

                    <ScrollReveal>
                        <div className="relative rounded-[2rem] bg-[#eef2ff] p-5 shadow-2xl sm:rounded-[2.4rem] sm:p-8">
                            <form onSubmit={handleSubmit} className="space-y-5 sm:space-y-6">
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <div>
                                        <label className="mb-2 block text-xs font-bold uppercase text-[#5b6079]">Your Name</label>
                                        <input
                                            type="text"
                                            name="name"
                                            suppressHydrationWarning
                                            className="w-full rounded-2xl border border-[#312e81]/10 bg-white/60 px-5 py-4 text-gray-900 outline-none transition-all focus:border-brand-primary focus:bg-white focus:ring-4 focus:ring-brand-primary/10"
                                            placeholder="Alex Sample"
                                        />
                                    </div>
                                    <div>
                                        <label className="mb-2 block text-xs font-bold uppercase text-[#5b6079]">Phone Number</label>
                                        <input
                                            type="tel"
                                            name="phone"
                                            suppressHydrationWarning
                                            className="w-full rounded-2xl border border-[#312e81]/10 bg-white/60 px-5 py-4 text-gray-900 outline-none transition-all focus:border-brand-primary focus:bg-white focus:ring-4 focus:ring-brand-primary/10"
                                            placeholder="+91 00000 00000"
                                        />
                                    </div>
                                </div>
                                <div>
                                    <label className="mb-2 block text-xs font-bold uppercase text-[#5b6079]">Category of Interest</label>
                                    <select name="category" suppressHydrationWarning className="w-full appearance-none rounded-2xl border border-[#312e81]/10 bg-white/60 px-5 py-4 text-gray-900 outline-none transition-all focus:border-brand-primary focus:bg-white focus:ring-4 focus:ring-brand-primary/10">
                                        <option>Personal Use</option>
                                        <option>Bulk Inquiry</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="mb-2 block text-xs font-bold uppercase text-[#5b6079]">Your Message</label>
                                    <textarea
                                        name="message"
                                        suppressHydrationWarning
                                        className="min-h-[120px] w-full rounded-2xl border border-[#312e81]/10 bg-white/60 px-5 py-4 text-gray-900 outline-none transition-all focus:border-brand-primary focus:bg-white focus:ring-4 focus:ring-brand-primary/10"
                                        placeholder="I would like pricing and availability for a sample product."
                                    />
                                </div>
                                <DemoFormStatus submitted={submitted} />
                                <button
                                    type="submit"
                                    className="group/submit relative w-full overflow-hidden rounded-2xl bg-brand-primary py-5 font-bold text-white shadow-xl transition-all duration-300 hover:bg-brand-secondary active:scale-[0.98]"
                                >
                                    <span className="relative z-10 flex items-center justify-center gap-2">
                                        Send Demo Inquiry
                                        <svg className="group-hover/submit:translate-x-1 group-hover/submit:-translate-y-1 transition-transform" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                            <line x1="22" y1="2" x2="11" y2="13"></line>
                                            <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
                                        </svg>
                                    </span>
                                    <div className="absolute inset-0 bg-white/10 translate-x-[-100%] group-hover/submit:translate-x-[100%] transition-transform duration-700 skew-x-[-20deg]"></div>
                                </button>
                            </form>
                        </div>
                    </ScrollReveal>
                </div>
            </div>
        </section>
    );
}
