import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Shipping Policy",
    description: "Demo placeholder shipping policy for TradeHub Demo.",
};

const sections = [
        {  paragraphs: ["Placeholder: orders would be processed based on stock, payment status, delivery zone and logistics capacity. Delivery arrangements, freight charges and payment steps would be confirmed per order. No real goods are shipped from this demonstration environment."] },
];

export default function ShippingPage() {
    return <LegalPage title="Shipping Policy" subtitle="Demo placeholder: delivery, dispatch and order fulfilment guidelines." sections={sections} />;
}
