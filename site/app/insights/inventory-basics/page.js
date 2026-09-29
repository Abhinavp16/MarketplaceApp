import InsightArticle from '@/components/InsightArticle';

export const metadata = {
    title: "Inventory Basics for Growing Distributors",
    description: 'Demo placeholder article with generic, synthetic content.',
};

const sections = [
    { heading: "Track what moves", body: "Placeholder: review sales by product regularly so fast movers are always in stock and slow movers are not over-ordered." },
    { heading: "Set reorder points", body: "Placeholder: define a minimum stock level for each item so that reorders happen before you run out." },
    { heading: "Organise the warehouse", body: "Placeholder: label locations clearly and group related items to speed up picking and reduce errors." },
    { heading: "Count regularly", body: "Placeholder: cycle counts catch discrepancies early and keep system stock aligned with the shelf." },
    { heading: "Use data to plan", body: "Placeholder: seasonal patterns and dealer feedback help forecast demand more accurately over time." },
];

export default function InventoryBasics() {
    return (
        <InsightArticle
            image="/demo/insights/insight-2.jpg"
            imageAlt="Abstract illustration of stacked inventory boxes"
            category="Operations"
            title="Inventory Basics for Growing Distributors"
            lead="This is placeholder content. Healthy inventory keeps customers supplied without tying up too much cash. These generic ideas apply to most distribution businesses."
            sections={sections}
        />
    );
}
