import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Refund & Return Policy",
    description: "Demo placeholder refund and return policy for TradeHub Demo.",
};

const sections = [
        {  paragraphs: ["Placeholder: return eligibility would depend on product condition, delivery issues, inspection outcome and the commercial terms of the order.", "Placeholder: damaged or incorrect products would be reported promptly with supporting images. Used or altered items may not qualify.", "No real refunds or returns are processed in this demonstration environment."] },
];

export default function RefundPage() {
    return <LegalPage title="Refund & Return Policy" subtitle="Demo placeholder: general return and refund guidelines." sections={sections} />;
}
