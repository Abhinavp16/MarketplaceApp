import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Terms of Service",
    description: "Demo placeholder terms of service for TradeHub Demo.",
};

const sections = [
        { heading: "1. Platform Use", paragraphs: ["This is a demonstration environment operated by the fictional TradeHub Distribution Pvt Ltd (Demo). It exists to showcase a catalogue, dealer and ordering website. Nothing on this site is a real offer to sell goods."] },
        { heading: "2. Account Responsibility", paragraphs: ["Placeholder: users would be responsible for keeping account information accurate and for activity performed with their credentials."] },
        { heading: "3. Orders and Pricing", paragraphs: ["Placeholder: describe how quotes, prices and orders are confirmed. All prices, products and stock levels shown in the demo are synthetic."] },
        { heading: "4. Acceptable Use", paragraphs: ["Placeholder: describe prohibited activity such as misuse, scraping or attempts to disrupt the service."] },
        { heading: "5. Limitation of Liability", paragraphs: ["Placeholder: a real document would set out liability limits. The demo is provided as is, without any warranty."] },
        { heading: "6. Changes", paragraphs: ["Placeholder: terms may be updated from time to time. Content here is for demonstration only."] },
];

export default function TermsPage() {
    return <LegalPage title="Terms of Service" subtitle="Demo placeholder terms for using this demonstration site." sections={sections} />;
}
