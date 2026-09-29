import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Dealer Pricing Policy",
    description: "Demo placeholder dealer pricing policy for TradeHub Demo.",
};

const sections = [
        {  paragraphs: ["Placeholder: dealer pricing might vary by product line, order volume, service area and support obligations.", "Placeholder: public pricing, wholesale tiers, negotiated rates and promotions could be managed separately depending on the partner model.", "All prices in this demonstration environment are synthetic."] },
];

export default function DealerPricingPage() {
    return <LegalPage title="Dealer Pricing Policy" subtitle="Demo placeholder: general pricing guidance for dealers and partners." sections={sections} />;
}
