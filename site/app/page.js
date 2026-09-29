import HeroSection from '@/components/home/HeroSection';
import BannersSection from '@/components/home/BannersSection';
import AboutSection from '@/components/home/AboutSection';
import ProductsSection from '@/components/home/ProductsSection';
import CategoriesSection from '@/components/home/CategoriesSection';
import StatsSection from '@/components/home/StatsSection';
import BlogSection from '@/components/home/BlogSection';
import ContactSection from '@/components/home/ContactSection';
import { getWebsiteContent } from '@/lib/website-content';

export const dynamic = 'force-dynamic';

export default async function Home() {
  const {
    heroImages,
    brands,
    featuredProducts,
    productCategories,
    featuredSection,
    categoriesSection,
  } = await getWebsiteContent();

  return (
    <>
      <HeroSection heroImages={heroImages} brands={brands} />
      <BannersSection />
      <AboutSection productImages={[featuredProducts?.[0]?.image, productCategories?.[0]?.image]} />
      <ProductsSection products={featuredProducts} section={featuredSection} />
      <CategoriesSection categories={productCategories} section={categoriesSection} />
      <StatsSection />
      <BlogSection />
      <ContactSection />
    </>
  );
}
