'use client';

import { useRouter } from 'next/navigation';
import Icon from '@/components/Icon';
import { ArrowLeft01Icon } from '@hugeicons/core-free-icons';

export default function BackButton({ fallbackHref = '/' }) {
    const router = useRouter();

    const handleBack = () => {
        if (typeof window !== 'undefined' && window.history.length > 1) {
            router.back();
            return;
        }

        router.push(fallbackHref);
    };

    return (
        <button
            type="button"
            onClick={handleBack}
            className="inline-flex h-12 items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 text-white shadow-[0_10px_30px_rgba(15,23,42,0.28)] backdrop-blur-md transition-colors hover:bg-white/16"
            aria-label="Go back"
        >
            <Icon icon={ArrowLeft01Icon} size={20} strokeWidth={2.4} className="h-5 w-5" />
            <span className="text-sm font-semibold tracking-wide">Back</span>
        </button>
    );
}
