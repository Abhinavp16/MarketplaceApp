import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Warranty Policy",
    description: "Demo placeholder warranty policy for TradeHub Demo.",
};

const sections = [
        {  paragraphs: ["Placeholder: warranty coverage would vary by manufacturer and product category and typically applies to verified manufacturing defects.", "Placeholder: claims might require proof of purchase, issue documentation and inspection before a repair or replacement decision.", "No real warranty is offered for the synthetic products shown in this demo."] },
];

export default function WarrantyPage() {
    return <LegalPage title="Warranty Policy" subtitle="Demo placeholder: general warranty guidelines." sections={sections} />;
}
