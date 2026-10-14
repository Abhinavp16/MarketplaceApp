import { SITE_SHORT_NAME } from '@/lib/site-config';

// Shared product pages carry a small "open in the app" box. The demo has no
// published mobile app (Android-only, unpublished), so there are no Play Store /
// App Store links, no intent links and no automatic redirects: the box only
// explains that. Where a real deployment would show the store buttons, the demo
// shows disabled placeholders and a note.
export default function OpenInApp() {
    return (
        <div
            data-testid="open-in-app"
            className="rounded-[1.6rem] border border-green-100 bg-[#f1f7ec] p-5"
        >
            <p className="text-sm font-bold text-text-primary">
                See prices and order in the {SITE_SHORT_NAME} app
            </p>
            <div className="mt-4 flex flex-wrap gap-3">
                <span
                    aria-disabled="true"
                    className="inline-flex cursor-not-allowed items-center justify-center rounded-full border border-gray-200 bg-white px-5 py-2.5 text-sm font-bold text-text-primary opacity-60"
                >
                    Get it on Google Play
                </span>
                <span className="text-xs font-semibold text-[#4f6248]">
                    Demo only — no mobile app is published
                </span>
            </div>
        </div>
    );
}
