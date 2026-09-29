'use client';

import { useState } from 'react';
import Link from 'next/link';
import ScrollReveal from '@/components/ScrollReveal';

const INITIAL_VISIBLE_COUNT = 12;

const defaultCategories = [];

const defaultSection = {
    eyebrow: 'PRODUCT CATEGORIES',
    title: 'Browse by Category',
    description: 'Explore demo catalogue categories and brands.',
    buttonText: 'View Products',
};

export default function CategoriesSection({
    categories = defaultCategories,
    section = defaultSection,
}) {
    const [expanded, setExpanded] = useState(false);
    const visibleCategories = expanded ? categories : categories.slice(0, INITIAL_VISIBLE_COUNT);
    const shouldShowViewMoreCard = !expanded && categories.length > INITIAL_VISIBLE_COUNT;
    const remainingCount = Math.max(categories.length - INITIAL_VISIBLE_COUNT, 0);

    return (
        <section id="categories" className="bg-[#e0e7ff] px-4 py-16 sm:px-6 sm:py-24 lg:px-7">
            <div className="mx-auto max-w-7xl">
            <ScrollReveal className="mb-12 grid grid-cols-1 gap-5 lg:mb-16 lg:grid-cols-[0.8fr_1fr] lg:items-end">
                <div>
                    <div className="home-kicker">{section.eyebrow}</div>
                    <h3 className="mt-5 max-w-xl text-4xl font-semibold leading-[1.02] tracking-[-0.024em] text-text-primary md:text-6xl">{section.title}</h3>
                </div>
                <p className="max-w-xl text-base leading-7 text-text-secondary lg:justify-self-end">{section.description}</p>
            </ScrollReveal>

            {categories.length === 0 && (
                <div className="rounded-[2rem] border border-dashed border-[#312e81]/25 bg-white/60 p-10 text-center">
                    <h3 className="text-2xl font-bold text-text-primary">Catalogue unavailable</h3>
                    <p className="mt-3 text-text-secondary">No categories were returned. Start the demo backend and refresh this page.</p>
                </div>
            )}

            <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6 lg:gap-4">
                {visibleCategories.map((cat, i) => {
                    const href = cat.href || `/category/${encodeURIComponent(cat.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')).replace(/^-|-$/g, '')}`;
                    return (
                        <ScrollReveal key={i} delay={i * 80}>
                            <Link
                                href={href}
                                className="group mx-auto flex h-full w-full max-w-[220px] cursor-pointer flex-col overflow-hidden rounded-[1.35rem] border border-[#312e81]/10 bg-[#eef2ff]/80 p-2 shadow-[0_16px_40px_rgba(30,27,75,0.08)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_22px_55px_rgba(30,27,75,0.14)]"
                            >
                                <div className="flex aspect-[4/3] items-center justify-center overflow-hidden rounded-[1.2rem] bg-[#c7d2fe]">
                                    <img
                                        src={cat.image}
                                        className="h-full w-full object-cover object-center transition-transform duration-500 group-hover:scale-105"
                                        alt={cat.name}
                                    />
                                </div>
                                <div className="flex min-h-[84px] flex-1 flex-col justify-between px-1.5 py-3">
                                    <h3 className="text-sm font-semibold leading-tight tracking-[-0.018em] text-text-primary sm:text-base">
                                        {cat.name}
                                    </h3>
                                    <div className="mt-3 flex items-center justify-between border-t border-[#312e81]/10 pt-2.5 text-[11px] font-semibold text-brand-primary">
                                        <span>{section.buttonText || 'View Products'}</span>
                                        <span className="flex h-7 w-7 items-center justify-center rounded-full bg-white/60">→</span>
                                    </div>
                                </div>
                            </Link>
                        </ScrollReveal>
                    );
                })}

                {shouldShowViewMoreCard && (
                    <ScrollReveal delay={visibleCategories.length * 80}>
                        <button
                            type="button"
                            onClick={() => setExpanded(true)}
                            className="group mx-auto flex h-full min-h-[15rem] w-full max-w-[220px] flex-col items-center justify-center rounded-[1.35rem] border border-white/10 bg-[#17153b] px-5 text-center text-white shadow-[0_16px_40px_rgba(30,27,75,0.16)] transition-all duration-300 hover:-translate-y-1"
                        >
                            <div className="mb-5 flex h-20 w-20 items-center justify-center rounded-full border border-white/30 bg-white/8">
                                <svg
                                    xmlns="http://www.w3.org/2000/svg"
                                    width="34"
                                    height="34"
                                    viewBox="0 0 24 24"
                                    fill="none"
                                    stroke="currentColor"
                                    strokeWidth="2.2"
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    className="transition-transform duration-300 group-hover:translate-x-1"
                                >
                                    <path d="M5 12h14" />
                                    <path d="m12 5 7 7-7 7" />
                                </svg>
                            </div>
                            <h3 className="text-3xl font-bold">View More</h3>
                            <p className="mt-3 text-sm font-medium text-white/85">
                                Show {remainingCount} more categories
                            </p>
                        </button>
                    </ScrollReveal>
                )}
            </div>
            </div>
        </section>
    );
}
