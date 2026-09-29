import { defaultHeroImages } from '@/lib/website-content';

// Shown only when the catalogue API returns no brands (e.g. backend offline).
const placeholderBrands = [{ label: 'Demo Brand A' }, { label: 'Demo Brand B' }, { label: 'Demo Brand C' }];

export default function HeroSection({ heroImages: initialHeroImages = defaultHeroImages, brands = [] }) {
    const partnerLogos = brands.length > 0 ? brands.map((brand) => ({ label: brand.name })) : placeholderBrands;
    const heroImages = Array.isArray(initialHeroImages) ? initialHeroImages : defaultHeroImages;
    const heroImage = heroImages[0] || '';

    return (
        <section className="relative w-full bg-[#e0e7ff] px-4 pb-10 pt-4 sm:px-6 sm:pb-14 sm:pt-6 lg:px-7 lg:pb-20 lg:pt-7">
            <div className="relative w-full">
                <div className="relative min-h-[520px] w-full overflow-visible rounded-[2rem] bg-[linear-gradient(135deg,#1e1b4b_0%,#17153b_48%,#e0e7ff_160%)] sm:min-h-[660px] sm:rounded-[2.4rem] lg:min-h-[690px] lg:rounded-[2.65rem]">
                    {heroImage && (
                        <div
                            className="absolute inset-0 rounded-[inherit] bg-cover bg-center"
                            style={{ backgroundImage: `url('${heroImage}')` }}
                        />
                    )}
                    <div className="absolute inset-0 rounded-[inherit] bg-[linear-gradient(180deg,rgba(18,16,46,0.62)_0%,rgba(23,21,59,0.38)_30%,rgba(18,16,46,0.30)_54%,rgba(18,16,46,0.72)_100%)]" />
                    <div className="absolute inset-0 rounded-[inherit] bg-[radial-gradient(circle_at_50%_58%,rgba(45,212,191,0.34),transparent_26%),radial-gradient(circle_at_50%_6%,rgba(255,255,255,0.14),transparent_26%)]" />

                    {/* Spacer reserving room for the shared fixed SiteNavbar */}
                    <div className="relative z-20 h-[104px] sm:h-[120px] lg:h-[136px]" />

                    <div className="relative z-10 mx-auto flex min-h-[345px] max-w-6xl flex-col items-center justify-center px-5 pb-28 pt-10 text-center sm:min-h-[470px] sm:px-8 sm:pb-32 lg:min-h-[485px] lg:pb-28 lg:pt-12">
                        <h1 className="max-w-[12.5ch] text-[clamp(3rem,8vw,6.2rem)] font-medium leading-[0.96] tracking-[-0.028em] text-white drop-shadow-[0_10px_30px_rgba(0,0,0,0.32)] sm:max-w-[15ch]">
                            Distribution Made Simple
                        </h1>
                    </div>

                    <div className="absolute -bottom-10 left-1/2 z-20 flex h-28 w-28 -translate-x-1/2 items-center justify-center rounded-full bg-[#0f0d26]/92 text-white shadow-[0_24px_60px_rgba(0,0,0,0.34)] sm:-bottom-14 sm:h-36 sm:w-36">
                        <svg className="absolute inset-0 h-full w-full animate-spin-slow" viewBox="0 0 140 140" aria-hidden="true">
                            <defs>
                                <path id="hero-scroll-text" d="M70,70 m-53,0 a53,53 0 1,1 106,0 a53,53 0 1,1 -106,0" />
                            </defs>
                            <text className="fill-white text-[12px] font-medium uppercase tracking-[0.22em]">
                                <textPath href="#hero-scroll-text">Demo Site Explore More About</textPath>
                            </text>
                        </svg>
                        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[#ffffff] shadow-[0_10px_26px_rgba(0,0,0,0.25)] sm:h-16 sm:w-16">
                            <img src="/logo-mark.png" alt="TradeHub Demo" className="h-10 w-10 rounded-full object-contain sm:h-12 sm:w-12" />
                        </div>
                    </div>
                </div>

                <div className="pt-20 sm:pt-24 lg:pt-28">
                    <div className="relative mx-auto max-w-6xl overflow-hidden text-[#16143a] [mask-image:linear-gradient(90deg,transparent,black_12%,black_88%,transparent)]">
                        <div className="brand-marquee-track flex w-max items-center gap-10 sm:gap-14 lg:gap-18">
                            {[...partnerLogos, ...partnerLogos].map((partner, index) => (
                                <div key={`${partner.label}-${index}`} className="shrink-0 rounded-full bg-[#eef2ff]/60 px-6 py-3 text-[#1e1b4b]/75 shadow-[inset_0_1px_0_rgba(255,255,255,0.55)]">
                                    <span className="whitespace-nowrap text-xl font-black tracking-[-0.018em] sm:text-2xl">{partner.label}</span>
                                </div>
                            ))}
                        </div>
                    </div>
                    <p className="mt-7 text-center text-xl font-medium tracking-[-0.018em] text-[#1e1b4b] sm:text-2xl">
                        Demo Brands in Our Catalogue
                    </p>
                </div>
            </div>
        </section>
    );
}
