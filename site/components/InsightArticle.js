import Link from 'next/link';

// Shared layout for the demo "insights" (blog-like) articles. All copy is generic placeholder text.
export default function InsightArticle({ image, imageAlt, category, date = 'Demo', title, lead, sections = [] }) {
    return (
        <main className="pt-24 pb-16 bg-neutral-surface min-h-screen">
            <div className="max-w-4xl mx-auto px-6">
                <Link href="/" className="inline-flex items-center text-brand-primary hover:underline mb-8 font-medium">
                    <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" /></svg>
                    Back to Home
                </Link>

                <article className="bg-white rounded-3xl shadow-sm border border-gray-100 overflow-hidden">
                    <div className="relative h-64 md:h-96 w-full">
                        <img src={image} alt={imageAlt} className="w-full h-full object-cover" />
                    </div>

                    <div className="p-8 md:p-12">
                        <div className="flex items-center gap-4 mb-6">
                            <span className="px-3 py-1 bg-brand-light text-brand-primary text-xs font-bold uppercase rounded-full">
                                {category}
                            </span>
                            <span className="text-sm text-gray-500">{date}</span>
                        </div>

                        <h1 className="text-3xl md:text-5xl font-bold text-text-primary mb-8 leading-tight">{title}</h1>

                        <p className="mb-8 rounded-2xl bg-teal-50 px-4 py-3 text-sm font-semibold text-teal-800">
                            Demo placeholder article. The content below is generic and synthetic.
                        </p>

                        <div className="prose prose-lg text-gray-600 max-w-none space-y-6">
                            <p className="lead text-xl">{lead}</p>
                            {sections.map((section) => (
                                <div key={section.heading}>
                                    <h3 className="text-xl font-bold text-text-primary mt-8">{section.heading}</h3>
                                    <p>{section.body}</p>
                                </div>
                            ))}
                        </div>
                    </div>
                </article>
            </div>
        </main>
    );
}
