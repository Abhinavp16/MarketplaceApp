import Link from 'next/link';
import {
    featuredProductFallbackImage,
    getFeaturedDescription,
    normalizeFeaturedProduct,
    slugifyFeaturedProduct,
} from '@/lib/featured-products';

export default function FeaturedProductCard({
    product,
    href,
}) {
    const normalizedProduct = normalizeFeaturedProduct(product);
    const productHref = href || normalizedProduct.href || `/products/${slugifyFeaturedProduct(normalizedProduct)}`;
    const cardDescription = getFeaturedDescription(normalizedProduct);
    const brandName = normalizedProduct.brand === 'GENERAL PRODUCTS' ? '' : normalizedProduct.brand;
    const categoryName = normalizedProduct.categoryName;

    return (
        <div className="group mx-auto flex h-full w-full max-w-[340px] flex-col overflow-hidden rounded-[2rem] border border-[#312e81]/10 bg-[#eef2ff]/80 shadow-[0_20px_55px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_28px_70px_rgba(30,27,75,0.14)]">
            <div className="relative aspect-[1.08] overflow-hidden rounded-[1.75rem] bg-[#c7d2fe] m-3 mb-0">
                <img
                    src={normalizedProduct.image || featuredProductFallbackImage}
                    className="h-full w-full object-cover object-center transition-transform duration-700 group-hover:scale-105"
                    alt={normalizedProduct.name}
                />
                <div className="absolute inset-0 bg-gradient-to-t from-[#17153b]/75 via-transparent to-transparent" />
                {normalizedProduct.badge && (
                    <div className={`absolute left-3 top-3 rounded-full px-3 py-1.5 text-[10px] font-bold uppercase tracking-[0.12em] shadow-sm ${normalizedProduct.badgeStyle || 'border border-white/30 bg-white/90 text-brand-primary'}`}>
                        {normalizedProduct.badge}
                    </div>
                )}
            </div>

            <div className="flex flex-1 flex-col px-5 py-5">
                <h4 className="break-words text-[0.82rem] font-bold leading-[1.15] tracking-[-0.03em] text-text-primary sm:min-h-[3.3rem] sm:text-[1.08rem] sm:leading-snug">
                    {normalizedProduct.name}
                </h4>

                {(brandName || categoryName) && (
                    <div className="mt-1 space-y-1 sm:mt-2 sm:space-y-1.5">
                        {brandName && (
                            <div className="inline-flex max-w-full items-center rounded-full border border-brand-primary/15 bg-white/65 px-1.5 py-0.5 text-[7.5px] font-black uppercase tracking-[0.08em] text-brand-primary shadow-sm sm:px-2.5 sm:py-1 sm:text-[10px] sm:tracking-[0.12em]">
                                <span className="mr-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-brand-primary" />
                                <span className="truncate">{brandName}</span>
                            </div>
                        )}
                        {categoryName && (
                            <p className="line-clamp-2 text-[8px] font-semibold leading-3 text-[#4b5578] sm:text-[11px] sm:leading-4">
                                <span className="font-black uppercase tracking-[0.12em] text-[#1e1b4b]/55">Category: </span>
                                {categoryName}
                            </p>
                        )}
                    </div>
                )}

                <p className="mt-2 hidden text-sm leading-6 text-[#5b6079] sm:line-clamp-2">
                    {cardDescription}
                </p>

                <div className="mt-auto flex items-center justify-between gap-3 border-t border-[#312e81]/10 pt-3 sm:pt-5">
                    <p className="text-[0.7rem] font-black leading-tight text-brand-primary sm:text-[1rem]">
                        {normalizedProduct.price}
                    </p>
                    <Link
                        href={productHref}
                        aria-label={`View details for ${normalizedProduct.name}`}
                        className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-[#312e81]/15 bg-white/60 text-brand-primary shadow-sm transition-colors hover:bg-brand-primary hover:text-white sm:h-11 sm:w-11"
                    >
                        <svg className="h-3.5 w-3.5 sm:h-4 sm:w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth="2.5" aria-hidden="true">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                        </svg>
                    </Link>
                </div>
            </div>
        </div>
    );
}
