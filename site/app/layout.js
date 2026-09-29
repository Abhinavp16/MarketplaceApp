import "./globals.css";
import DemoNoticeStrip from "@/components/DemoNoticeStrip";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import RouteMain from "@/components/RouteMain";
import { SITE_NAME, SITE_URL, TAGLINE } from "@/lib/site-config";

export const metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${SITE_NAME} - ${TAGLINE}`,
    template: `%s - ${SITE_NAME}`,
  },
  description:
    "TradeHub Demo is a fictional distribution business used to demonstrate a catalogue, dealer and ordering website. All content is synthetic placeholder data.",
  // This is a demonstration site: keep it out of search indexes.
  robots: {
    index: false,
    follow: false,
    nocache: true,
    googleBot: { index: false, follow: false },
  },
  icons: {
    icon: "/favicon.png",
    shortcut: "/favicon.ico",
    apple: "/apple-touch-icon.png",
  },
  openGraph: {
    title: `${SITE_NAME} - ${TAGLINE}`,
    description: "Demonstration environment with synthetic data.",
    images: ["/og-image.png"],
    siteName: SITE_NAME,
    type: "website",
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="font-secondary bg-neutral-background text-text-secondary overflow-x-hidden">
        <DemoNoticeStrip />
        <Header />
        <RouteMain>{children}</RouteMain>
        <Footer />
      </body>
    </html>
  );
}
