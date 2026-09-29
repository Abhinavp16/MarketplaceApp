// The API base URL is derived from NEXT_PUBLIC_API_BASE_URL only (see .env.example).
// When it is not set, an empty string is returned and callers fall back to empty states.
export function getApiBaseUrl() {
    const rawBase = process.env.NEXT_PUBLIC_API_BASE_URL || '';
    return rawBase.trim().replace(/^['"]|['"]$/g, '').replace(/\/+$/, '');
}

export function getApiOrigin() {
    const base = getApiBaseUrl();
    if (!base) return '';
    try {
        return new URL(base).origin;
    } catch {
        return '';
    }
}

// Fail-soft JSON fetch: never throws, returns null when the backend is unavailable.
export async function fetchApiJson(path) {
    const base = getApiBaseUrl();
    if (!base) return null;
    try {
        const response = await fetch(`${base}${path}`, { cache: 'no-store' });
        if (!response.ok) return null;
        return await response.json();
    } catch {
        return null;
    }
}
