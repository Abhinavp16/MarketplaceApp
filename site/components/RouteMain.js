'use client';

import { useEffect } from 'react';
import { usePathname } from 'next/navigation';

export default function RouteMain({ children }) {
    const pathname = usePathname();

    useEffect(() => {
        window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
    }, [pathname]);

    return (
        <main className="pt-0">
            <div key={pathname} className="route-transition">
                {children}
            </div>
        </main>
    );
}
