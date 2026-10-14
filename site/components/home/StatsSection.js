'use client';
import { useEffect, useRef, useState } from 'react';
import {
    Agreement01Icon,
    Location01Icon,
    PackageIcon,
    StarIcon,
} from '@hugeicons/core-free-icons';
import ScrollReveal from '@/components/ScrollReveal';
import DitherField from '@/components/DitherField';
import Icon from '@/components/Icon';

function Counter({ end, duration = 2000, suffix = '' }) {
    const [count, setCount] = useState(0);
    const ref = useRef(null);
    const hasAnimated = useRef(false);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting && !hasAnimated.current) {
                    hasAnimated.current = true;
                    const start = 0;
                    const increment = end / (duration / 16);
                    let current = start;
                    const timer = setInterval(() => {
                        current += increment;
                        if (current >= end) {
                            setCount(end);
                            clearInterval(timer);
                        } else {
                            setCount(Math.floor(current));
                        }
                    }, 16);
                }
            },
            { threshold: 0.5 }
        );
        if (ref.current) observer.observe(ref.current);
        return () => observer.disconnect();
    }, [end, duration]);

    return (
        <span ref={ref}>
            {count.toLocaleString()}{suffix}
        </span>
    );
}

const stats = [
    { value: 1000, suffix: '+', label: 'Sample Orders (demo)', icon: PackageIcon },
    { value: 12, suffix: '', label: 'Sample Regions', icon: Location01Icon },
    { value: 50, suffix: '+', label: 'Sample Dealers', icon: Agreement01Icon },
    { value: 99, suffix: '%', label: 'Placeholder Rating', icon: StarIcon },
];

export default function StatsSection() {
    return (
        <section className="relative overflow-hidden bg-[#e0e7ff] px-4 py-10 sm:px-6 sm:py-16 lg:px-7">
            <div className="absolute left-0 top-0 h-96 w-96 rounded-full bg-white/25 blur-[120px]" />
            <div className="absolute bottom-0 right-0 h-64 w-64 rounded-full bg-[#312e81]/10 blur-[100px]" />

            <div className="relative z-10 mx-auto max-w-7xl overflow-hidden rounded-[2.3rem] bg-[#17153b] px-5 py-8 text-white shadow-[0_28px_80px_rgba(30,27,75,0.18)] sm:px-8 sm:py-10 lg:px-12 lg:py-12">
                <div className="absolute -right-24 -top-28 h-72 w-72 rounded-full bg-[#e0e7ff]/10 blur-2xl" />
                <div className="absolute bottom-0 left-1/2 h-px w-3/4 -translate-x-1/2 bg-gradient-to-r from-transparent via-white/20 to-transparent" />

                <ScrollReveal className="relative mb-8 grid grid-cols-1 gap-5 lg:mb-10 lg:grid-cols-[0.75fr_1fr] lg:items-end">
                    <div>
                        <div className="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/8 px-4 py-2 text-xs font-semibold text-white/80 shadow-[inset_0_1px_0_rgba(255,255,255,0.12)]">
                            <span className="h-2 w-2 rounded-full bg-[#e0e7ff]" />
                            Demo Statistics
                        </div>
                        <h3 className="mt-4 max-w-xl text-4xl font-semibold leading-[1.02] tracking-[-0.024em] text-white md:text-6xl">
                            Our Impact in Numbers
                        </h3>
                    </div>
                    <p className="max-w-xl text-base leading-7 text-white/64 lg:justify-self-end">
                        These figures are invented placeholders that demonstrate how headline statistics would appear on the site.
                    </p>
                </ScrollReveal>

                <div className="relative grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4 lg:gap-4">
                    {stats.map((stat, i) => (
                        <ScrollReveal key={i} delay={i * 150}>
                            <div className="group relative h-full overflow-hidden rounded-[1.8rem] border border-white/10 bg-[linear-gradient(145deg,rgba(255,255,255,0.11),rgba(255,255,255,0.035))] p-5 shadow-[inset_0_1px_0_rgba(255,255,255,0.10)] transition-all duration-300 hover:-translate-y-1 hover:border-white/18 hover:bg-white/[0.09] sm:p-6">
                                {/* Dithered glow from the top-right corner. */}
                                <DitherField reach={0.72} alpha={0.3} className="opacity-80 transition-opacity duration-500 group-hover:opacity-100" />
                                <div className="relative mb-6 flex items-center justify-between">
                                    <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#e0e7ff]/12 text-[#e0e7ff] ring-1 ring-white/10">
                                        <Icon icon={stat.icon} size={23} />
                                    </span>
                                    <span className="text-[11px] font-black uppercase tracking-[0.2em] text-white/32">0{i + 1}</span>
                                </div>
                                <div className="relative mb-2 text-4xl font-semibold tracking-[-0.018em] text-white md:text-5xl">
                                    <Counter end={stat.value} suffix={stat.suffix} />
                                </div>
                                <p className="relative border-t border-white/10 pt-3 text-xs font-bold uppercase tracking-widest text-white/48">
                                    {stat.label}
                                </p>
                            </div>
                        </ScrollReveal>
                    ))}
                </div>
            </div>
        </section>
    );
}
