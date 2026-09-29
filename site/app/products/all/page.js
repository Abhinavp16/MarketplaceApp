import Link from 'next/link';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import { fallbackProductImage, getAllWebsiteProducts } from '@/lib/catalog-api';

export const metadata = {
    title: 'All Products',
    description: 'Search and browse all products in the demo catalogue (synthetic data).',
};

export default async function AllProductsPage({ searchParams }) {
    const resolvedSearchParams = await searchParams;
    const search = String(resolvedSearchParams?.search || '').trim();
    const products = await getAllWebsiteProducts(search);

    return (
        <div className="page-transition">
            <PageHero
                title="All Products"
                subtitle="Search the complete demo catalogue."
                backHref="/products"
            />

            <section className="mx-auto max-w-7xl px-2.5 pb-10 pt-6 sm:px-6 sm:py-20">
                <ScrollReveal className="mb-3 rounded-[1rem] border border-[#312e81]/10 bg-[#eef2ff]/80 p-2 shadow-[0_10px_26px_rgba(30,27,75,0.08)] sm:mb-8 sm:rounded-[2rem] sm:p-6">
                    <div className="flex flex-col gap-2 sm:gap-4 lg:flex-row lg:items-end lg:justify-between">
                        <div className="hidden sm:block">
                            <p className="text-[10px] font-black uppercase tracking-[0.2em] text-brand-primary sm:text-xs sm:tracking-[0.22em]">Demo Catalogue</p>
                            <h2 className="mt-2 text-2xl font-semibold tracking-[-0.03em] text-text-primary sm:text-4xl">
                                {search ? `Search results for "${search}"` : 'Browse Every Product'}
                            </h2>
                            <p className="mt-1.5 text-xs leading-5 text-text-secondary sm:mt-2 sm:text-sm sm:leading-6">
                                Showing {products.length} product{products.length === 1 ? '' : 's'} from the demo catalogue.
                            </p>
                        </div>
                        <form action="/products/all" className="flex w-full items-center gap-1.5 rounded-full border border-[#312e81]/15 bg-white p-1 shadow-sm sm:flex-row sm:gap-3 sm:border-0 sm:bg-transparent sm:p-0 sm:shadow-none lg:max-w-xl">
                            <input
                                type="search"
                                name="search"
                                defaultValue={search}
                                placeholder="Search by product name, SKU, or description"
                                className="min-h-9 min-w-0 flex-1 rounded-full border-0 bg-transparent px-3 text-[11px] font-medium text-text-primary outline-none placeholder:text-slate-400 sm:min-h-12 sm:border sm:border-[#312e81]/15 sm:bg-white sm:px-5 sm:text-sm sm:transition sm:focus:border-brand-primary sm:focus:ring-4 sm:focus:ring-brand-primary/10"
                            />
                            <button type="submit" aria-label="Search products" className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#17153b] text-white transition hover:bg-brand-primary sm:min-h-12 sm:w-auto sm:px-6 sm:text-sm sm:font-bold">
                                <svg className="h-4 w-4 sm:hidden" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth="2.5" aria-hidden="true">
                                    <path strokeLinecap="round" strokeLinejoin="round" d="m21 21-4.35-4.35m1.35-5.65a7 7 0 1 1-14 0 7 7 0 0 1 14 0Z" />
                                </svg>
                                <span className="hidden sm:inline">Search</span>
                            </button>
                            {search && (
                                <Link href="/products/all" className="inline-flex min-h-10 items-center justify-center rounded-full border border-[#312e81]/15 bg-white px-4 text-xs font-bold text-text-secondary transition hover:text-brand-primary sm:min-h-12 sm:px-5 sm:text-sm">
                                    Clear
                                </Link>
                            )}
                        </form>
                    </div>
                </ScrollReveal>

                <div className="grid grid-cols-2 gap-1.5 sm:grid-cols-3 sm:gap-3 lg:grid-cols-5 xl:grid-cols-6">
                    {products.map((product, index) => {
                        const description = product.shortDescription || product.description || `View details for ${product.name}.`;
                        const brandName = product.brand === 'GENERAL PRODUCTS' ? '' : product.brand;
                        return (
                            <ScrollReveal key={product.id || index} delay={Math.min(index, 12) * 35}>
                                <div className="flex h-full flex-col overflow-hidden rounded-[0.85rem] border border-[#312e81]/10 bg-white p-1.5 shadow-[0_8px_20px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_18px_42px_rgba(30,27,75,0.14)] sm:rounded-[1.1rem] sm:p-2">
                                    <div className="mb-1 aspect-[1.35/1] overflow-hidden rounded-[0.65rem] bg-neutral-surface sm:mb-2 sm:aspect-[1.18/1] sm:rounded-[0.9rem]">
                                        <img src={product.image || fallbackProductImage} alt={product.name} className="h-full w-full object-cover" />
                                    </div>
                                    <div className="flex flex-1 flex-col px-0.5 pb-0.5">
                                        <h3 className="break-words text-[9px] font-bold leading-[1.12] text-text-primary line-clamp-2 sm:min-h-[2.4rem] sm:text-sm sm:leading-tight">{product.name}</h3>
                                        <div className="mt-0.5 space-y-0.5 sm:mt-1.5 sm:space-y-1">
                                            {brandName && (
                                                <div className="inline-flex max-w-full items-center rounded-full border border-brand-primary/15 bg-[#eef2ff] px-1 py-0.5 text-[7px] font-black uppercase tracking-[0.06em] text-brand-primary sm:px-2 sm:text-[9px] sm:tracking-[0.1em]">
                                                    <span className="mr-1 h-1 w-1 shrink-0 rounded-full bg-brand-primary sm:h-1.5 sm:w-1.5" />
                                                    <span className="truncate">{brandName}</span>
                                                </div>
                                            )}
                                            {product.categoryName && (
                                                <p className="line-clamp-1 text-[7.5px] font-semibold leading-3 text-[#4b5578] sm:text-[10px] sm:leading-4">
                                                    <span className="font-black uppercase tracking-[0.1em] text-[#1e1b4b]/55">Category: </span>
                                                    {product.categoryName}
                                                </p>
                                            )}
                                        </div>
                                        <p className="mt-1.5 hidden text-xs leading-5 text-gray-500 sm:line-clamp-2">{description}</p>
                                        <p className="mt-1 text-[7.5px] font-black leading-tight text-brand-primary sm:mt-2 sm:text-xs">MRP: Rs. {Number(product.mrp || product.retailPrice || 0).toLocaleString('en-IN')}</p>
                                        <div className="mt-auto hidden pt-1.5 sm:block">
                                            <Link href={product.href} className="block w-full rounded-md border border-gray-200 bg-neutral-surface py-1.5 text-center text-[9.5px] font-bold text-text-secondary transition hover:border-brand-primary hover:text-brand-primary sm:rounded-xl sm:py-2 sm:text-xs">
                                                View Details
                                            </Link>
                                        </div>
                                    </div>
                                </div>
                            </ScrollReveal>
                        );
                    })}

                    {products.length === 0 && (
                        <div className="rounded-[2rem] border border-dashed border-gray-300 bg-white/70 p-10 text-center sm:col-span-3 lg:col-span-5 xl:col-span-6">
                            <h3 className="text-2xl font-primary font-bold text-text-primary">No products found</h3>
                            <p className="mt-3 text-text-secondary">Try a different product name, brand, SKU, or category. If the list is always empty, make sure the demo backend is running.</p>
                        </div>
                    )}
                </div>
            </section>
        </div>
    );
}
