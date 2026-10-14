// Demo backend origin derived from NEXT_PUBLIC_API_BASE_URL (localhost:5050 by default).
// No production hosts are configured: this is an isolated sales demo.
const DEFAULT_API = 'http://localhost:5050/api/v1';

function configuredApiUrl() {
  const raw = (process.env.NEXT_PUBLIC_API_BASE_URL || DEFAULT_API).trim().replace(/^['"]|['"]$/g, '');
  try {
    return new URL(raw);
  } catch {
    return new URL(DEFAULT_API);
  }
}

// Allow <Image>/remote images only from the demo backend origin.
function backendPattern() {
  const url = configuredApiUrl();
  return {
    protocol: url.protocol.replace(':', ''),
    hostname: url.hostname,
    port: url.port || '',
    pathname: '/**',
  };
}

// The API the website calls from the browser (also serves /uploads/demo/* images).
const apiOrigins = () => {
  const origins = new Set(['http://localhost:5050']);
  origins.add(configuredApiUrl().origin);
  return [...origins];
};

const isDev = process.env.NODE_ENV !== 'production';

// Where the website may load things from. Inline scripts stay allowed because
// Next.js needs them; the main protections are no framing (clickjacking), no
// plugins, and data can only be sent to the demo API.
const api = apiOrigins().join(' ');
const contentSecurityPolicy = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline'${isDev ? " 'unsafe-eval'" : ''}`,
  "style-src 'self' 'unsafe-inline'",
  `img-src 'self' data: blob: ${api}`,
  `media-src 'self' blob: ${api}`,
  "font-src 'self' data:",
  ["connect-src 'self'", api, ...(isDev ? ['ws://localhost:*', 'http://localhost:*'] : [])].join(' '),
  "frame-src 'none'",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "object-src 'none'",
].join('; ');

const securityHeaders = [
  { key: 'Content-Security-Policy', value: contentSecurityPolicy },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), payment=(), usb=()' },
  // HSTS only makes sense over HTTPS in production, never for the local demo.
  ...(isDev ? [] : [{ key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' }]),
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  poweredByHeader: false,
  images: {
    remotePatterns: [
      backendPattern(),
      { protocol: 'http', hostname: 'localhost', port: '5050', pathname: '/**' },
    ],
  },
  async headers() {
    return [{ source: '/:path*', headers: securityHeaders }];
  },
};

export default nextConfig;
