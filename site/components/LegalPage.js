import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import { EFFECTIVE_DATE } from '@/lib/site-config';

// Shared layout for the demo legal / policy pages. All copy passed in is placeholder text.
export default function LegalPage({ title, subtitle, sections = [] }) {
    return (
        <div className="page-transition">
            <PageHero title={title} subtitle={subtitle} />

            <section className="py-24 px-6 max-w-4xl mx-auto">
                <ScrollReveal>
                    <div className="space-y-10 text-text-secondary leading-relaxed">
                        <p className="rounded-2xl border border-[#0d9488]/25 bg-teal-50 px-4 py-3 text-center text-sm font-semibold text-teal-800">
                            Demo placeholder content. This page is not a real legal document.
                        </p>
                        <p className="text-sm text-gray-400 italic text-center">Effective Date: {EFFECTIVE_DATE}</p>
                        {sections.map((section, index) => (
                            <div key={index}>
                                {section.heading && (
                                    <h2 className="text-3xl font-bold text-text-primary mb-4">{section.heading}</h2>
                                )}
                                {section.paragraphs.map((paragraph, i) => (
                                    <p key={i} className={i > 0 ? 'mt-4' : ''}>{paragraph}</p>
                                ))}
                            </div>
                        ))}
                    </div>
                </ScrollReveal>
            </section>
        </div>
    );
}
