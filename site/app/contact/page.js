'use client';
import { useState } from 'react';
import DemoFormStatus from '@/components/DemoFormStatus';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import { ADDRESS, CONTACT_EMAIL, CONTACT_PHONE, CONTACT_PHONE_HREF } from '@/lib/site-config';

export default function ContactPage() {
    const [submitted, setSubmitted] = useState(false);

    // Demo: nothing is sent anywhere; the form is cleared and a confirmation is shown.
    const handleSubmit = (e) => {
        e.preventDefault();
        e.currentTarget.reset();
        setSubmitted(true);
    };

    return (
        <div className="page-transition">
            <PageHero
                title="Contact Us"
                subtitle="Demo contact page: product enquiries, dealer discussions and bulk supply coordination."
                breadcrumbItems={['Contact Us']}
            />

            <section className="px-6 py-10 max-w-7xl mx-auto sm:py-24">
                <ScrollReveal className="mb-8 text-center sm:mb-12">
                    <h2 className="mb-3 text-xs font-bold uppercase tracking-[0.24em] text-brand-primary sm:mb-4 sm:text-sm sm:tracking-[0.3em]">Get in Touch</h2>
                    <h3 className="text-3xl font-primary font-bold text-text-primary md:text-5xl">Contact Details</h3>
                </ScrollReveal>

                <div className="mb-10 grid grid-cols-1 gap-4 md:grid-cols-3 sm:mb-16 sm:gap-5">
                    <div className="group relative overflow-hidden rounded-[2rem] border border-[#1e1b4b]/10 bg-[#f5f6ff] p-5 text-[#1e1b4b] shadow-[0_20px_55px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_28px_70px_rgba(30,27,75,0.14)] sm:p-7">
                        <div className="absolute inset-x-0 top-0 h-1 bg-[#14b8a6]" />
                        <div className="mb-5 flex items-start justify-between gap-5 sm:mb-7">
                            <div>
                                <p className="mb-3 text-[11px] font-black uppercase tracking-[0.26em] text-[#6b7194]">Direct Connect</p>
                                <h4 className="text-[2rem] font-semibold tracking-[-0.02em] text-[#16143a]">Call Us</h4>
                            </div>
                            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-white text-[#14b8a6] shadow-sm ring-1 ring-[#1e1b4b]/8">
                                <svg xmlns="http://www.w3.org/2000/svg" width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.78 19.78 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.78 19.78 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.32 1.77.59 2.61a2 2 0 0 1-.45 2.11L8 9.69a16 16 0 0 0 6.31 6.31l1.25-1.25a2 2 0 0 1 2.11-.45c.84.27 1.71.47 2.61.59A2 2 0 0 1 22 16.92Z" />
                                </svg>
                            </span>
                        </div>
                        <div className="space-y-3 rounded-[1.35rem] border border-[#1e1b4b]/8 bg-[#ffffff] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.72)]">
                            <div>
                                <p className="text-xs font-bold uppercase tracking-wide text-[#6b7194]">Support calls &amp; product enquiries (placeholder)</p>
                                <a href={CONTACT_PHONE_HREF} className="mt-1 block text-xl font-semibold tracking-tight text-[#1e1b4b]">{CONTACT_PHONE}</a>
                            </div>
                        </div>
                    </div>

                    <div className="group relative overflow-hidden rounded-[2rem] border border-[#1e1b4b]/10 bg-[#f5f6ff] p-5 text-[#1e1b4b] shadow-[0_20px_55px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_28px_70px_rgba(30,27,75,0.14)] sm:p-7">
                        <div className="absolute inset-x-0 top-0 h-1 bg-[#0f766e]" />
                        <div className="mb-5 flex items-start justify-between gap-5 sm:mb-7">
                            <div>
                                <p className="mb-3 text-[11px] font-black uppercase tracking-[0.26em] text-[#6b7194]">Official Desk</p>
                                <h4 className="text-[2rem] font-semibold tracking-[-0.02em] text-[#16143a]">Email Us</h4>
                            </div>
                            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-white text-[#0f766e] shadow-sm ring-1 ring-[#1e1b4b]/8">
                                <svg xmlns="http://www.w3.org/2000/svg" width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <path d="M4 4h16v16H4z" />
                                    <path d="m4 7 8 6 8-6" />
                                </svg>
                            </span>
                        </div>
                        <a href={`mailto:${CONTACT_EMAIL}`} className="block rounded-[1.35rem] border border-[#1e1b4b]/8 bg-[#ffffff] p-4 text-base font-semibold leading-6 text-[#1e1b4b] underline-offset-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.72)] hover:underline sm:text-lg break-all">
                            {CONTACT_EMAIL}
                        </a>
                    </div>

                    <div className="group relative overflow-hidden rounded-[2rem] border border-[#1e1b4b]/10 bg-[#f5f6ff] p-5 text-[#1e1b4b] shadow-[0_20px_55px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_28px_70px_rgba(30,27,75,0.14)] sm:p-7">
                        <div className="absolute inset-x-0 top-0 h-1 bg-[#4b5f9c]" />
                        <div className="mb-5 flex items-start justify-between gap-5 sm:mb-7">
                            <div>
                                <p className="mb-3 text-[11px] font-black uppercase tracking-[0.26em] text-[#6b7194]">Visit Point</p>
                                <h4 className="text-[2rem] font-semibold tracking-[-0.02em] text-[#16143a]">Demo Address</h4>
                            </div>
                            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-white text-[#4b5f9c] shadow-sm ring-1 ring-[#1e1b4b]/8">
                                <svg xmlns="http://www.w3.org/2000/svg" width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                    <path d="M12 21s7-4.4 7-11a7 7 0 1 0-14 0c0 6.6 7 11 7 11Z" />
                                    <path d="M12 12.5A2.5 2.5 0 1 0 12 7a2.5 2.5 0 0 0 0 5.5Z" />
                                </svg>
                            </span>
                        </div>
                        <p className="rounded-[1.35rem] border border-[#1e1b4b]/8 bg-[#ffffff] p-4 text-base font-medium leading-relaxed text-[#3b4266] shadow-[inset_0_1px_0_rgba(255,255,255,0.72)]">
                            {ADDRESS}
                        </p>
                    </div>
                </div>

                <div className="grid grid-cols-1 items-start gap-10 lg:grid-cols-2 lg:gap-16">
                    <ScrollReveal>
                        <div className="rounded-[2rem] border border-gray-100 bg-white p-6 shadow-2xl sm:rounded-[3rem] sm:p-10">
                            <h3 className="text-2xl font-bold text-text-primary mb-2">Send us a Message</h3>
                            <p className="text-text-secondary mb-8">Fill out the form to try the demo flow. Nothing is sent or stored.</p>
                            <form onSubmit={handleSubmit} className="space-y-6">
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <input type="text" name="name" className="w-full px-5 py-4 bg-gray-50 border border-transparent rounded-2xl focus:border-brand-primary focus:bg-white outline-none text-gray-900" placeholder="Alex Sample" required />
                                    <input type="email" name="email" className="w-full px-5 py-4 bg-gray-50 border border-transparent rounded-2xl focus:border-brand-primary focus:bg-white outline-none text-gray-900" placeholder="alex@example.com" />
                                </div>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                                    <input type="tel" name="phone" className="w-full px-5 py-4 bg-gray-50 border border-transparent rounded-2xl focus:border-brand-primary focus:bg-white outline-none text-gray-900" placeholder="+91 00000 00000" required />
                                    <select name="category" className="w-full px-5 py-4 bg-gray-50 border border-transparent rounded-2xl focus:border-brand-primary focus:bg-white outline-none text-gray-900">
                                        <option>Personal Use</option>
                                        <option>Bulk Inquiry</option>
                                        <option>Dealership</option>
                                    </select>
                                </div>
                                <textarea
                                    name="message"
                                    className="w-full px-5 py-4 bg-gray-50 border border-transparent rounded-2xl focus:border-brand-primary focus:bg-white outline-none text-gray-900 min-h-[150px]"
                                    placeholder="Hello, I want product details, pricing, and delivery information."
                                    required
                                />
                                <DemoFormStatus submitted={submitted} />
                                <button type="submit" className="w-full py-5 bg-brand-primary text-white rounded-2xl font-bold hover:bg-brand-secondary transition-all">
                                    Submit Demo Message
                                </button>
                            </form>
                        </div>
                    </ScrollReveal>

                    <ScrollReveal>
                        <div className="sticky top-28 space-y-8">
                            <div className="overflow-hidden rounded-3xl border border-[#1e1b4b]/10 bg-[#f5f6ff] shadow-[0_20px_55px_rgba(30,27,75,0.08)]">
                                <div className="flex h-[400px] w-full flex-col items-center justify-center gap-3 bg-[linear-gradient(135deg,#e0e7ff,#c9e8e4)] px-6 text-center">
                                    <span className="flex h-14 w-14 items-center justify-center rounded-full bg-white text-[#0d9488] shadow-sm">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                            <path d="M12 21s7-4.4 7-11a7 7 0 1 0-14 0c0 6.6 7 11 7 11Z" />
                                            <path d="M12 12.5A2.5 2.5 0 1 0 12 7a2.5 2.5 0 0 0 0 5.5Z" />
                                        </svg>
                                    </span>
                                    <p className="text-lg font-semibold text-[#1e1b4b]">Map placeholder</p>
                                    <p className="text-sm text-[#4b5578]">{ADDRESS}</p>
                                    <p className="text-xs text-[#6b7194]">No third-party map is embedded in this demo.</p>
                                </div>
                            </div>
                            <div className="bg-white p-8 rounded-3xl border border-gray-100 shadow-sm">
                                <h4 className="font-bold text-text-primary mb-4 text-lg">Business Hours (placeholder)</h4>
                                <div className="space-y-3 text-sm">
                                    <div className="flex justify-between"><span className="text-text-secondary">Monday - Friday</span><span className="font-semibold text-text-primary">9:00 AM - 6:00 PM</span></div>
                                    <div className="flex justify-between"><span className="text-text-secondary">Weekends</span><span className="font-semibold text-red-500">Closed</span></div>
                                </div>
                            </div>
                        </div>
                    </ScrollReveal>
                </div>
            </section>
        </div>
    );
}
