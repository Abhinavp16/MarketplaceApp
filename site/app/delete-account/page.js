import PageHero from '@/components/PageHero';
import ScrollReveal from '@/components/ScrollReveal';
import AccountDeletionRequestForm from '@/components/AccountDeletionRequestForm';
import { CONTACT_EMAIL } from '@/lib/site-config';

export const metadata = {
    title: 'Request Account Deletion',
    description: 'Demo placeholder page showing how an account deletion request flow could look.',
};

export default function DeleteAccountPage() {
    return (
        <div className="page-transition">
            <PageHero
                title="Request Account Deletion"
                subtitle="Demo placeholder: an example of an account deletion request flow."
                breadcrumbItems={['Request Account Deletion']}
            />

            <section className="mx-auto max-w-4xl px-6 py-24">
                <ScrollReveal>
                    <div className="space-y-8 text-text-secondary leading-relaxed">
                        <div className="rounded-2xl border border-[#e0e7ff] bg-[#f5f6ff] p-6">
                            <h2 className="text-2xl font-bold text-text-primary">How this works (demo)</h2>
                            <p className="mt-3">In a real deployment, a user would submit the name and registered mobile number for their account and the operator would verify the request before completing it. In this demonstration environment the form below is a no-op: nothing is submitted, sent or stored.</p>
                        </div>

                        <AccountDeletionRequestForm />

                        <div className="space-y-4 rounded-2xl border border-gray-200 bg-white p-6">
                            <h2 className="text-2xl font-bold text-text-primary">What would happen after completion</h2>
                            <p>Placeholder: account access would be revoked and profile details, saved addresses, uploaded media and notification history would be deleted or anonymised.</p>
                            <p>Placeholder: some order and payment records might be retained where required for tax, fraud-prevention or other legal obligations.</p>
                            <p>Demo contact: <a className="font-semibold text-[#0d9488] underline" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>.</p>
                        </div>
                    </div>
                </ScrollReveal>
            </section>
        </div>
    );
}
