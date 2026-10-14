import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import InsightCard from '@/components/InsightCard';
import { insightPosts } from '@/lib/insights';

export const metadata = {
    title: 'Insights & Guides',
    description: 'Placeholder buying guides and operations tips for distributors, dealers and retailers (synthetic demo content).',
};

export default function InsightsPage() {
    const [featured, ...rest] = insightPosts;
    const categories = [...new Set(insightPosts.map((post) => post.category))];

    return (
        <div className="page-transition">
            <PageHero
                title="Insights & Guides"
                subtitle="Placeholder guides and tips on suppliers, inventory and bulk ordering. Demo content only."
            />

            <section className="bg-[#dfe8d3] px-4 pb-16 pt-6 sm:px-6 sm:pb-24 lg:px-7">
                <div className="mx-auto max-w-7xl">
                    <ScrollReveal className="mb-8 flex flex-col gap-4 sm:mb-10 sm:flex-row sm:items-end sm:justify-between">
                        <div>
                            <div className="home-kicker">Knowledge Hub</div>
                            <h2 className="mt-4 text-3xl font-semibold tracking-[-0.024em] text-text-primary md:text-5xl">
                                All Blog Posts
                            </h2>
                        </div>
                        <div className="flex flex-wrap gap-2">
                            <span className="rounded-full bg-[#062712] px-4 py-2 text-xs font-bold text-white">
                                {insightPosts.length} articles
                            </span>
                            {categories.map((category) => (
                                <span key={category} className="rounded-full border border-[#0b3b1f]/10 bg-white/60 px-4 py-2 text-xs font-bold text-brand-primary">
                                    {category}
                                </span>
                            ))}
                        </div>
                    </ScrollReveal>

                    {featured && (
                        <ScrollReveal className="mb-5">
                            <InsightCard post={featured} featured />
                        </ScrollReveal>
                    )}

                    <div className={`grid grid-cols-1 gap-5 md:grid-cols-2 ${rest.length >= 3 ? 'lg:grid-cols-3' : ''}`}>
                        {rest.map((post, i) => (
                            <ScrollReveal key={post.href} delay={i * 120} className="h-full">
                                <InsightCard post={post} />
                            </ScrollReveal>
                        ))}
                    </div>
                </div>
            </section>
        </div>
    );
}
