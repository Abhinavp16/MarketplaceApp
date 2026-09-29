import InsightArticle from '@/components/InsightArticle';

export const metadata = {
    title: "Choosing a Reliable Supplier: A Demo Checklist",
    description: 'Demo placeholder article with generic, synthetic content.',
};

const sections = [
    { heading: "Confirm product quality and specifications", body: "Placeholder: ask for specification sheets, samples and quality certifications before placing a large order." },
    { heading: "Compare pricing transparently", body: "Placeholder: compare unit price, volume discounts, packing charges and delivery costs so the total cost is clear." },
    { heading: "Check lead times and stock levels", body: "Placeholder: reliable lead times matter as much as price. Confirm typical stock availability and how backorders are handled." },
    { heading: "Understand payment and return terms", body: "Placeholder: agree payment schedules, warranty coverage and return conditions in writing." },
    { heading: "Start small, then scale", body: "Placeholder: begin with a trial order to evaluate service before committing to larger volumes." },
];

export default function ChoosingASupplier() {
    return (
        <InsightArticle
            image="/demo/insights/insight-1.png"
            imageAlt="Abstract illustration of supplier checklist"
            category="Buying Guide"
            title="Choosing a Reliable Supplier: A Demo Checklist"
            lead="This is placeholder content. A good supplier relationship depends on clear communication, consistent quality and predictable delivery. Use this generic checklist as a starting point."
            sections={sections}
        />
    );
}
