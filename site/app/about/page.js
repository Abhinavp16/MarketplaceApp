import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import { getWebsiteContent } from '@/lib/website-content';
import { ADDRESS, LEGAL_NAME, SITE_NAME } from '@/lib/site-config';

export const metadata = {
    title: 'About Us',
    description: 'About TradeHub Demo, a fictional distribution business used for demonstration purposes.',
};

export const dynamic = 'force-dynamic';

const values = [
    {
        title: 'Reliable Supply',
        description: 'Demo placeholder: describe how you keep products available and coordinate with dealers and direct buyers.',
    },
    {
        title: 'Streamlined Operations',
        description: 'Demo placeholder: product discovery, bulk enquiries, payment coordination and dispatch handling in one workflow.',
    },
    {
        title: 'Dealer-Friendly Distribution',
        description: 'Demo placeholder: from retail supply to wholesale fulfilment, with tools to grow a dealer network.',
    },
];

export default async function AboutPage() {
    const { productCategories, featuredProducts } = await getWebsiteContent();
    const productImages = [productCategories?.[0]?.image, featuredProducts?.[0]?.image].filter(Boolean);

    return (
        <div className="page-transition">
            <PageHero
                title="About Us"
                subtitle="TradeHub Demo is a fictional distributor used to demonstrate this website template."
                breadcrumbItems={['About Us']}
            />

            <section className="px-6 py-10 sm:py-24 max-w-7xl mx-auto">
                <div className="grid grid-cols-1 gap-10 lg:grid-cols-2 lg:gap-16 items-center">
                    <ScrollReveal>
                        <div className="mb-4 h-1 w-12 bg-brand-primary sm:mb-6" />
                        <h2 className="mb-5 text-3xl font-primary font-bold leading-tight text-text-primary sm:mb-8 md:text-5xl">
                            Built Around Practical Supply
                        </h2>
                        <p className="mb-4 text-base leading-relaxed text-text-secondary sm:mb-6 sm:text-lg">
                            This is demo placeholder content. TradeHub Demo is a fictional business that serves retailers, dealers and end buyers with a catalogue of industrial supplies.
                        </p>
                        <p className="mb-4 text-base leading-relaxed text-text-secondary sm:mb-6 sm:text-lg">
                            The demo catalogue includes sample categories such as power tools, hand tools, fasteners and fittings, and safety gear from fictional brands. All product data is synthetic.
                        </p>
                        <div className="mt-6 rounded-2xl border border-gray-100 bg-neutral-surface p-5 sm:mt-10 sm:p-6">
                            <h3 className="text-xl font-bold text-text-primary mb-4">Business Snapshot</h3>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                                <p className="text-text-secondary"><span className="font-semibold text-text-primary">Brand:</span> {SITE_NAME}</p>
                                <p className="text-text-secondary"><span className="font-semibold text-text-primary">Legal Name:</span> {LEGAL_NAME}</p>
                                <p className="text-text-secondary sm:col-span-2"><span className="font-semibold text-text-primary">Address:</span> {ADDRESS}</p>
                            </div>
                        </div>
                    </ScrollReveal>

                    <ScrollReveal className="relative">
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                            <img
                                src={productImages[0] || '/demo/about/about-product.png'}
                                className="h-72 w-full rounded-2xl object-cover object-center shadow-lg"
                                alt="Demo product illustration"
                            />
                            <img
                                src="/demo/about/about-card.png"
                                className="h-72 w-full rounded-2xl object-cover object-center shadow-lg"
                                alt="Demo warehouse illustration"
                            />
                            <div className="bg-brand-primary p-6 rounded-2xl text-white sm:col-span-2">
                                <p className="text-3xl font-bold italic mb-1">Demo placeholder content</p>
                                <p className="text-xs uppercase tracking-tighter opacity-80">Synthetic data for demonstration only</p>
                            </div>
                        </div>
                    </ScrollReveal>
                </div>
            </section>

            <section className="bg-neutral-surface py-12 sm:py-24">
                <div className="max-w-7xl mx-auto px-6">
                    <ScrollReveal className="mb-10 text-center sm:mb-16">
                        <h2 className="mb-3 text-xs font-bold uppercase tracking-[0.24em] text-brand-primary sm:mb-4 sm:text-sm sm:tracking-[0.3em]">What Drives Us</h2>
                        <h3 className="text-3xl font-primary font-bold text-text-primary md:text-5xl">Platform Principles</h3>
                    </ScrollReveal>

                    <div className="grid grid-cols-1 gap-5 md:grid-cols-3 md:gap-8">
                        {values.map((value, i) => (
                            <ScrollReveal key={i} delay={i * 100}>
                                <div className="h-full rounded-3xl border border-gray-100 bg-white p-6 shadow-sm transition-all hover:shadow-xl sm:p-8">
                                    <h4 className="text-xl font-bold text-text-primary mb-4">{value.title}</h4>
                                    <p className="text-text-secondary leading-relaxed">{value.description}</p>
                                </div>
                            </ScrollReveal>
                        ))}
                    </div>
                </div>
            </section>
        </div>
    );
}
