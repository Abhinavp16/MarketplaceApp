# DemoMart Admin

Next.js admin and staff panel for the **DemoMart** sales demonstration
("Distribution made simple"). It runs against the local demo backend and shows
only synthetic data.

## Run

```bash
cp .env.example .env.local     # NEXT_PUBLIC_API_BASE_URL=http://localhost:5050/api/v1
npm install
npm run dev                    # http://localhost:3000
# or: npm run build && npm start
```

`NEXT_PUBLIC_API_BASE_URL` is the only required setting. It is read at build
time. The Socket.IO URL is derived from it (same host, without `/api/v1`). There
is no fallback host: if it is unset, API calls return a clear configuration
error and the socket hooks throw. Optional: `NEXT_PUBLIC_WEBSITE_BASE_URL` (link
target used by the Manage Website page, defaults to `https://demo.demomart.example`).

## Demo login

- Admin: `admin@demomart.example` / `Demo@12345` (email + password form on `/login`,
  posts to `POST /auth/login`; the backend must run with `DEMO_MODE=true`).
  The login page shows the hint and a "Fill demo credentials" button.
- Staff: click **Staff login** on the login page (username + password, `POST /auth/staff/login`).
  Staff land on `/member/orders`.

## Demo behaviour

- A persistent strip "Demonstration Environment — synthetic data" is shown in the admin
  and staff layouts (reads `GET /demo/info`; static text if unreachable).
- **Reset Demo** (Settings page, bottom card): only visible when `/demo/info` returns
  `demoMode: true`. Opens a dialog that requires typing `RESET DEMO`, calls
  `POST /admin/demo/reset` with `{"confirm":"RESET DEMO"}`, shows a success/failure
  toast, then reloads the page to refetch data.
- Staff panel: the negotiation "Accept Deal & Create Order" and "Create Missing Order"
  actions are disabled with the tooltip "Approval is reserved for the business owner in this demo".
- Sockets authenticate with the JWT (`auth: { token }`) on connect, and the token is
  also sent in the `join-negotiation` and `join-admin` events (the backend checks it per event).
- Sign-out (`endSession()` in `lib/api.ts`) calls `POST /auth/logout` with the refresh token
  (best effort) and clears the stored session. Both sidebars use it.

## Features

Receipts (download, share, print PDF) from Deal Desk and Orders; Deal Desk requirement
groups (group panel, accept dialog with delivery charge and shipping address, decline
dialog, clear declined); customer-order accept dialog with delivery charge; pack-aware
product form (Packet, Coil, Bundle) with a live pack preview; Coming Soon fields on the
product form plus a list badge and filter; "Hide from customers" on brands and categories;
per-customer hidden brands on Customer Profile and Account Upgrades; a shared Leads page
(`/potential-customers`, and `/member/leads` for members); banner drag-and-drop reorder with
validation reasons; account-deletion identity-verification gate and badges; a price-update
nudge (`POST /admin/price-updates/flush`) after immediate price saves; security headers
(CSP, frame/nosniff/referrer/permissions policies, noindex, HSTS in production builds) in
`next.config.mjs`; and bulk product import (see "Import products").

## Import products

Admin only (the staff panel under `/member` has no import). On **Products**, the **Import
products** button opens a three-step dialog (`components/products/import-products-dialog.tsx`,
API helper in `lib/catalog-import.ts`); **Template** next to it downloads
`catalog-import-template.xlsx` (`GET /admin/products/import/template`).

1. **Upload**: drag a `.xlsx` or `.csv` file (max 5 MB, 5,000 rows) or choose one. Options:
   "Create missing brands and categories" (off by default) and, under Advanced, when price
   changes take effect (apply immediately, or schedule in 24 hours). Choosing a file runs a
   dry run automatically (`POST /admin/products/import?dryRun=true`).
2. **Review**: tiles for Rows, New, Updated, Unchanged, Errors and Warnings, a banner saying
   nothing is saved yet, brands/categories that will be created, ignored columns, and a row
   table (Create / Update / Unchanged, status, expandable errors, warnings and before-to-after
   changes) with All / Errors / Warnings / Changes filters and a SKU search. "Import N
   products" stays disabled while any row has errors; fix the file and upload it again.
3. **Result**: the same file and options are sent with `dryRun=false`. The summary shows
   created, updated and unchanged counts, and notes scheduled price changes. "Close and
   refresh list" reloads the products list.

