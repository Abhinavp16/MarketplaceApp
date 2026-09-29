import { DEMO_CONTACT_HINT, DEMO_INQUIRY_CONFIRMATION } from '@/lib/inquiry';

// Shown after a demo form is "submitted". Nothing is transmitted anywhere.
export default function DemoFormStatus({ submitted, className = '' }) {
    return (
        <div className={className} aria-live="polite">
            {submitted ? (
                <p role="status" className="rounded-2xl bg-teal-50 px-4 py-3 text-sm font-semibold text-teal-800">
                    {DEMO_INQUIRY_CONFIRMATION}
                </p>
            ) : (
                <p className="text-xs text-text-secondary">Demo form: submitting shows a confirmation only. {DEMO_CONTACT_HINT}</p>
            )}
        </div>
    );
}
