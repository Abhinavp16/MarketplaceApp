import Link from 'next/link';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import { getBrandCategories } from '@/lib/catalog-api';

export async function generateMetadata({ params }) {
    const resolvedParams = await params;
    const { brand } = await getBrandCategories(resolvedParams.brandSlug);
    return {
        title: brand ? brand.name : 'Brand',
        description: brand ? `Browse ${brand.name} categories and products.` : 'Browse brand products.',
    };
}

export default async function BrandPage({ params }) {
    const resolvedParams = await params;
    const { brand, categories } = await getBrandCategories(resolvedParams.brandSlug);

    if (!brand) {
        return (
            <div className="page-transition min-h-[60vh] flex flex-col items-center justify-center text-center px-6">
                <h1 className="text-4xl md:text-5xl font-primary font-bold text-text-primary mb-6">Brand Not Found</h1>
                <p className="text-text-secondary text-lg mb-8">We could not find the brand you were looking for.</p>
                <Link href="/products" className="px-8 py-3 bg-brand-primary text-white font-bold rounded-full hover:bg-brand-secondary transition-colors shadow-cta">
                    Back to Products
                </Link>
            </div>
        );
    }

    return (
        <div className="page-transition">
            <PageHero title={brand.name} subtitle={brand.description || `Browse ${brand.name} categories.`} backHref="/products" />

            <section className="px-6 pb-14 pt-6 sm:py-24">
                <div className="mx-auto max-w-7xl">
                    <ScrollReveal className="mb-10 hidden text-center sm:mb-16 sm:block">
                        <h2 className="mb-3 text-xs font-bold uppercase tracking-[0.24em] text-brand-primary sm:mb-4 sm:text-sm sm:tracking-[0.3em]">Brand Categories</h2>
                        <h3 className="text-3xl font-primary font-bold leading-tight text-text-primary md:text-5xl">{brand.name} Products</h3>
                        <p className="mx-auto mt-4 max-w-2xl text-sm leading-6 text-text-secondary sm:mt-6 sm:text-base">Choose a category to view products from this brand only.</p>
                    </ScrollReveal>

                    <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6 lg:gap-4">
                        {categories.map((cat, i) => (
                            <ScrollReveal key={cat.id || i} delay={i * 80}>
                                <div className="group flex h-full flex-col overflow-hidden rounded-[1.35rem] border border-[#312e81]/10 bg-[#eef2ff]/85 p-2 shadow-[0_16px_40px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_22px_55px_rgba(30,27,75,0.14)]">
                                    <div className="relative aspect-[4/3] overflow-hidden rounded-[1.2rem] bg-[#c7d2fe]">
                                        <img src={cat.image} className="h-full w-full object-cover object-center transition-transform duration-500 group-hover:scale-105" alt={cat.name} />
                                        <div className="absolute inset-x-3 top-3 flex justify-end">
                                            <span className="rounded-full bg-white/90 px-3 py-1 text-[11px] font-black uppercase tracking-[0.14em] text-[#1e1b4b] shadow-sm backdrop-blur-sm">
                                                {cat.productCount ? `${cat.productCount} Items` : 'Category'}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="flex min-h-[100px] flex-grow flex-col px-1.5 py-3">
                                        <h4 className="text-text-primary text-sm font-semibold leading-tight tracking-[-0.018em] sm:text-base">{cat.name}</h4>
                                        <p className="mt-2 line-clamp-2 text-xs leading-5 text-text-secondary">{cat.description || `View ${cat.name} products from ${brand.name}.`}</p>
                                        <Link href={cat.href} className="mt-auto flex items-center justify-between border-t border-[#312e81]/10 pt-2.5 text-[11px] font-semibold text-brand-primary">
                                            <span>View Products</span>
                                            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-white/70 text-[#1e1b4b] transition-colors group-hover:bg-[#1e1b4b] group-hover:text-white">→</span>
                                        </Link>
                                    </div>
                                </div>
                            </ScrollReveal>
                        ))}
                    </div>
                </div>
            </section>
        </div>
    );
}
