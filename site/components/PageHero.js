'use client';

import { usePathname } from 'next/navigation';

// Generic banner artwork generated into public/demo/hero (see scripts/generate_assets.py).
const defaultPageHeroImages = [
    '/demo/hero/hero-1.jpg',
    '/demo/hero/hero-2.jpg',
    '/demo/hero/hero-3.jpg',
    '/demo/hero/hero-4.jpg',
    '/demo/hero/hero-5.jpg',
];

function getPageHeroIndex(pathname = '') {
    if (pathname === '/about') return 1;
    if (pathname === '/products' || pathname.startsWith('/products/') || pathname.startsWith('/category/') || pathname.startsWith('/brand/')) return 2;
    if (pathname === '/dealership' || pathname === '/dealer-agreement' || pathname === '/dealer-pricing') return 3;
    if (pathname === '/contact') return 4;
    return 4;
}

export default function PageHero({ title, subtitle, heroImages = defaultPageHeroImages }) {
    const pathname = usePathname();
    const images = Array.isArray(heroImages) && heroImages.length > 0 ? heroImages : defaultPageHeroImages;
    const heroImage = images[Math.min(getPageHeroIndex(pathname), images.length - 1)] || '';

    return (
        <section className="relative w-full bg-[#e0e7ff] px-4 pb-4 pt-4 sm:px-6 sm:pb-14 sm:pt-6 lg:px-7">
            <div className="relative min-h-[205px] w-full overflow-visible rounded-[1.55rem] bg-[linear-gradient(135deg,#1e1b4b_0%,#17153b_48%,#e0e7ff_160%)] sm:min-h-[500px] sm:rounded-[2.4rem] lg:min-h-[560px] lg:rounded-[2.65rem]">
                {heroImage && (
                    <div
                        className="absolute inset-0 hidden rounded-[inherit] bg-cover bg-center md:block"
                        style={{ backgroundImage: `url('${heroImage}')` }}
                    />
                )}
                <div className="absolute inset-0 rounded-[inherit] bg-[linear-gradient(180deg,rgba(18,16,46,0.70)_0%,rgba(23,21,59,0.46)_36%,rgba(18,16,46,0.82)_100%)]" />
                <div className="absolute inset-0 rounded-[inherit] bg-[radial-gradient(circle_at_50%_38%,rgba(45,212,191,0.24),transparent_30%),radial-gradient(circle_at_50%_0%,rgba(255,255,255,0.13),transparent_28%)]" />

                <div className="relative z-10 mx-auto flex min-h-[205px] max-w-5xl flex-col items-center justify-center px-5 pb-8 pt-24 text-center sm:min-h-[500px] sm:px-8 sm:pb-20 sm:pt-32 lg:min-h-[560px] lg:pb-24 lg:pt-36">
                    <h1 className="max-w-[12ch] break-words text-[clamp(1.9rem,9vw,2.45rem)] font-medium leading-[0.98] tracking-[-0.028em] text-white drop-shadow-[0_10px_30px_rgba(0,0,0,0.32)] sm:text-[clamp(3rem,8vw,6rem)]">
                        {title}
                    </h1>
                    {subtitle && (
                        <p className="mt-3 max-w-[19rem] text-xs leading-5 text-white/76 sm:mt-6 sm:max-w-2xl sm:text-lg sm:leading-relaxed md:text-xl">
                            {subtitle}
                        </p>
                    )}
                </div>
            </div>
        </section>
    );
}
