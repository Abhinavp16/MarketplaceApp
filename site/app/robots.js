import { SITE_URL } from '@/lib/site-config';

// Demo site: disallow all crawling.
export default function robots() {
    return {
        rules: { userAgent: '*', disallow: '/' },
        host: SITE_URL,
    };
}
