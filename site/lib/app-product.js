import { getApiBaseUrl } from '@/lib/api-base';
import { normalizeWebsiteImageUrl } from '@/lib/media-url';
import { featuredProductFallbackImage } from '@/lib/featured-products';

// Products shared from the app link to /products/<slug>. Any active product
// can be shared, not only the website's featured ones, so the page falls back
// to the demo backend's public product API (GET /products/:slug). Without a
// login it returns the customer (retail) price only. Coming-soon products come
// back with the price hidden and are shown with a Coming Soon badge.

const priceFormatter = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });

function specLines(specifications) {
    if (!Array.isArray(specifications)) return [];
    return specifications
        .map((spec) => {
            if (typeof spec === 'string') return spec.trim();
            const key = String(spec?.key || spec?.name || spec?.label || '').trim();
            const value = String(spec?.value || '').trim();
            return key && value ? `${key}: ${value}` : key || value;
        })
        .filter(Boolean)
        .slice(0, 4);
}

/** Display price: "₹17,100 / Set", or a Coming Soon / quote label. */
export function appProductPriceLabel(product = {}) {
    if (product.comingSoon && product.priceHidden) return 'Price coming soon';
    const price = Number(product.price) || 0;
    if (price <= 0) return 'Request Quote';
    const unit = String(product.priceUnit || '').trim();
    return `₹${priceFormatter.format(price)}${unit ? ` / ${unit}` : ''}`;
}

/** The product for a shared /products/<slug> link, shaped like a featured product. */
export async function getAppProductBySlug(slug) {
    const value = String(slug || '').trim();
    if (!value) return null;
    try {
        const response = await fetch(
            `${getApiBaseUrl()}/products/${encodeURIComponent(value)}`,
            { cache: 'no-store' },
        );
        if (!response.ok) return null;
        const json = await response.json();
        const product = json?.data;
        if (!product?.name) return null;

        const images = (Array.isArray(product.images) ? product.images : [])
            .map((image) => normalizeWebsiteImageUrl(typeof image === 'string' ? image : image?.url))
            .filter(Boolean);
        const image = normalizeWebsiteImageUrl(product.primaryImage) || images[0] || featuredProductFallbackImage;

        return {
            name: String(product.name).trim(),
            slug: String(product.slug || value).trim(),
            price: appProductPriceLabel(product),
            mrp: product.priceHidden ? 0 : Number(product.mrp) || 0,
            comingSoon: Boolean(product.comingSoon),
            priceHidden: Boolean(product.priceHidden),
            image,
            images: images.length > 0 ? images : [image],
            badge: product.comingSoon ? 'Coming Soon' : '',
            shortDescription: String(product.shortDescription || '').trim(),
            description: String(product.description || '').trim(),
            specs: specLines(product.specifications),
            brand: typeof product.brand === 'string' ? product.brand : product.brand?.name || '',
        };
    } catch {
        return null;
    }
}
