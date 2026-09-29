import Link from 'next/link';
import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import ProductImageGallery from '@/components/ProductImageGallery';
import ProductVariantShowcase from '@/components/products/ProductVariantShowcase';
import VariantAwareInquiryButton from '@/components/products/VariantAwareInquiryButton';
import {
    buildFeaturedProductInquiryProps,
    featuredProductFallbackImage,
    findFeaturedProductBySlug,
    getFeaturedDescription,
    getFeaturedProducts,
} from '@/lib/featured-products';

export async function generateMetadata({ params }) {
    const resolvedParams = await params;
    const products = await getFeaturedProducts();
    const product = findFeaturedProductBySlug(products, resolvedParams.slug);

    return {
        title: product ? product.name : 'Product Details',
        description: product ? getFeaturedDescription(product) : 'View detailed product information and request the latest price.',
    };
}

export default async function FeaturedProductDetailPage({ params }) {
    const resolvedParams = await params;
    const products = await getFeaturedProducts();
    const product = findFeaturedProductBySlug(products, resolvedParams.slug);

    if (!product) {
        return (
            <div className="page-transition min-h-[60vh] flex flex-col items-center justify-center px-6 text-center">
                <h1 className="mb-6 text-4xl font-primary font-bold text-text-primary md:text-5xl">Product Not Found</h1>
                <p className="mb-8 text-lg text-text-secondary">We could not find the product you were looking for.</p>
                <Link
                    href="/products"
                    className="rounded-full bg-brand-primary px-8 py-3 font-bold text-white shadow-cta transition-colors hover:bg-brand-secondary"
                >
                    Back to Products
                </Link>
            </div>
        );
    }

    const inquiryProps = buildFeaturedProductInquiryProps(product);
    const productKey = product.slug || product.name;

    return (
        <div className="page-transition">
            <PageHero
                title={product.name}
                backHref="/products"
            />

            <section className="mx-auto max-w-7xl px-6 py-24">
                <div className="grid grid-cols-1 items-start gap-10 lg:grid-cols-2">
                    <ScrollReveal>
                        <div className="relative">
                            <ProductImageGallery
                                images={product.images?.length > 0 ? product.images : [product.image || featuredProductFallbackImage]}
                                name={product.name}
                                productKey={productKey}
                            />
                            {product.badge && (
                                <div className={`absolute left-10 top-10 rounded-xl px-3 py-2 text-[10px] font-bold uppercase tracking-[0.14em] shadow-sm z-20 ${product.badgeStyle || 'border border-teal-100 bg-white text-brand-primary'}`}>
                                    {product.badge}
                                </div>
                            )}
                        </div>
                    </ScrollReveal>

                    <ScrollReveal>
                        <div className="rounded-[2.3rem] border border-gray-100 bg-white p-8 shadow-[0_18px_50px_rgba(15,23,42,0.08)]">
                            <div className="inline-flex rounded-full border border-teal-100 bg-teal-50 px-4 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] text-brand-primary">
                                Product Details
                            </div>

                            <h2 className="mt-5 text-4xl font-primary font-bold leading-tight text-text-primary">
                                {product.name}
                            </h2>

                            <p className="mt-5 text-2xl font-black text-brand-primary">
                                {product.price}
                            </p>

                            {/* Always show short description if available */}
                            {product.shortDescription && (
                                <p className="mt-6 text-base leading-8 text-text-secondary">
                                    {product.shortDescription}
                                </p>
                            )}

                            {/* Show description if no short description */}
                            {!product.shortDescription && product.description && (
                                <p className="mt-6 text-base leading-8 text-text-secondary">
                                    {product.description}
                                </p>
                            )}

                            <ProductVariantShowcase
                                product={product}
                                productKey={productKey}
                            />

                            {/* Always show Key Features if available */}
                            {product.specs.length > 0 && (
                                <div className="mt-8 rounded-[1.9rem] bg-neutral-surface p-6">
                                    <h3 className="text-[11px] font-bold uppercase tracking-[0.2em] text-brand-primary">
                                        Key Features
                                    </h3>
                                    <ul className="mt-4 space-y-3">
                                        {product.specs.slice(0, 4).map((spec, index) => (
                                            <li key={index} className="flex items-start gap-3 text-sm leading-7 text-text-secondary">
                                                <span className="mt-2 h-2 w-2 shrink-0 rounded-full bg-brand-primary" />
                                                <span>{spec}</span>
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            )}

                            <div className="mt-10">
                                <VariantAwareInquiryButton
                                    productKey={productKey}
                                    {...inquiryProps}
                                    className="inline-flex w-full items-center justify-center rounded-2xl bg-gradient-to-r from-brand-primary to-brand-secondary px-6 py-4 text-center text-sm font-bold text-white shadow-[0_14px_30px_rgba(13,148,136,0.26)] transition-all duration-300 hover:-translate-y-0.5 hover:shadow-[0_18px_36px_rgba(13,148,136,0.34)]"
                                >
                                    Get Latest Price
                                </VariantAwareInquiryButton>
                            </div>

                        </div>
                    </ScrollReveal>
                </div>
            </section>
        </div>
    );
}
