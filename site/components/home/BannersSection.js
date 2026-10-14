import Link from 'next/link';
import Icon from '@/components/Icon';
import { ArrowRight02Icon } from '@hugeicons/core-free-icons';

// Demo: the mobile app is not published, so the original's store QR tiles are inert placeholders.
const storeTiles = [
    { label: 'Play Store', sublabel: 'Android' },
    { label: 'App Store', sublabel: 'iPhone' },
];

export default function BannersSection() {
    return (
        <section className="bg-[#dfe8d3] px-4 py-10 sm:px-6 sm:py-14 lg:px-7">
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

                <div className="grid grid-cols-1 items-stretch">
                    <div className="group relative left-1/2 min-h-[292px] w-screen -translate-x-1/2 overflow-hidden bg-transparent pb-5 transition-all sm:min-h-[356px] lg:pb-6">
                        <div className="absolute inset-0 bg-white sm:top-[100px]" />

                        <div className="absolute left-6 top-[106px] h-[150px] w-[195px] sm:left-[max(20px,calc(50%-650px))] sm:top-[-6px] sm:h-[350px] sm:w-[520px]">
                            <img
                                src="/demo/banner/app-preview.png"
                                alt="Demo app preview graphic"
                                className="h-full w-full object-contain object-left-bottom"
                            />
                        </div>

                        <span className="absolute right-6 top-[139px] z-20 inline-flex items-center gap-3 rounded-full border border-white/85 bg-white px-4 py-2 text-sm font-bold text-[#f9761f] shadow-[0_12px_28px_rgba(8,36,18,0.12)] sm:hidden">
                            Explore
                            <span className="flex h-9 w-9 items-center justify-center rounded-full border border-[#f9761f]/40 text-2xl leading-none"><Icon icon={ArrowRight02Icon} size={20} /></span>
                        </span>

                        <div className="relative z-10 flex min-h-[292px] flex-col px-7 pt-7 sm:ml-[max(430px,calc(50%-130px))] sm:min-h-[356px] sm:pt-[128px]">
                            <h3 className="max-w-[21rem] text-[28px] font-black leading-[1.18] tracking-[-0.045em] text-[#122316] sm:max-w-[700px] sm:text-5xl sm:leading-[1.08] sm:tracking-[-0.055em] lg:text-[48px] xl:text-[48px]">
                                Come make an impact with DemoMart
                            </h3>
                            <div className="mt-6 hidden items-center gap-4 sm:mt-8 sm:flex">
                                <Link href="/products" className="inline-flex w-fit shrink-0 items-center gap-6 rounded-full border border-[#f9761f]/70 px-8 py-3 text-base font-semibold text-[#f9761f] transition-colors group-hover:bg-[#f9761f] group-hover:text-white sm:gap-8">
                                    Explore Products
                                    <span className="flex h-12 w-12 items-center justify-center rounded-full border border-[#f9761f]/70 text-3xl leading-none transition-colors group-hover:border-white"><Icon icon={ArrowRight02Icon} size={24} /></span>
                                </Link>
                                {storeTiles.map((store) => (
                                    <div
                                        key={store.label}
                                        title="Demo only: no mobile app is published"
                                        className="flex w-[152px] shrink-0 flex-col items-center gap-2 rounded-xl border border-[#122316]/10 bg-white/95 px-3 pb-3 pt-3 shadow-[0_12px_28px_rgba(8,36,18,0.12)] transition-transform hover:-translate-y-0.5"
                                    >
                                        <div className="flex h-[104px] w-[104px] items-center justify-center rounded-md border border-dashed border-[#122316]/20 bg-[#edf3e6] text-center text-[10px] font-bold uppercase tracking-[0.12em] text-[#4f6248]">
                                            Demo only
                                        </div>
                                        <span className="text-center">
                                            <span className="block text-[9px] font-bold uppercase tracking-[0.12em] text-[#4f6248]">Coming Soon</span>
                                            <span className="block text-[15px] font-extrabold leading-tight text-[#122316]">
                                                {store.label}
                                                <span className="ml-1 text-[11px] font-semibold text-[#4f6248]">· {store.sublabel}</span>
                                            </span>
                                        </span>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

                    <Link href="/dealership" className="group relative left-1/2 min-h-[300px] w-screen -translate-x-1/2 overflow-hidden bg-[#cbdab8] transition-all sm:min-h-[340px]">
                        <div className="absolute right-[max(28px,calc(50%-590px))] top-1/2 hidden h-56 w-56 -translate-y-1/2 items-center justify-center rounded-full bg-white shadow-[0_24px_60px_rgba(8,36,18,0.12)] sm:flex lg:h-64 lg:w-64">
                            <img
                                src="/demo/banner/dealer-partnership.png"
                                alt="Hand tools laid out on a workbench"
                                className="w-[82%] object-contain"
                            />
                        </div>

                        <div className="relative z-10 flex min-h-[300px] flex-col px-7 pt-9 sm:min-h-[340px] sm:px-[max(42px,calc(50%-610px))] sm:pt-12">
                            <h3 className="max-w-2xl text-[40px] font-black leading-[1.02] tracking-[-0.05em] text-[#122316] sm:text-6xl">
                                Become a <span className="text-[#0d4b8f]">Dealer</span>
                            </h3>
                            <p className="mt-5 max-w-xl text-base font-semibold leading-7 text-[#4f6248] sm:text-lg">
                                Join the demo supply network and explore how dealer onboarding, pricing tiers and orders could work. Placeholder copy only.
                            </p>
                            <span className="mt-7 inline-flex w-fit items-center gap-8 rounded-full bg-[#0d4b8f] px-7 py-3 text-base font-bold text-white shadow-[0_16px_35px_rgba(13,75,143,0.24)] transition-colors group-hover:bg-white group-hover:text-[#0d4b8f] sm:mt-8">
                                Become Dealer
                                <span className="flex h-11 w-11 items-center justify-center rounded-full bg-white text-2xl leading-none text-[#0d4b8f] transition-colors group-hover:bg-[#0d4b8f] group-hover:text-white"><Icon icon={ArrowRight02Icon} size={20} /></span>
                            </span>
                        </div>
                    </Link>
                </div>
            </div>
        </section>
    );
}
