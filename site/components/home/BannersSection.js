import Link from 'next/link';

export default function BannersSection() {
    return (
        <section className="bg-[#e0e7ff] px-4 py-10 sm:px-6 sm:py-14 lg:px-7">
            <div className="mx-auto max-w-7xl">
                <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
                    <div>
                        <h2 className="max-w-3xl text-3xl font-semibold leading-tight tracking-[-0.022em] text-text-primary sm:text-4xl lg:text-5xl">
                            Dealer support and streamlined ordering<br className="hidden lg:block" /> for a modern distribution business.
                        </h2>
                    </div>
                    <p className="max-w-md text-sm leading-6 text-text-secondary sm:text-base">
                        Placeholder copy: dealership programs, bulk support and product discovery shown as a template.
                    </p>
                </div>

                <div className="grid grid-cols-1 items-stretch gap-5 lg:gap-6">
                    <div className="group relative left-1/2 min-h-[292px] w-screen -translate-x-1/2 overflow-hidden bg-transparent transition-all sm:min-h-[356px]">
                        <div className="absolute inset-0 bg-white sm:top-[100px]" />

                        <div className="absolute left-6 top-[106px] h-[150px] w-[195px] sm:left-[max(20px,calc(50%-650px))] sm:top-[-6px] sm:h-[350px] sm:w-[520px]">
                            <img
                                src="/demo/banner/app-preview.png"
                                alt="Demo app preview graphic"
                                className="h-full w-full object-contain object-left-bottom"
                            />
                        </div>

                        <span className="absolute right-6 top-[139px] z-20 inline-flex items-center gap-3 rounded-full border border-white/85 bg-white px-4 py-2 text-sm font-bold text-[#0d9488] shadow-[0_12px_28px_rgba(30,27,75,0.12)] sm:hidden">
                            Explore
                            <span className="flex h-9 w-9 items-center justify-center rounded-full border border-[#0d9488]/40 text-2xl leading-none">→</span>
                        </span>

                        <div className="relative z-10 flex min-h-[292px] flex-col px-7 pt-7 sm:ml-[max(430px,calc(50%-130px))] sm:min-h-[356px] sm:pt-[128px]">
                            <h3 className="max-w-[21rem] text-[28px] font-black leading-[1.18] tracking-[-0.045em] text-[#16143a] sm:max-w-[700px] sm:text-5xl sm:leading-[1.08] sm:tracking-[-0.055em] lg:text-[48px] xl:text-[48px]">
                                Come make an impact with TradeHub Demo
                            </h3>
                            <div className="mt-6 hidden items-center gap-4 sm:mt-8 sm:flex">
                                <Link href="/products" className="inline-flex w-fit shrink-0 items-center gap-6 rounded-full border border-[#0d9488]/70 px-8 py-3 text-base font-semibold text-[#0d9488] transition-colors hover:bg-[#0d9488] hover:text-white sm:gap-8">
                                    Explore Products
                                    <span className="flex h-12 w-12 items-center justify-center rounded-full border border-current text-3xl leading-none">→</span>
                                </Link>
                                <span className="rounded-xl border border-[#16143a]/10 bg-white/95 px-4 py-3 text-xs font-semibold text-[#4b5578] shadow-[0_12px_28px_rgba(30,27,75,0.12)]">
                                    Demo only — no mobile app is published
                                </span>
                            </div>
                        </div>
                    </div>

                    <Link href="/dealership" className="group relative left-1/2 min-h-[300px] w-screen -translate-x-1/2 overflow-hidden bg-[#c9e8e4] transition-all sm:min-h-[340px]">
                        <div className="absolute right-[max(28px,calc(50%-590px))] top-1/2 hidden h-56 w-56 -translate-y-1/2 items-center justify-center rounded-full bg-white shadow-[0_24px_60px_rgba(30,27,75,0.12)] sm:flex lg:h-64 lg:w-64">
                            <img
                                src="/demo/banner/dealer-partnership.png"
                                alt="Dealer partnership graphic"
                                className="w-[82%] object-contain"
                            />
                        </div>

                        <div className="relative z-10 flex min-h-[300px] flex-col px-7 pt-9 sm:min-h-[340px] sm:px-[max(42px,calc(50%-610px))] sm:pt-12">
                            <h3 className="max-w-2xl text-[40px] font-black leading-[1.02] tracking-[-0.05em] text-[#16143a] sm:text-6xl">
                                Become a <span className="text-[#0f766e]">Dealer</span>
                            </h3>
                            <p className="mt-5 max-w-xl text-base font-semibold leading-7 text-[#4b5578] sm:text-lg">
                                Join the demo supply network and explore how dealer onboarding, pricing tiers and orders could work. Placeholder copy only.
                            </p>
                            <span className="mt-7 inline-flex w-fit items-center gap-8 rounded-full bg-[#0f766e] px-7 py-3 text-base font-bold text-white shadow-[0_16px_35px_rgba(13,148,136,0.24)] transition-colors group-hover:bg-white group-hover:text-[#0f766e] sm:mt-8">
                                Become Dealer
                                <span className="flex h-11 w-11 items-center justify-center rounded-full bg-white text-2xl leading-none text-[#0f766e] transition-colors group-hover:bg-[#0f766e] group-hover:text-white">→</span>
                            </span>
                        </div>
                    </Link>
                </div>
            </div>
        </section>
    );
}
