import Link from 'next/link';
import ScrollReveal from '@/components/ScrollReveal';
import FeaturedProductCard from '@/components/products/FeaturedProductCard';
import { normalizeFeaturedProduct } from '@/lib/featured-products';

const defaultProducts = [];

const defaultFeaturedSection = {
    eyebrow: 'FEATURED',
    title: 'Featured Products',
    sideText: 'Featured products selected from the demo catalogue.',
    buttonText: 'Get Quote',
};

export default function ProductsSection({
    products = defaultProducts,
    section = defaultFeaturedSection,
}) {
    return (
        <section id="products" className="bg-[#e0e7ff] px-4 pb-14 pt-8 sm:px-6 sm:py-24 lg:px-7">
            <div className="mx-auto max-w-7xl">
                <div className="mb-7 text-center sm:mb-12 lg:text-left">
                    <ScrollReveal>
                        <h3 className="mx-auto max-w-[15ch] text-[2.15rem] font-semibold leading-[1.05] tracking-[-0.024em] text-text-primary sm:max-w-[18ch] sm:text-5xl lg:mx-0 lg:text-6xl">
                            {section.title}
                        </h3>
                    </ScrollReveal>
                </div>

                {products.length === 0 && (
                    <div className="rounded-[2rem] border border-dashed border-[#312e81]/25 bg-white/60 p-10 text-center">
                        <h4 className="text-2xl font-bold text-text-primary">No featured products yet</h4>
                        <p className="mt-3 text-text-secondary">Products load from the demo backend. Start it and refresh this page.</p>
                    </div>
                )}

                <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-5 lg:gap-4">
                    {products.map((product, i) => (
                        <ScrollReveal key={i} delay={i * 50} className={i >= 4 ? 'hidden sm:block' : ''}>
                            <FeaturedProductCard product={normalizeFeaturedProduct(product, i)} />
                        </ScrollReveal>
                    ))}
                </div>

                <ScrollReveal className="mt-10 flex justify-center">
                    <Link href="/products/all" className="inline-flex min-h-12 items-center justify-center rounded-full border border-[#312e81]/15 bg-white/70 px-7 text-sm font-bold text-brand-primary shadow-sm transition hover:-translate-y-0.5 hover:bg-[#17153b] hover:text-white">
                        View All Products
                    </Link>
                </ScrollReveal>
            </div>
        </section>
    );
}
