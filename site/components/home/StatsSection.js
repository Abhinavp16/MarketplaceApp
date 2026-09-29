'use client';
import { useEffect, useRef, useState } from 'react';
import ScrollReveal from '@/components/ScrollReveal';

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
    { value: 1000, suffix: '+', label: 'Sample Orders (demo)', icon: 'M20 7.5 12 3 4 7.5m16 0-8 4.5m8-4.5v9L12 21m0-13.5L4 7.5m8 0V21M4 7.5v9L12 21' },
    { value: 12, suffix: '', label: 'Sample Regions', icon: 'M12 21s7-4.4 7-11a7 7 0 1 0-14 0c0 6.6 7 11 7 11Zm0-8.5A2.5 2.5 0 1 0 12 7a2.5 2.5 0 0 0 0 5.5Z' },
    { value: 50, suffix: '+', label: 'Sample Dealers', icon: 'M8.5 11.5 11 14l4.5-4.5M3.5 12.5l4.2-4.2a3 3 0 0 1 4.2 0l.6.6.6-.6a3 3 0 0 1 4.2 0l3.2 3.2a3 3 0 0 1 0 4.2l-3.8 3.8a3 3 0 0 1-4.2 0L12 19l-.4.4a3 3 0 0 1-4.2 0l-3.9-3.9a2.1 2.1 0 0 1 0-3Z' },
    { value: 99, suffix: '%', label: 'Placeholder Rating', icon: 'm12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3 6.4 20.2 7.5 14 3 9.6l6.2-.9L12 3Z' },
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
                                <div className="absolute -right-10 -top-10 h-28 w-28 rounded-full bg-[#e0e7ff]/8 transition-transform duration-500 group-hover:scale-125" />
                                <div className="relative mb-6 flex items-center justify-between">
                                    <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#e0e7ff]/12 text-[#e0e7ff] ring-1 ring-white/10">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                                            <path d={stat.icon} />
                                        </svg>
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
