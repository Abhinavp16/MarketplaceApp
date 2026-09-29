import Link from 'next/link';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import ProductImageGallery from '@/components/ProductImageGallery';
import ProductVariantShowcase from '@/components/products/ProductVariantShowcase';
import VariantAwareInquiryButton from '@/components/products/VariantAwareInquiryButton';
import VariantAwareSkuChip from '@/components/products/VariantAwareSkuChip';
import {
    buildProductInquiryDetails,
    findCategoryBySlug,
    findProductBySlug,
    formatPrice,
    getCategories,
    getProductHighlights,
    productCardFallbackImage,
} from '@/lib/category-products';

export async function generateMetadata({ params }) {
    const categories = await getCategories();
    const resolvedParams = await params;
    const category = findCategoryBySlug(categories, resolvedParams.slug);
    const product = category ? findProductBySlug(category, resolvedParams.productSlug) : null;

    return {
        title: product ? product.name : 'Product Details',
        description: product?.shortDescription || product?.description || 'View product details and send an inquiry.',
    };
}

export default async function ProductDetailPage({ params }) {
    const categories = await getCategories();
    const resolvedParams = await params;
    const category = findCategoryBySlug(categories, resolvedParams.slug);
    const product = category ? findProductBySlug(category, resolvedParams.productSlug) : null;

    if (!category || !product) {
        return (
            <div className="page-transition min-h-[60vh] flex flex-col items-center justify-center text-center px-6">
                <h1 className="text-4xl md:text-5xl font-primary font-bold text-text-primary mb-6">Product Not Found</h1>
                <p className="text-text-secondary text-lg mb-8">We could not find the product you were looking for.</p>
                <Link
                    href={category ? `/category/${resolvedParams.slug}` : '/products'}
                    className="px-8 py-3 bg-brand-primary text-white font-bold rounded-full hover:bg-brand-secondary transition-colors shadow-cta"
                >
                    Back to Products
                </Link>
            </div>
        );
    }

    const displayPrice = product.mrp ? `MRP: ${formatPrice(product.mrp)}` : formatPrice(product.retailPrice || product.wholesalePrice);
    const highlights = getProductHighlights(product);
    const inquiryDetails = buildProductInquiryDetails(product);
    const productKey = product.productId || product.slug || product.name;

    return (
        <div className="page-transition">
            <PageHero
                title={product.name}
                backHref={`/category/${resolvedParams.slug}`}
            />

            <section className="py-24 px-6 max-w-7xl mx-auto">
                <div className="grid grid-cols-1 lg:grid-cols-[1.05fr_0.95fr] gap-10 items-start">
                    <ScrollReveal>
                        <div className="relative">
                            <ProductImageGallery
                                images={product.images?.length > 0 ? product.images : [product.image || productCardFallbackImage]}
                                name={product.name}
                                displayPrice={displayPrice}
                                productKey={productKey}
                            />
                            {product.badge && (
                                <div className={`absolute left-10 top-10 rounded-xl px-3 py-2 text-[10px] font-bold uppercase tracking-[0.14em] shadow-sm z-20 bg-white text-brand-primary border border-teal-100`}>
                                    {product.badge}
                                </div>
                            )}
                        </div>
                    </ScrollReveal>

                    <ScrollReveal>
                        <div className="rounded-[2.5rem] border border-gray-100 bg-white p-8 shadow-sm">
                            <div className="flex flex-wrap items-center gap-3">
                                <span className="inline-flex items-center rounded-full bg-neutral-surface px-4 py-1.5 text-[11px] font-bold uppercase tracking-[0.24em] text-brand-primary">
                                    {category.name}
                                </span>
                                <span className={`inline-flex items-center rounded-full px-4 py-1.5 text-[11px] font-bold uppercase tracking-[0.24em] ${product.stock > 0 ? 'bg-emerald-50 text-emerald-700' : 'bg-rose-50 text-rose-600'}`}>
                                    {product.stock > 0 ? 'In Stock' : 'Check Availability'}
                                </span>
                            </div>

                            <h2 className="mt-5 text-4xl font-primary font-bold leading-tight text-text-primary">
                                {product.name}
                            </h2>

                            <p className="mt-5 text-base leading-8 text-text-secondary">
                                {product.description || product.shortDescription || `Get full details and support for ${product.name}.`}
                            </p>

                            <ProductVariantShowcase
                                product={product}
                                productKey={productKey}
                            />

                            {highlights.length > 0 && (
                                <div className="mt-8 rounded-[2rem] bg-neutral-surface p-6">
                                    <h3 className="text-[11px] font-bold uppercase tracking-[0.24em] text-brand-primary mb-4">
                                        Key Features
                                    </h3>
                                    <ul className="space-y-3">
                                        {highlights.map((highlight, index) => (
                                            <li key={index} className="flex items-start gap-3 text-sm leading-7 text-text-secondary">
                                                <span className="mt-2 h-2 w-2 shrink-0 rounded-full bg-brand-primary" />
                                                <span>{highlight}</span>
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            )}

                            <div className="mt-8 flex flex-wrap gap-3 text-sm">
                                <VariantAwareSkuChip productKey={productKey} sku={product.sku} />
                            </div>

                            <div className="mt-10">
                                <VariantAwareInquiryButton
                                    productKey={productKey}
                                    productName={product.name}
                                    price={displayPrice}
                                    details={inquiryDetails}
                                    className="inline-flex w-full items-center justify-center rounded-2xl bg-gradient-to-r from-brand-primary to-brand-secondary px-6 py-4 text-center text-sm font-bold text-white shadow-[0_14px_30px_rgba(13,148,136,0.26)] transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_18px_36px_rgba(13,148,136,0.34)]"
                                >
                                    Request Quote
                                </VariantAwareInquiryButton>
                            </div>
                        </div>
                    </ScrollReveal>
                </div>
            </section>
        </div>
    );
}
