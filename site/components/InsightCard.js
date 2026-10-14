import Link from 'next/link';
import Icon from '@/components/Icon';
import { ArrowRight02Icon } from '@hugeicons/core-free-icons';

// Blog post card. `featured` lays it out wide (image beside the text).
export default function InsightCard({ post, featured = false }) {
    return (
        <Link href={post.href} className="block h-full">
            <article
                className={`group flex h-full cursor-pointer overflow-hidden rounded-[2rem] border border-[#0b3b1f]/10 bg-[#edf3e6]/80 p-3 shadow-[0_20px_55px_rgba(8,36,18,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_28px_70px_rgba(8,36,18,0.14)] ${featured ? 'flex-col lg:flex-row' : 'flex-col'}`}
            >
                <div className={`relative overflow-hidden rounded-[1.55rem] bg-[#d6e0c9] ${featured ? 'h-64 sm:h-80 lg:h-auto lg:min-h-[360px] lg:w-[58%] lg:shrink-0' : 'h-56'}`}>
                    <img
                        src={post.image}
                        alt={post.imageAlt || post.title}
                        loading="lazy"
                        className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-105"
                    />
                    <span className="absolute left-3 top-3 rounded-full bg-white/90 px-3 py-1 text-[10px] font-bold uppercase tracking-[0.08em] text-brand-primary shadow-sm backdrop-blur">
                        {post.category}
                    </span>
                </div>
                <div className={`flex flex-1 flex-col ${featured ? 'px-3 py-6 lg:px-8 lg:py-8' : 'px-3 py-5'}`}>
                    <div className="mb-3 flex items-center gap-2 text-xs font-medium text-text-secondary">
                        <span>{post.date}</span>
                        <span className="h-1 w-1 rounded-full bg-text-secondary/40" />
                        <span>{post.readTime}</span>
                    </div>
                    <h4 className={`font-semibold leading-snug tracking-[-0.03em] text-text-primary transition-colors group-hover:text-brand-primary ${featured ? 'text-2xl sm:text-3xl' : 'text-xl'}`}>
                        {post.title}
                    </h4>
                    <p className={`mb-5 mt-3 text-sm leading-6 text-text-secondary ${featured ? 'sm:text-base sm:leading-7' : 'line-clamp-2'}`}>
                        {post.excerpt}
                    </p>
                    <div className="mt-auto flex items-center gap-2 border-t border-[#0b3b1f]/10 pt-4 text-sm font-bold text-brand-primary">
                        Read More
                        <Icon icon={ArrowRight02Icon} size={16} strokeWidth={2} className="transition-transform group-hover:translate-x-1" />
                    </div>
                </div>
            </article>
        </Link>
    );
}