Request-level failures (wrong file type, too large, too many rows, missing columns) show as a
toast and an inline alert; row problems come back inside the preview. Tests:
`tests/catalog-import.spec.ts` (mocked API). Sample files live in `../docs/`.

## Browser alerts (optional, Firebase Cloud Messaging)

Off by default. With every `NEXT_PUBLIC_FIREBASE_*` variable empty (see `.env.example`), the
Notifications page shows "Browser alerts are not configured for this environment" and no
Firebase code runs or is loaded. To turn it on, follow `../docs/FIREBASE_SETUP.md`: set
`NEXT_PUBLIC_FIREBASE_API_KEY`, `_AUTH_DOMAIN`, `_PROJECT_ID`, `_STORAGE_BUCKET`,
`_MESSAGING_SENDER_ID`, `_APP_ID` and `_VAPID_KEY` in `.env.local`, then restart `npm run dev`
(or rebuild).

- `lib/firebase-client.ts` reads the keys; `lib/hooks/useAdminPush.ts` registers the browser's
  token with `POST /notifications/register-token` (`platform: web`) and removes it with
  `POST /notifications/unregister-token`. The choice is remembered per admin as
  `adminPushWanted:<userId>` and `restoreAdminPush()` switches alerts back on silently after
  sign-in (only if permission is already granted).
- `scripts/generate-sw.js` writes `public/sw.js` from `public/sw.template.js` on `predev` and
  `prebuild`. With empty keys the result is the plain offline-shell worker with no Firebase;
  with keys it also handles background FCM messages. `public/sw.js` is gitignored.
- The CSP in `next.config.mjs` adds the Firebase hosts (fcmregistrations, firebaseinstallations,
  googleapis, gstatic) only when `NEXT_PUBLIC_FIREBASE_PROJECT_ID` is set.

## What was removed or replaced

- The third-party hosting analytics package and its import.
- Magic-link request UI on the login page (replaced by an email and password form; the `/login/verify` page is kept but unused).
- `public/sw.js` is generated (see "Browser alerts") and registered only in production builds.
- All original-client branding, hard-coded production hosts, map centre (now India centre 20.5937, 78.9629),
  store links (now placeholders), and the original Mongo/JWT Playwright login helper.
- Visual design is identical to the original panel (green primary, same Tailwind/CSS tokens, fonts and
  class names in every shared file); only the branding text and logo were replaced. Demo-only components
  (`DemoBanner`, `ResetDemoCard`, password login form, catalog import dialog) use the same green tokens.
- Generated assets in `public/` (green DemoMart "D." mark): `icon.svg`, `icon.png`, `icon-192.png`, `icon-maskable-512.png`,
  `apple-touch-icon.png`, `favicon.ico`, `images/Banner/1-5.jpg` (real royalty-free photos, see `../backend/assets/demo-images/CREDITS.md`).

## Tests

`npm test` runs Playwright (dev server on port 3000). All specs except `demo-login`
mock the API with `page.route` (and `routeWebSocket` for the live deal socket). Run with
`--workers=1` if the dev server is slow to compile and timeouts appear. `tests/demo-login.spec.ts` signs in against the local demo backend
(`DEMO_API_URL`, default `http://localhost:5050/api/v1`) and needs it running with `DEMO_MODE=true`.

## Limitations

- The Wholesaler Map page loads Leaflet from unpkg and tiles from OpenStreetMap, and a few
  image fallbacks use placehold.co, so those need internet access.
- `npm run typecheck` is clean and the build no longer ignores type errors.
  `npm run lint` still reports React-compiler rule errors (set-state-in-effect, purity) in
  older files, unrelated to the demo changes.
- The CSP in `next.config.mjs` allows the local demo API (`http://localhost:5050`,
  `ws://localhost:5050`), unpkg (Leaflet) and OpenStreetMap; change it if the API moves.
- Browser alerts are off until you add your own Firebase web keys (see "Browser alerts"); real
  push delivery has not been verified against a live Firebase project.
- The staff minimum-price check (`staffMinPrice`) has no backing data and is treated as "no minimum".
- Store-URL validation on Settings no longer enforces specific store listings (placeholders only).
- Some data-driven copy (labels, settings fields) comes from the backend seed, not this app.
