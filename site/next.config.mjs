// Allow <Image>/remote images only from the demo backend origin derived from NEXT_PUBLIC_API_BASE_URL
// (localhost:5050 by default for local demos). No production hosts are configured.
function backendPattern() {
  try {
    const url = new URL(process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:5050/api/v1');
    return {
      protocol: url.protocol.replace(':', ''),
      hostname: url.hostname,
      port: url.port || '',
      pathname: '/**',
    };
  } catch {
    return { protocol: 'http', hostname: 'localhost', port: '5050', pathname: '/**' };
  }
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      backendPattern(),
      { protocol: 'http', hostname: 'localhost', port: '5050', pathname: '/**' },
    ],
  },
};

export default nextConfig;
