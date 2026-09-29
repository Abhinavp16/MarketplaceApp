import { fetchApiJson } from '@/lib/api-base';
import { normalizeWebsiteImageUrl } from '@/lib/media-url';
import { getWebsiteHomeCatalog } from '@/lib/catalog-api';

const featuredProductFallbackImage = '/demo/product-placeholder.png';

// No hardcoded product list: featured products always come from the demo backend.
const defaultFeaturedProducts = [];

function extractSpecs(product) {
    if (Array.isArray(product?.specs) && product.specs.length > 0) {
        return product.specs.map((spec) => String(spec || '').trim()).filter(Boolean);
    }

    const sourceText = String(product?.description || product?.shortDescription || '').trim();
    if (!sourceText) {
        return [];
    }

    return sourceText
        .split(/\r?\n|[|.]/)
        .map((item) => item.replace(/^[\s\-•.]+/, '').trim())
        .filter(Boolean);
}

export function normalizeFeaturedVariants() {
    return [];
}

export function slugifyFeaturedProduct(product = {}) {
    const base = typeof product === 'string' ? product : product?.slug || product?.name || '';
    return encodeURIComponent(String(base).toLowerCase().replace(/[^a-z0-9]+/g, '-')).replace(/^-|-$/g, '');
}

export function normalizeFeaturedProduct(product, index = 0) {
    const specs = extractSpecs(product);

    const images = Array.isArray(product?.images)
        ? product.images.map((image) => String(image || '').trim()).filter(Boolean)
        : [];

    const mrp = Number(product?.mrp) || 0;

    return {
        name: String(product?.name || `Product ${index + 1}`).trim(),
        price: String(product?.price || (mrp > 0 ? `MRP: Rs. ${mrp}` : 'Request Quote')).trim(),
        mrp,
        image: String(product?.image || images[0] || featuredProductFallbackImage).trim(),
        images,
        badge: String(product?.badge || '').trim(),
        badgeStyle: String(product?.badgeStyle || '').trim(),
        description: String(product?.description || '').trim(),
        shortDescription: String(product?.shortDescription || '').trim(),
        specs,
        slug: String(product?.slug || '').trim(),
        href: String(product?.href || '').trim(),
        brand: String(product?.brand || '').trim(),
        categoryName: String(product?.categoryName || '').trim(),
        priceUnit: String(product?.priceUnit || '').trim(),
        packing: String(product?.packing || '').trim(),
    };
}

export function getFeaturedDescription(product) {
    if (product.description) {
        return product.description;
    }

    if (product.shortDescription) {
        return product.shortDescription;
    }

    if (product.specs.length > 0) {
        return product.specs.join('. ');
    }

    return `Get complete specifications, pricing, and dealer support for ${product.name}.`;
}

export function buildFeaturedProductInquiryProps(product) {
    return {
        productName: product.name,
        price: product.price,
        details: product.specs.slice(0, 4),
    };
}

export async function getFeaturedProducts() {
    const catalog = await getWebsiteHomeCatalog();
    if (catalog.featuredProducts.length > 0) {
        return catalog.featuredProducts.map((product, index) => normalizeFeaturedProduct(product, index));
    }

    const json = await fetchApiJson('/settings/website-content');
    const source = Array.isArray(json?.data?.featuredProducts) ? json.data.featuredProducts : [];
    return source.map((product, index) => normalizeFeaturedProduct({
        ...product,
        image: normalizeWebsiteImageUrl(product?.image),
    }, index));
}

export function findFeaturedProductBySlug(products, slug) {
    return products.find((product) => slugifyFeaturedProduct(product) === slug);
}

export { defaultFeaturedProducts, featuredProductFallbackImage };
