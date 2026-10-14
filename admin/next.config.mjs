// The demo API this panel talks to (REST and the live socket). It is configured
// only through NEXT_PUBLIC_API_BASE_URL; the local demo backend is always allowed.
const apiOrigins = () => {
  const origins = new Set(['http://localhost:5050', 'ws://localhost:5050'])
  try {
    const api = new URL(process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:5050/api/v1')
    origins.add(api.origin)
    origins.add(`${api.protocol === 'https:' ? 'wss:' : 'ws:'}//${api.host}`)
  } catch {
    // Invalid URL: the defaults above still apply.
  }
  return [...origins]
}

const isDev = process.env.NODE_ENV !== 'production'

// Browser alerts (Firebase Cloud Messaging) are optional. The extra hosts below are
// added to the policy only when a Firebase project id is configured; otherwise the
// policy is exactly as strict as before.
const firebaseEnabled = Boolean(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID)
const firebaseConnect = firebaseEnabled
  ? [
      'https://fcmregistrations.googleapis.com',
      'https://firebaseinstallations.googleapis.com',
      'https://fcm.googleapis.com',
      'https://www.googleapis.com',
      'https://*.googleapis.com',
    ]
  : []
// The service worker pulls the Firebase SDK from gstatic via importScripts.
const firebaseScript = firebaseEnabled ? ['https://www.gstatic.com'] : []

// Where the panel may load things from. Inline scripts stay allowed because
// Next.js needs them; the main protections are no framing (clickjacking), no
// plugins, and data can only be sent to the demo API and the map/icon hosts.
const contentSecurityPolicy = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline'${isDev ? " 'unsafe-eval'" : ''} https://unpkg.com ${firebaseScript.join(' ')}`.trim(),
  "style-src 'self' 'unsafe-inline' https://unpkg.com",
  ['img-src', "'self'", 'data:', 'blob:', ...apiOrigins().filter((o) => o.startsWith('http')), 'https:'].join(' '),
  ['media-src', "'self'", 'blob:', ...apiOrigins().filter((o) => o.startsWith('http')), 'https:'].join(' '),
  "font-src 'self' data:",
  [
    "connect-src 'self'",
    ...apiOrigins(),
    'https://unpkg.com',
    'https://*.tile.openstreetmap.org',
    ...firebaseConnect,
    ...(isDev ? ['ws://localhost:*', 'http://localhost:*'] : []),
  ].join(' '),
  'frame-src https://www.openstreetmap.org https://www.youtube.com https://www.youtube-nocookie.com',
  "worker-src 'self' blob:",
  "manifest-src 'self'",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "object-src 'none'",
].join('; ')

const securityHeaders = [
  { key: 'Content-Security-Policy', value: contentSecurityPolicy },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'no-referrer' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), payment=(), usb=()' },
  // HTTPS-only header: sent in production builds, never while developing on http://localhost.
  ...(isDev ? [] : [{ key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' }]),
  // The panel is private: keep it out of search engines.
  { key: 'X-Robots-Tag', value: 'noindex, nofollow' },
]

/** @type {import('next').NextConfig} */
const nextConfig = {
  poweredByHeader: false,
  images: {
    unoptimized: true,
  },
  async headers() {
    return [{ source: '/:path*', headers: securityHeaders }]
  },
  // Member pages used to live under /staff; keep old links and bookmarks working.
  async redirects() {
    return [
      { source: '/staff', destination: '/member', permanent: false },
      { source: '/staff/:path*', destination: '/member/:path*', permanent: false },
      { source: '/staff-management', destination: '/member-management', permanent: false },
    ]
  },
}

export default nextConfig
