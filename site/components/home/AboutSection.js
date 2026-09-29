import ScrollReveal from '@/components/ScrollReveal';

const fallbackProductImages = ['/demo/about/about-product.png', '/demo/about/about-card.png'];
const aboutCardImage = '/demo/about/about-card.png';

export default function AboutSection({ productImages = fallbackProductImages }) {
    const images = productImages.filter(Boolean).length > 0 ? productImages.filter(Boolean) : fallbackProductImages;
    const firstImage = images[0] || fallbackProductImages[0];

    return (
        <section id="about" className="overflow-hidden bg-[#e0e7ff] px-4 py-16 sm:px-6 sm:py-24 lg:px-7">
            <div className="mx-auto grid max-w-7xl grid-cols-1 gap-12 lg:grid-cols-2 lg:gap-20">
                <ScrollReveal>
                    <div className="home-kicker">Who We Are</div>
                    <h2 className="mt-5 max-w-xl text-4xl font-semibold leading-[1.02] tracking-[-0.024em] text-text-primary sm:text-5xl lg:text-6xl">
                        Comprehensive <br /> Distribution Solutions
                    </h2>
                    <p className="mt-7 max-w-xl text-base leading-8 text-text-secondary sm:text-lg">
                        TradeHub Demo is a fictional distributor. This placeholder text stands in for a short company introduction: who you serve, what you supply, and how ordering works for retailers, dealers and bulk buyers.
                    </p>

                    <div className="mt-10 space-y-4">
                        <div className="flex items-center gap-4 rounded-[1.6rem] border border-[#312e81]/10 bg-[#eef2ff]/70 p-5 shadow-[0_18px_50px_rgba(30,27,75,0.06)] transition-colors hover:border-[#312e81]/25">
                            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-[#312e81] text-sm font-bold text-white shadow-sm">
                                D2B
                            </div>
                            <div>
                                <h4 className="font-bold tracking-[-0.02em] text-text-primary">Bulk Wholesaling</h4>
                                <p className="mt-1 text-sm leading-6 text-text-secondary">Placeholder: volume pricing and consistent supply for retailers, dealers and resellers.</p>
                            </div>
                        </div>
                        <div className="flex items-center gap-4 rounded-[1.6rem] border border-[#312e81]/10 bg-[#eef2ff]/70 p-5 shadow-[0_18px_50px_rgba(30,27,75,0.06)] transition-colors hover:border-[#312e81]/25">
                            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-[#312e81] text-sm font-bold text-white shadow-sm">
                                D2C
                            </div>
                            <div>
                                <h4 className="font-bold tracking-[-0.02em] text-text-primary">Direct Retail</h4>
                                <p className="mt-1 text-sm leading-6 text-text-secondary">Placeholder: direct purchasing for individual and small-business buyers.</p>
                            </div>
                        </div>
                    </div>
                </ScrollReveal>

                <ScrollReveal className="relative">
                    <div className="grid min-h-0 grid-cols-1 gap-4 sm:min-h-[620px] sm:grid-cols-2 sm:gap-5">
                        <div className="space-y-4 sm:pt-12">
                            <div className="rounded-[1.6rem] border border-[#312e81]/10 bg-[#eef2ff]/80 p-5 shadow-sm">
                                <p className="mb-1 text-[10px] font-bold uppercase tracking-[0.15em] text-brand-primary">Regional Reach</p>
                                <p className="text-sm font-semibold leading-6 text-text-primary">Sample copy describing your regional coverage.</p>
                            </div>
                            <img
                                src={firstImage}
                                className="h-auto w-full rounded-[2rem] object-cover object-center shadow-[0_24px_70px_rgba(30,27,75,0.12)] sm:h-[300px]"
                                alt="Demo product illustration"
                            />
                            <div className="rounded-[1.6rem] bg-brand-primary p-6 text-white">
                                <p className="mb-1 text-3xl font-semibold tracking-[-0.018em]">Demo Data</p>
                                <p className="text-xs uppercase tracking-[0.14em] text-white/70">Synthetic sample content</p>
                            </div>
                            <div className="rounded-[1.6rem] border border-[#312e81]/10 bg-[#eef2ff]/80 p-5 shadow-sm">
                                <p className="mb-1 text-[10px] font-bold uppercase tracking-[0.15em] text-brand-primary">Fast Dispatch</p>
                                <p className="text-sm font-semibold leading-6 text-text-primary">Sample copy describing dispatch and fulfilment.</p>
                            </div>
                        </div>
                        <div className="space-y-4">
                            <div className="rounded-[2rem] bg-[#17153b] p-8 text-center text-white">
                                <p className="mb-2 text-5xl font-semibold tracking-[-0.018em]">N/A</p>
                                <p className="text-[10px] font-bold uppercase tracking-widest text-white/50">Placeholder metric</p>
                            </div>
                            <img
                                src={aboutCardImage}
                                className="h-auto w-full rounded-[2rem] object-cover object-center shadow-[0_24px_70px_rgba(30,27,75,0.12)] sm:h-[300px]"
                                alt="Demo warehouse illustration"
                            />
                            <div className="rounded-[1.6rem] border border-[#312e81]/10 bg-[#eef2ff]/80 p-5 shadow-sm">
                                <p className="mb-1 text-[10px] font-bold uppercase tracking-[0.15em] text-brand-primary">Core Team</p>
                                <p className="text-sm font-semibold leading-6 text-text-primary">Sample copy describing the team and support model.</p>
                            </div>
                        </div>
                    </div>
                    <div className="absolute -bottom-10 -right-10 -z-10 h-48 w-48 rounded-full bg-white/30 blur-3xl" />
                </ScrollReveal>
            </div>
        </section>
    );
}
