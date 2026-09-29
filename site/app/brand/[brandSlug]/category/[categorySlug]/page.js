import Link from 'next/link';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import { getBrandCategoryProducts, fallbackProductImage, slugifyCatalogName } from '@/lib/catalog-api';

export async function generateMetadata({ params }) {
    const resolvedParams = await params;
    const { brand, category } = await getBrandCategoryProducts(resolvedParams.brandSlug, resolvedParams.categorySlug);
    return {
        title: category && brand ? `${category.name} - ${brand.name}` : 'Category Products',
        description: category ? category.description || `Browse ${category.name} products.` : 'Browse category products.',
    };
}

export default async function BrandCategoryPage({ params }) {
    const resolvedParams = await params;
    const { brand, category, products } = await getBrandCategoryProducts(resolvedParams.brandSlug, resolvedParams.categorySlug);

    if (!brand || !category) {
        return (
            <div className="page-transition min-h-[60vh] flex flex-col items-center justify-center text-center px-6">
                <h1 className="text-4xl md:text-5xl font-primary font-bold text-text-primary mb-6">Category Not Found</h1>
                <p className="text-text-secondary text-lg mb-8">We could not find the category you were looking for.</p>
                <Link href="/products" className="px-8 py-3 bg-brand-primary text-white font-bold rounded-full hover:bg-brand-secondary transition-colors shadow-cta">Back to Products</Link>
            </div>
        );
    }

    return (
        <div className="page-transition">
            <PageHero title={category.name} subtitle={`${brand.name} products`} backHref={`/brand/${resolvedParams.brandSlug}`} />

            <section className="py-24 px-6 max-w-7xl mx-auto">
                <ScrollReveal className="mb-12">
                    <h2 className="text-3xl md:text-4xl font-primary font-bold text-text-primary mb-4">All Products in {category.name}</h2>
                    <p className="text-text-secondary">Browse {brand.name} products in this category.</p>
                </ScrollReveal>

                <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-6">
                    {products.map((product, index) => {
                        const cardDescription = product.shortDescription || product.description || `Explore ${product.name} with sample specifications for demonstration.`;
                        return (
                            <ScrollReveal key={product.id || index} delay={index * 80}>
                                <div className="flex h-full flex-col overflow-hidden rounded-[1.5rem] border border-gray-100 bg-white p-3 shadow-sm">
                                    <div className="mb-3 aspect-square overflow-hidden rounded-[1.2rem] bg-neutral-surface">
                                        <img src={product.image || fallbackProductImage} alt={product.name} className="h-full w-full object-cover" />
                                    </div>
                                    <div className="flex flex-1 flex-col px-1 pb-1">
                                        <h3 className="break-words text-[0.74rem] font-bold leading-[1.12] text-text-primary line-clamp-2 sm:min-h-[3.25rem] sm:text-base sm:leading-tight">{product.name}</h3>
                                        <div className="mt-1 space-y-0.5 sm:mt-2 sm:space-y-1">
                                            <div className="inline-flex max-w-full items-center rounded-full border border-brand-primary/15 bg-[#eef2ff] px-1.5 py-0.5 text-[7.5px] font-black uppercase tracking-[0.08em] text-brand-primary sm:px-2 sm:text-[9px] sm:tracking-[0.1em]">
                                                <span className="mr-1 h-1.5 w-1.5 shrink-0 rounded-full bg-brand-primary" />
                                                <span className="truncate">{brand.name}</span>
                                            </div>
                                            <p className="line-clamp-1 text-[8px] font-semibold leading-3 text-[#4b5578] sm:text-[10px] sm:leading-4">
                                                <span className="font-black uppercase tracking-[0.1em] text-[#1e1b4b]/55">Category: </span>
                                                {category.name}
                                            </p>
                                        </div>
                                        <p className="mt-2 hidden min-h-[4.5rem] text-sm leading-6 text-gray-500 sm:line-clamp-3">{cardDescription}</p>
                                        <p className="mt-2 text-[10px] font-black leading-tight text-brand-primary sm:text-sm">MRP: ₹{Number(product.mrp || product.retailPrice || 0).toLocaleString('en-IN')}</p>
                                        <div className="mt-auto hidden pt-4 sm:block">
                                            <Link href={`/brand/${resolvedParams.brandSlug}/category/${resolvedParams.categorySlug}/${product.slug || slugifyCatalogName(product.name)}`} className="block w-full rounded-2xl border border-gray-200 bg-neutral-surface py-3 text-center text-sm font-bold text-text-secondary">View Product Details</Link>
                                        </div>
                                    </div>
                                </div>
                            </ScrollReveal>
                        );
                    })}
                </div>
            </section>
        </div>
    );
}
