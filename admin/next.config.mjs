/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
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
