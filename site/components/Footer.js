import Link from 'next/link';
import { ADDRESS, CONTACT_EMAIL, CONTACT_PHONE, CONTACT_PHONE_HREF, LEGAL_NAME, SITE_NAME, TAGLINE } from '@/lib/site-config';

const policyLinks = [
    { name: 'Terms', href: '/terms' },
    { name: 'Privacy', href: '/privacy' },
    { name: 'Delete Account', href: '/delete-account' },
    { name: 'Shipping', href: '/shipping' },
    { name: 'Refund', href: '/refund' },
    { name: 'Warranty', href: '/warranty' },
    { name: 'Dealer', href: '/dealer-agreement' },
    { name: 'Pricing', href: '/dealer-pricing' },
];

const socialLinks = [
    { name: 'facebook', icon: 'M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z', href: '/contact' },
    { name: 'instagram', icon: 'M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z', href: '/contact' },
    { name: 'youtube', icon: 'M2.5 17a24.12 24.12 0 0 1 0-10 2 2 0 0 1 1.4-1.4 49.56 49.56 0 0 1 16.2 0A2 2 0 0 1 21.5 7a24.12 24.12 0 0 1 0 10 2 2 0 0 1-1.4 1.4 49.55 49.55 0 0 1-16.2 0A2 2 0 0 1 2.5 17', href: '/contact' },
];

