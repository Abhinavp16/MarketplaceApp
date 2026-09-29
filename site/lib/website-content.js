import { fetchApiJson } from '@/lib/api-base';
import { normalizeFeaturedProduct } from '@/lib/featured-products';
import { normalizeWebsiteImageUrl } from '@/lib/media-url';
import { getWebsiteHomeCatalog } from '@/lib/catalog-api';

// Generic banner artwork generated into public/demo/hero (see scripts/generate_assets.py).
export const defaultHeroImages = [
    '/demo/hero/hero-1.jpg',
    '/demo/hero/hero-2.jpg',
    '/demo/hero/hero-3.jpg',
    '/demo/hero/hero-4.jpg',
    '/demo/hero/hero-5.jpg',
];

const defaultCategoriesSection = {
    eyebrow: 'PRODUCT CATEGORIES',
    title: 'Browse by Category',
    description: 'Explore demo catalogue categories and brands. Everything shown here is synthetic sample data.',
    buttonText: 'View Products',
};

const defaultFeaturedSection = {
    eyebrow: 'FEATURED',
    title: 'Featured Products',
    sideText: 'Featured products selected from the demo catalogue.',
    buttonText: 'Get Quote',
};

export function buildLiveCategories(liveCatalog) {
    return [
        ...liveCatalog.brands.map((brand) => ({
            name: brand.name,
            description: brand.description || 'Explore brand categories and available products.',
            image: brand.image,
            fallback: brand.image,
            href: brand.href,
            productCount: brand.productCount,
            products: [],
        })),
        ...liveCatalog.generalCategories.map((category) => ({
            name: category.name,
            description: category.description || 'Explore available products in this category.',
            image: category.image,
            fallback: category.image,
            href: category.href,
            productCount: category.productCount,
            products: [],
        })),
    ];
}

// Fail-soft: every network call resolves to empty data when the backend is down.
export async function getWebsiteContent() {
    const [settings, liveCatalog] = await Promise.all([
        fetchApiJson('/settings/website-content'),
        getWebsiteHomeCatalog(),
    ]);

    const heroCards = Array.isArray(settings?.data?.heroCards) ? settings.data.heroCards : [];
    const uploadedHero = heroCards.map((card) => normalizeWebsiteImageUrl(card?.image || '')).filter(Boolean);
    const heroImages = uploadedHero.length > 0 ? uploadedHero : defaultHeroImages;

    const settingsFeatured = Array.isArray(settings?.data?.featuredProducts) ? settings.data.featuredProducts : [];
    const featuredSource = liveCatalog.featuredProducts.length > 0
        ? liveCatalog.featuredProducts
        : settingsFeatured.map((product) => ({ ...product, image: normalizeWebsiteImageUrl(product?.image) }));
    const featuredProducts = featuredSource.map((product, index) => normalizeFeaturedProduct(product, index));

    return {
        heroImages,
        brands: liveCatalog.brands,
        featuredProducts,
        productCategories: buildLiveCategories(liveCatalog),
        featuredSection: settings?.data?.featuredSection
            ? { ...defaultFeaturedSection, ...settings.data.featuredSection }
            : defaultFeaturedSection,
        categoriesSection: settings?.data?.categoriesSection
            ? { ...defaultCategoriesSection, ...settings.data.categoriesSection }
            : defaultCategoriesSection,
    };
}
