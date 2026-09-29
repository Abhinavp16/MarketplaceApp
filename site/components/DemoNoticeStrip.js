import { DEMO_NOTICE } from '@/lib/site-config';

export default function DemoNoticeStrip() {
    return (
        <div
            role="note"
            className="relative z-[60] flex h-8 items-center justify-center bg-[#1e1b4b] px-3 text-center text-[11px] font-semibold uppercase tracking-[0.14em] text-white sm:text-xs"
        >
            <span className="mr-2 inline-block h-1.5 w-1.5 rounded-full bg-[#5eead4]" aria-hidden="true" />
            {DEMO_NOTICE}
        </div>
    );
}
