import { fetchApiJson } from '@/lib/api-base';
import { normalizeWebsiteImageUrl } from '@/lib/media-url';
import {
    getGeneralCategories,
    getGeneralCategoryProducts,
    normalizeCatalogProduct,
} from '@/lib/catalog-api';

const productCardFallbackImage = '/demo/product-placeholder.png';

// No hardcoded categories: everything comes from the demo backend.
const defaultProductCategories = [];

export function slugifyCategoryName(name = '') {
    return encodeURIComponent(String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-')).replace(/^-|-$/g, '');
}

export function slugifyProductName(product = {}) {
    const explicitSlug = String(product?.slug || '').trim();
    if (explicitSlug) {
        return slugifyCategoryName(explicitSlug);
    }

    return slugifyCategoryName(product?.name || '');
}

export function normalizeCategoryProduct(product, index) {
    if (typeof product === 'string') {
        return {
            name: product.trim(),
            shortDescription: '',
            description: '',
            image: '',
            images: [],
            slug: '',
            productId: '',
            sku: '',
            stock: 0,
            priceUnit: '',
            packing: '',
            retailPrice: 0,
            wholesalePrice: 0,
            mrp: 0,
            order: index,
        };
    }

    const images = Array.isArray(product?.images)
        ? product.images.map((image) => String(image || '').trim()).filter(Boolean)
        : [];

    return {
        name: String(product?.name || '').trim(),
        shortDescription: String(product?.shortDescription || '').trim(),
        description: String(product?.description || '').trim(),
        image: String(product?.image || images[0] || '').trim(),
        images,
        slug: String(product?.slug || '').trim(),
        productId: String(product?.productId || '').trim(),
        sku: String(product?.sku || '').trim(),
        stock: Number(product?.stock) || 0,
        priceUnit: String(product?.priceUnit || '').trim(),
        packing: String(product?.packing || '').trim(),
        retailPrice: Number(product?.retailPrice) || 0,
        wholesalePrice: Number(product?.wholesalePrice) || 0,
        mrp: Number(product?.mrp) || 0,
        order: Number.isFinite(product?.order) ? product.order : index,
    };
}

export function normalizeProductVariants(variants = []) {
    return [];
}

export function getVariantSummary(product = {}) {
    return null;
}

export function getCategoryProducts(category) {
    const productDetails = Array.isArray(category?.productDetails)
        ? category.productDetails.map((product, index) => normalizeCategoryProduct(product, index)).filter((product) => product.name)
        : [];

    if (productDetails.length > 0) {
        return productDetails.sort((a, b) => (a.order || 0) - (b.order || 0));
    }

    return Array.isArray(category?.products)
        ? category.products.map((product, index) => normalizeCategoryProduct(product, index)).filter((product) => product.name)
        : [];
}

export function formatPrice(value) {
    if (!Number.isFinite(value) || value <= 0) {
        return '';
    }

    return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
    }).format(value);
}

export function buildProductInquiryDetails(product) {
    const details = [];

    if (product.shortDescription) {
        details.push(product.shortDescription);
    } else if (product.description) {
        details.push(product.description);
    }

    if (product.sku) {
        details.push(`SKU: ${product.sku}`);
    }

    if (product.stock > 0) {
        details.push(`Stock: ${product.stock}`);
    }

    return details;
}

export function getProductHighlights(product) {
    const baseText = product.shortDescription || product.description || '';

    return baseText
        .split(/\r?\n|[|.]/)
        .map((item) => item.replace(/^[\s\-\u2022.]+/, '').trim())
        .filter(Boolean)
        .slice(0, 4);
}

export async function getCategories() {
    const liveCategories = await getGeneralCategories();
    if (liveCategories.length > 0) {
        const categoriesWithProducts = await Promise.all(
            liveCategories.map(async (category) => {
                const result = await getGeneralCategoryProducts(category.slug);
                const productDetails = result.products.map((product, index) => normalizeCatalogProduct(product, index));
                return {
                    ...category,
                    products: productDetails.map((product) => product.name),
                    productDetails,
                };
            })
        );
        return categoriesWithProducts;
    }

    const json = await fetchApiJson('/settings/website-content');
    const productCategories = Array.isArray(json?.data?.productCategories) ? json.data.productCategories : [];

    return productCategories.map((category) => ({
        ...category,
        image: normalizeWebsiteImageUrl(category?.image),
        productDetails: Array.isArray(category?.productDetails)
            ? category.productDetails.map((product) => ({
                ...product,
                image: normalizeWebsiteImageUrl(product?.image),
                images: Array.isArray(product?.images) ? product.images.map(normalizeWebsiteImageUrl) : product?.images,
            }))
            : category?.productDetails,
    }));
}

export function findCategoryBySlug(categories, slug) {
    return categories.find((category) => slugifyCategoryName(category.name) === slug);
}

export function findProductBySlug(category, productSlug) {
    return getCategoryProducts(category).find((product) => slugifyProductName(product) === productSlug);
}

export { defaultProductCategories, productCardFallbackImage };
