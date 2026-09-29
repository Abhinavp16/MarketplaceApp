import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Dealer & Distributor Agreement",
    description: "Demo placeholder dealer agreement overview for TradeHub Demo.",
};

const sections = [
        {  paragraphs: ["Placeholder: approved dealers might be asked to provide business registration details, tax information, service coverage and order capability.", "Placeholder: partner pricing, territory expectations and marketing permissions would be governed by formal commercial terms.", "This page is a template only and is not a binding agreement."] },
];

export default function DealerAgreementPage() {
    return <LegalPage title="Dealer & Distributor Agreement" subtitle="Demo placeholder: general guidance for dealer onboarding." sections={sections} />;
}
