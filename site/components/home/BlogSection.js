import Link from 'next/link';
import ScrollReveal from '@/components/ScrollReveal';
import Icon from '@/components/Icon';
import InsightCard from '@/components/InsightCard';
import { ArrowRight02Icon } from '@hugeicons/core-free-icons';
import { insightPosts } from '@/lib/insights';

const HOME_POST_COUNT = 3;

export default function BlogSection() {
    return (
        <section className="bg-[#e0e7ff] px-4 py-16 sm:px-6 sm:py-24 lg:px-7">
            <div className="mx-auto max-w-7xl">
                <ScrollReveal className="mb-12 grid grid-cols-1 gap-6 lg:mb-16 lg:grid-cols-[0.8fr_1fr] lg:items-end">
                    <div>
                        <div className="home-kicker">Knowledge Hub</div>
                        <h3 className="mt-5 max-w-xl text-4xl font-semibold leading-[1.02] tracking-[-0.024em] text-text-primary md:text-6xl">
                            Latest Insights
                        </h3>
                    </div>
                    <p className="max-w-xl text-base leading-7 text-text-secondary lg:justify-self-end">
                        Placeholder articles that show how a knowledge hub could look. Content is generic and synthetic.
                    </p>
                </ScrollReveal>

                <div className="grid grid-cols-1 gap-5 md:grid-cols-3">
                    {insightPosts.slice(0, HOME_POST_COUNT).map((post, i) => (
                        <ScrollReveal key={post.href} delay={i * 120} className="h-full">
                            <InsightCard post={post} />
                        </ScrollReveal>
                    ))}
                </div>

                <ScrollReveal className="mt-10 flex justify-center sm:mt-12">
                    <Link
                        href="/insights"
                        className="group inline-flex items-center gap-4 rounded-full bg-[#16143a] py-2 pl-7 pr-2 text-sm font-bold text-white shadow-[0_16px_35px_-12px_rgba(22,20,58,0.6)] transition-all hover:-translate-y-0.5 sm:text-base"
                    >
                        View All Blog Posts
                        <span className="flex h-10 w-10 items-center justify-center rounded-full bg-white/15 transition-colors group-hover:bg-white group-hover:text-[#16143a]">
                            <Icon icon={ArrowRight02Icon} size={18} strokeWidth={2} className="transition-transform group-hover:translate-x-0.5" />
                        </span>
                    </Link>
                </ScrollReveal>
            </div>
        </section>
    );
}
