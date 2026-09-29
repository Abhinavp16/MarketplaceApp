import { getApiOrigin } from '@/lib/api-base';

// Site-local static assets live under /demo (plus a few root files such as /logo.png).
// Any other root-relative path is assumed to be served by the demo backend.
const LOCAL_PREFIXES = ['/demo/', '/logo', '/favicon', '/og-image', '/apple-touch-icon'];

export function normalizeWebsiteImageUrl(url) {
    const value = String(url || '').trim();
    if (!value) return '';

    if (/^https?:\/\//i.test(value) || value.startsWith('data:')) return value;

    if (value.startsWith('/')) {
        if (LOCAL_PREFIXES.some((prefix) => value.startsWith(prefix))) return value;
        const origin = getApiOrigin();
        return origin ? `${origin}${value}` : '';
    }

    return value;
}
