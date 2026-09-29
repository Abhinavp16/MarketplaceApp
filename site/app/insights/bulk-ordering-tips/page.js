import InsightArticle from '@/components/InsightArticle';

export const metadata = {
    title: "Bulk Ordering Tips for Dealers and Retailers",
    description: 'Demo placeholder article with generic, synthetic content.',
};

const sections = [
    { heading: "Plan around demand", body: "Placeholder: order quantities should reflect realistic sales forecasts, not just the best discount tier." },
    { heading: "Consolidate orders", body: "Placeholder: combining products into one order can reduce freight and administrative costs." },
    { heading: "Agree delivery windows", body: "Placeholder: confirm delivery dates and receiving hours so goods can be checked and stored promptly." },
    { heading: "Inspect on arrival", body: "Placeholder: check quantities and condition at delivery and report issues straight away with photos." },
    { heading: "Keep records", body: "Placeholder: retain quotes, invoices and delivery notes to simplify reconciliation and future negotiations." },
];

export default function BulkOrderingTips() {
    return (
        <InsightArticle
            image="/demo/insights/insight-3.jpg"
            imageAlt="Abstract illustration of pallets and delivery"
            category="Dealer Tips"
            title="Bulk Ordering Tips for Dealers and Retailers"
            lead="This is placeholder content. Ordering in volume can improve margins when it is planned carefully. Here are some generic tips for dealers and retailers."
            sections={sections}
        />
    );
}