export default function Footer() {
    return (
        <footer className="relative overflow-hidden bg-[#12102e] px-6 pb-6 pt-12 text-white sm:pt-14">
            <div className="absolute -left-24 top-0 h-72 w-72 rounded-full bg-[#e0e7ff]/10 blur-[110px]" />
            <div className="absolute -right-32 bottom-0 h-96 w-96 rounded-full bg-[#0d9488]/18 blur-[130px]" />
            <div className="footer-gold-orb absolute left-[12%] top-16 h-44 w-44 rounded-full bg-[#14b8a6]/18 blur-[54px]" />
            <div className="footer-gold-orb footer-gold-orb-slow absolute bottom-20 right-[18%] h-56 w-56 rounded-full bg-[#5eead4]/14 blur-[66px]" />

            <div className="relative z-10 mx-auto max-w-7xl">
                <div className="grid grid-cols-1 gap-10 border-b border-white/10 pb-10 lg:grid-cols-2">
                    <div>
                        <h2 className="max-w-xl text-3xl font-semibold leading-tight tracking-[-0.028em] text-white md:text-4xl">
                            {SITE_NAME} — {TAGLINE}
                        </h2>

                        <div className="mt-7 grid gap-4 text-sm text-[#c7cdf0] sm:grid-cols-2">
                            <div className="flex items-center gap-3">
                                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#e0e7ff]/12 text-[#e0e7ff]">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M20 6 9 17l-5-5" />
                                    </svg>
                                </span>
                                <span className="font-medium">Demo placeholder content</span>
                            </div>
                            <div className="flex items-center gap-3">
                                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#e0e7ff]/12 text-[#e0e7ff]">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M21 12V7H5a2 2 0 0 1 0-4h14v4" />
                                        <path d="M3 5v14a2 2 0 0 0 2 2h16v-5" />
                                        <path d="M18 12a2 2 0 0 0 0 4h4v-4Z" />
                                    </svg>
                                </span>
                                <span className="font-medium">Delivery arrangements confirmed per order</span>
                            </div>
                            <a href={CONTACT_PHONE_HREF} className="flex items-center gap-3 transition-colors hover:text-white">
                                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#e0e7ff]/12 text-[#e0e7ff]">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.78 19.78 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.78 19.78 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.32 1.77.59 2.61a2 2 0 0 1-.45 2.11L8 9.69a16 16 0 0 0 6.31 6.31l1.25-1.25a2 2 0 0 1 2.11-.45c.84.27 1.71.47 2.61.59A2 2 0 0 1 22 16.92Z" />
                                    </svg>
                                </span>
                                <span className="font-medium">Support: {CONTACT_PHONE}</span>
                            </a>
                                                        <a href={`mailto:${CONTACT_EMAIL}`} className="flex min-w-0 items-center gap-3 transition-colors hover:text-white">
                                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#e0e7ff]/12 text-[#e0e7ff]">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                        <rect width="20" height="16" x="2" y="4" rx="2" />
                                        <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                                    </svg>
                                </span>
                                <span className="truncate font-medium">{CONTACT_EMAIL}</span>
                            </a>
                        </div>
                    </div>

                    <div className="lg:justify-self-end">
                        <p className="max-w-xl text-base leading-7 text-[#c7cdf0]">
                            A fictional distribution business used to demonstrate a catalogue, dealer and ordering website. Products, prices, brands and people shown here are synthetic sample data.
                        </p>
                        <div className="mt-6 flex flex-wrap gap-3">
                            <a href={`mailto:${CONTACT_EMAIL}`} className="rounded-full border border-white/14 bg-white/8 px-5 py-3 text-sm font-semibold text-white transition-all hover:-translate-y-0.5 hover:bg-[#e0e7ff] hover:text-[#1e1b4b]">
                                Email Us
                            </a>
                            <a href={CONTACT_PHONE_HREF} className="rounded-full bg-[#e0e7ff] px-5 py-3 text-sm font-semibold text-[#1e1b4b] transition-all hover:-translate-y-0.5 hover:bg-white">
                                Call Now
                            </a>
                        </div>
                    </div>
                </div>

                <div className="flex flex-col items-center gap-5 border-b border-white/10 py-9">
                    <span className="text-xs font-black uppercase tracking-[0.24em] text-[#a5abd0]">Follow Us (demo links)</span>
                    <div className="flex gap-4">
                        {socialLinks.map((social) => (
                            <a key={social.name} href={social.href} aria-label={social.name} className="flex h-[3.25rem] w-[3.25rem] items-center justify-center rounded-full border border-white/10 bg-white/8 text-[#dfe3fa] shadow-lg transition-all hover:-translate-y-1 hover:bg-[#e0e7ff] hover:text-[#1e1b4b]">
                                <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
                                    <path d={social.icon} />
                                    {social.name === 'instagram' && (
                                        <>
                                            <rect width="20" height="20" x="2" y="2" rx="5" ry="5" />
                                            <line x1="17.5" x2="17.51" y1="6.5" y2="6.5" />
                                        </>
                                    )}
                                    {social.name === 'youtube' && <path d="m10 15 5-3-5-3z" />}
                                </svg>
                            </a>
                        ))}
                    </div>
                </div>

                <div className="flex flex-col gap-6 pt-8 lg:flex-row lg:items-center lg:justify-between">
                    <div>
                        <Link href="/" className="inline-flex items-center gap-3 text-xl font-semibold tracking-[-0.02em] text-white">
                            <span className="flex h-11 w-11 items-center justify-center rounded-full bg-[#ffffff] shadow-lg">
                                <img src="/logo-mark.png" alt={SITE_NAME} className="h-8 w-8 rounded-full object-contain" />
                            </span>
                            <span>TradeHub <span className="text-[#5eead4]">Demo</span></span>
                        </Link>
                        <p className="mt-2 text-xs font-medium text-[#a5abd0]">{ADDRESS}</p>
                    </div>

                    <div className="flex flex-wrap gap-x-6 gap-y-2 text-xs font-bold uppercase tracking-[0.16em] text-[#a5abd0]">
                        {policyLinks.map((item) => (
                            <Link key={item.name} href={item.href} className="transition-colors hover:text-white">
                                {item.name}
                            </Link>
                        ))}
                    </div>
                </div>

                <div className="mt-8 text-center text-xs font-medium text-[#8a90b5]">
                    <p suppressHydrationWarning>{`Copyright ${new Date().getFullYear()} ${LEGAL_NAME}. Demonstration environment — synthetic data.`}</p>
                </div>
            </div>
        </footer>
    );
}
