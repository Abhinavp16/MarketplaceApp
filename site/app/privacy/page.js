import LegalPage from '@/components/LegalPage';

export const metadata = {
    title: "Privacy Policy",
    description: "Demo placeholder privacy policy for TradeHub Demo.",
};

const sections = [
        { heading: "1. Information We Collect", paragraphs: ["This is placeholder text. A real policy would describe the account, contact, order and device information a platform collects. In this demonstration environment all data is synthetic and no real personal information is required or stored."] },
        { heading: "2. How We Use Information", paragraphs: ["Placeholder: information would typically be used to create accounts, process orders, provide support, prevent fraud and meet legal obligations."] },
        { heading: "3. Data Sharing and Processing", paragraphs: ["Placeholder: describe any service providers (hosting, notifications, payments, logistics) that process data on your behalf. The demo does not share data with any third party."] },
        { heading: "4. Your Choices", paragraphs: ["Placeholder: explain how users can manage permissions and request access, correction or deletion of their data. See the demo account deletion page for an example of the flow."] },
        { heading: "5. Data Protection", paragraphs: ["Placeholder: summarise the technical and organisational safeguards in place. No system can guarantee absolute security."] },
        { heading: "6. Account Deletion and Retention", paragraphs: ["Placeholder: describe how deletion requests are handled and which records may be retained for legal reasons. The demo deletion form does not submit or store anything."] },
        { heading: "7. Contact", paragraphs: ["For questions about this demo, use the placeholder contact details: demo@tradehub.example or +91 00000 00000, 100 Demo Street, Sample City, Demo State 000000."] },
];

export default function PrivacyPage() {
    return <LegalPage title="Privacy Policy" subtitle="Demo placeholder: how platform data could be collected, used and protected." sections={sections} />;
}
