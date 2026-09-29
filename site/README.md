# TradeHub Demo - public website

Generic Next.js (App Router, Tailwind v4) marketing and catalogue site for the fictional
"TradeHub Distribution Pvt Ltd (Demo)". It is one part of an isolated sales-demo suite; all
content, brands, prices and contact details are synthetic.

## Run

```bash
cp .env.example .env.local        # points at the demo backend
npm install
npm run dev                       # http://localhost:3001
# or
npm run build && npm start        # production build on http://localhost:3001
npm run lint
```

The demo backend is expected at `http://localhost:5050/api/v1`. The site still builds and renders
(with empty states) when the backend is down.

## Environment

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_API_BASE_URL` | Only source of the API base URL. Catalogue calls and backend-hosted image URLs are derived from it. No production fallback exists; if unset, pages show empty states. |
| `NEXT_PUBLIC_SITE_URL` | Used for metadata base only (the site is `noindex`). |

## What reads from the backend

`lib/catalog-api.js`, `lib/website-content.js`, `lib/featured-products.js`, `lib/category-products.js`
call `/website/catalog/*` (home, brands, categories, products) and optionally `/settings/website-content`.
Every call is fail-soft (network errors and non-2xx responses resolve to empty data). Category and brand
slugs, product IDs and featured products are not hardcoded; whatever the API returns is rendered.
Bundled tiles in `public/demo/categories` are used only as image fallbacks for the four demo category slugs
(`power-tools`, `hand-tools`, `fasteners-fittings`, `safety-gear`).

## What is placeholder

- All copy: home hero, about, contact, dealership, insights articles and legal pages
  (privacy, terms, refund, shipping, warranty, dealer agreement, dealer pricing, delete account).
  They are short "demo placeholder" texts, not legal documents.
- Identity constants live in `lib/site-config.js` (brand, legal name, tagline, email, phone, address).
- Hero, category, about, insight and dealer images under `public/demo/` are real photographs that are free
  for commercial use with no attribution obligation (CC0 / public domain from Wikimedia Commons, Pexels
  License from Pexels); every source is listed in `../backend/assets/demo-images/CREDITS.md`.
- `scripts/generate_assets.py` (Pillow, `npm run assets`) only generates the synthetic brand graphics:
  logo, favicon, OG image, brand tiles (copies of the backend wordmark logos), neutral placeholders and the
  phone-frame `app-preview.png` (built from `../docs/screenshots/app-home.png`). The palette is teal
  (see `app/globals.css` `@theme`).
- A "Demonstration Environment - synthetic data" strip is rendered on every page (`components/DemoNoticeStrip.js`).

## Limitations

- No form sends anything. Contact, dealership, inquiry popup and account deletion forms only show
  "Inquiry received (demo - no message sent)" (no WhatsApp, email or API calls, nothing stored).
- Social links in the footer/quick-contact panel are dummy links to `/contact`.
- The contact page shows a map placeholder, not an embedded map. No analytics, tracking scripts or
  third-party fonts are loaded.
- Robots: `<meta name="robots" content="noindex,nofollow">` and `robots.txt` disallow all. There is no
  sitemap or structured data.
- Images from the API are rendered with plain `<img>` tags (ESLint `no-img-element` warnings are expected).
  `next.config.mjs` allows `localhost:5050` for `next/image` should you switch.
- Static assets live under `/demo/*`; other root-relative image paths returned by the API are resolved
  against the API origin (see `lib/media-url.js`).
