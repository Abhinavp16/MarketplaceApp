import Link from 'next/link';
import ScrollReveal from '@/components/ScrollReveal';

const blogPosts = [
    {
        title: 'Choosing a Reliable Supplier: A Demo Checklist',
        category: 'Buying Guide',
        date: 'Demo',
        image: '/demo/insights/insight-1.jpg',
        link: '/insights/choosing-a-supplier'
    },
    {
        title: 'Inventory Basics for Growing Distributors',
        category: 'Operations',
        date: 'Demo',
        image: '/demo/insights/insight-2.jpg',
        link: '/insights/inventory-basics'
    },
    {
        title: 'Bulk Ordering Tips for Dealers and Retailers',
        category: 'Dealer Tips',
        date: 'Demo',
        image: '/demo/insights/insight-3.jpg',
        link: '/insights/bulk-ordering-tips'
    },
];

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
                    {blogPosts.map((post, i) => (
                        <ScrollReveal key={i} delay={i * 120}>
                            <Link href={post.link}>
                                <article className="group flex h-full cursor-pointer flex-col overflow-hidden rounded-[2rem] border border-[#312e81]/10 bg-[#eef2ff]/80 p-3 shadow-[0_20px_55px_rgba(30,27,75,0.08)] transition-all hover:-translate-y-1 hover:shadow-[0_28px_70px_rgba(30,27,75,0.14)]">
                                    <div className="relative h-56 overflow-hidden rounded-[1.55rem]">
                                        <div className="absolute inset-0 z-10 bg-gradient-to-t from-[#17153b]/60 to-transparent transition-colors" />
                                        <img
                                            src={post.image}
                                            className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700"
                                            alt={post.title}
                                        />
                                    </div>
                                    <div className="flex flex-1 flex-col px-3 py-5">
                                        <div className="mb-3 flex items-center gap-3">
                                            <span className="rounded-full border border-[#312e81]/10 bg-white/55 px-3 py-1 text-[10px] font-bold uppercase text-brand-primary">
                                                {post.category}
                                            </span>
                                            <span className="text-xs text-gray-400">{post.date}</span>
                                        </div>
                                        <h4 className="mb-auto text-xl font-semibold leading-snug tracking-[-0.04em] text-text-primary transition-colors group-hover:text-brand-primary">
                                            {post.title}
                                        </h4>
                                        <div className="mt-5 flex items-center gap-2 border-t border-[#312e81]/10 pt-4 text-sm font-bold text-brand-primary">
                                            Read More
                                            <svg className="w-4 h-4 group-hover:translate-x-1 transition-transform" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                                <path d="M5 12h14" />
                                                <path d="m12 5 7 7-7 7" />
                                            </svg>
                                        </div>
                                    </div>
                                </article>
                            </Link>
                        </ScrollReveal>
                    ))}
                </div>
            </div>
        </section>
    );
}
