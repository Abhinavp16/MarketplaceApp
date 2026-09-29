import Link from 'next/link';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import FeaturedProductCard from '@/components/products/FeaturedProductCard';
import { getWebsiteContent } from '@/lib/website-content';
import { CONTACT_PHONE, CONTACT_PHONE_HREF } from '@/lib/site-config';
import { fallbackCategoryImage } from '@/lib/catalog-api';

export const metadata = {
    title: 'Products',
    description: 'Browse the demo catalogue: power tools, hand tools, fasteners and fittings, and safety gear (synthetic data).',
};

export const dynamic = 'force-dynamic';

function slugifyCategoryName(name = '') {
    return encodeURIComponent(String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-')).replace(/^-|-$/g, '');
}

export default async function ProductsPage() {
    const { brands, productCategories, featuredProducts, categoriesSection, featuredSection } = await getWebsiteContent();
    const partnerLogos = brands.map((brand) => ({ label: brand.name }));

    return (
        <div className="page-transition">
            <PageHero
                title="Our Products"
                subtitle="Browse categories from the demo catalogue."
                breadcrumbItems={['Products']}
            />

            {partnerLogos.length > 0 && (
            <section className="hidden px-6 pt-4 sm:block sm:pt-10">
                <ScrollReveal className="mx-auto max-w-7xl">
                    <div className="relative overflow-hidden text-[#16143a] [mask-image:linear-gradient(90deg,transparent,black_12%,black_88%,transparent)]">
                        <div className="brand-marquee-track flex w-max items-center gap-10 sm:gap-14 lg:gap-18">
                            {[...partnerLogos, ...partnerLogos].map((partner, index) => (
                                <div key={`${partner.label}-${index}`} className="shrink-0 rounded-full border border-[#1e1b4b]/18 bg-[#eef2ff]/60 px-6 py-3 text-[#1e1b4b]/75 shadow-[inset_0_1px_0_rgba(255,255,255,0.55)]">
                                    <span className="whitespace-nowrap text-xl font-black tracking-[-0.018em] sm:text-2xl">{partner.label}</span>
                                </div>
                            ))}
                        </div>
                    </div>
                    <p className="mt-4 text-center text-lg font-medium tracking-[-0.018em] text-[#1e1b4b] sm:mt-7 sm:text-2xl">
                        Demo Brands
                    </p>
                </ScrollReveal>
            </section>
            )}

            <section className="pb-14 pt-8 sm:py-24 bg-neutral-surface">
                <div className="max-w-7xl mx-auto px-4 sm:px-6">
                    <ScrollReveal className="mb-7 flex flex-col items-center text-center sm:mb-16 md:items-start md:text-left">
                        <div>
                            <h3 className="mx-auto max-w-[15ch] text-center text-[2.15rem] font-primary font-bold leading-[1.05] tracking-[-0.024em] text-text-primary sm:max-w-[18ch] sm:text-4xl md:mx-0 md:text-left md:text-5xl">{featuredSection.title}</h3>
                        </div>
                    </ScrollReveal>

                    {featuredProducts.length === 0 && (
                        <div className="rounded-[2rem] border border-dashed border-gray-300 bg-white/70 p-10 text-center">
                            <h4 className="text-2xl font-primary font-bold text-text-primary">No featured products yet</h4>
                            <p className="mt-3 text-text-secondary">Products load from the demo backend. Start it and refresh this page.</p>
                        </div>
                    )}
                    <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-5 lg:gap-4">
                        {featuredProducts.map((product, i) => (
                            <ScrollReveal key={i} delay={i * 100} className={i >= 4 ? 'hidden sm:block' : ''}>
                                <FeaturedProductCard product={product} />
                            </ScrollReveal>
                        ))}
                    </div>
                    <ScrollReveal className="mt-10 flex justify-center">
                        <Link href="/products/all" className="inline-flex min-h-12 items-center justify-center rounded-full border border-[#312e81]/15 bg-white px-7 text-sm font-bold text-brand-primary shadow-sm transition hover:-translate-y-0.5 hover:bg-[#17153b] hover:text-white">
                            View All Products
                        </Link>
                    </ScrollReveal>
                </div>
            </section>

            <section className="px-6 pb-14 pt-6 sm:py-24">
                <div className="mx-auto max-w-7xl">
                <ScrollReveal className="mb-4 text-center sm:hidden">
                    <h3 className="text-lg font-bold tracking-[-0.02em] text-text-primary">Explore Our Vast Categories</h3>
                </ScrollReveal>
                <ScrollReveal className="mb-10 hidden text-center sm:mb-16 sm:block">
                    <h2 className="mb-3 text-xs font-bold uppercase tracking-[0.24em] text-brand-primary sm:mb-4 sm:text-sm sm:tracking-[0.3em]">{categoriesSection.eyebrow}</h2>
                    <h3 className="text-3xl font-primary font-bold leading-tight text-text-primary md:text-5xl">{categoriesSection.title}</h3>
                    <p className="mx-auto mt-4 max-w-2xl text-sm leading-6 text-text-secondary sm:mt-6 sm:text-base">{categoriesSection.description}</p>
                </ScrollReveal>

                {productCategories.length === 0 && (
                    <div className="rounded-[2rem] border border-dashed border-gray-300 bg-white/70 p-10 text-center">
                        <h4 className="text-2xl font-primary font-bold text-text-primary">Catalogue unavailable</h4>
                        <p className="mt-3 text-text-secondary">No categories were returned. Start the demo backend and refresh this page.</p>
                    </div>
                )}
                <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6 lg:gap-4">
                    {productCategories.map((cat, i) => (
                        <ScrollReveal key={i} delay={i * 80}>
                            <div className="group flex h-full flex-col overflow-hidden rounded-[1.35rem] border border-[#312e81]/10 bg-[#eef2ff]/85 p-2 shadow-[0_16px_40px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_22px_55px_rgba(30,27,75,0.14)]">
                                <div className="relative aspect-[4/3] overflow-hidden rounded-[1.2rem] bg-[#c7d2fe]">
                                    <img src={cat.image || fallbackCategoryImage} className="h-full w-full object-cover object-center transition-transform duration-500 group-hover:scale-105" alt={cat.name} />
                                    <div className="absolute inset-x-3 top-3 flex justify-end">
                                        <span className="rounded-full bg-white/90 px-3 py-1 text-[11px] font-black uppercase tracking-[0.14em] text-[#1e1b4b] shadow-sm backdrop-blur-sm">
                                            {Number.isFinite(cat.productCount) && cat.productCount > 0 ? `${cat.productCount} Items` : (Array.isArray(cat.products) && cat.products.length > 0 ? `${cat.products.length} Items` : 'Category')}
                                        </span>
                                    </div>
                                </div>
                                <div className="flex min-h-[100px] flex-grow flex-col px-1.5 py-3">
                                    <h4 className="text-text-primary text-sm font-semibold leading-tight tracking-[-0.018em] sm:text-base">{cat.name}</h4>
                                    <p className="mt-2 line-clamp-2 text-xs leading-5 text-text-secondary">{cat.description}</p>
                                    <Link href={cat.href || `/category/${slugifyCategoryName(cat.name)}`} className="mt-auto flex items-center justify-between border-t border-[#312e81]/10 pt-2.5 text-[11px] font-semibold text-brand-primary">
                                        <span>{categoriesSection.buttonText || 'View Products'}</span>
                                        <span className="flex h-7 w-7 items-center justify-center rounded-full bg-white/70 text-[#1e1b4b] transition-colors group-hover:bg-[#1e1b4b] group-hover:text-white">→</span>
                                    </Link>
                                </div>
                            </div>
                        </ScrollReveal>
                    ))}
                </div>
                </div>
            </section>

            <section className="py-24 bg-brand-primary relative overflow-hidden">
                <div className="absolute top-0 right-0 w-96 h-96 bg-white/10 rounded-full blur-[120px]" />
                <div className="max-w-4xl mx-auto px-6 text-center relative z-10">
                    <ScrollReveal>
                        <h2 className="text-4xl md:text-5xl font-primary font-bold text-white mb-6">Need Bulk Orders?</h2>
                        <p className="text-white/80 text-lg mb-10 max-w-2xl mx-auto">Placeholder call to action: ask about dealer pricing, commercial quantities and distribution partnerships.</p>
                        <div className="flex flex-wrap justify-center gap-4">
                            <Link href="/contact" className="px-8 py-4 bg-white text-brand-primary rounded-full font-bold hover:bg-gray-100 transition-all">
                                Request Bulk Quote
                            </Link>
                            <a href={CONTACT_PHONE_HREF} className="px-8 py-4 bg-white/10 backdrop-blur-md border border-white/20 text-white rounded-full font-bold hover:bg-white/20 transition-all">
                                Call: {CONTACT_PHONE}
                            </a>
                        </div>
                    </ScrollReveal>
                </div>
            </section>
        </div>
    );
}
