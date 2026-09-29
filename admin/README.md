# TradeHub Demo Admin

Next.js admin and staff panel for the **TradeHub Demo** sales demonstration
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
target used by the Manage Website page, defaults to `https://demo.tradehub.example`).

## Demo login

- Admin: `admin@tradehub.example` / `Demo@12345` (email + password form on `/login`,
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
- Sockets authenticate with the JWT (`auth: { token }`) on connect; the admin
  notification channel also sends it in `join-admin`.

## What was removed or replaced

- Firebase (SDK, `lib/firebase-client.ts`, `NEXT_PUBLIC_FIREBASE_*`, FCM in the service worker,
  push token registration). `useAdminPush` is now a no-op stub and the browser-alerts card
  was removed from Notifications.
- The third-party hosting analytics package and its import.
- Magic-link request UI on the login page (the `/login/verify` page is kept but unused).
- The build-time service worker generator; `public/sw.js` is now a small static PWA
  shell/offline worker, registered only in production builds.
- All client branding, hard-coded production hosts, map centre (now India centre 20.5937, 78.9629),
  store links (now placeholders), and the client Playwright tests/helpers.
- Brand colour: green replaced by indigo/teal (`app/globals.css`, `styles/globals.css`, and
  hard-coded hex/`emerald-*` utilities across the app).
- Generated assets in `public/`: `icon.svg`, `icon.png`, `icon-192.png`, `icon-maskable-512.png`,
  `apple-touch-icon.png`, `favicon.ico`, `images/Banner/1-5.jpg` (generic placeholders).

## Tests

`npm test` runs Playwright (dev server on port 3000). Most specs mock the API with
`page.route`. `tests/demo-login.spec.ts` signs in against the local demo backend
(`DEMO_API_URL`, default `http://localhost:5050/api/v1`) and needs it running with `DEMO_MODE=true`.

## Limitations

- The Wholesaler Map page loads Leaflet from unpkg and tiles from OpenStreetMap, and a few
  image fallbacks use placehold.co, so those need internet access.
- `next.config.mjs` keeps `typescript.ignoreBuildErrors: true` (inherited). `npm run typecheck`
  reports 4 pre-existing type errors (banners page, categories page `icon-xs` size).
  `npm run lint` reports pre-existing issues unrelated to the demo changes.
- The staff minimum-price check (`staffMinPrice`) has no backing data and is treated as "no minimum".
- Store-URL validation on Settings no longer enforces specific store listings (placeholders only).
- Some data-driven copy (labels, settings fields) comes from the backend seed, not this app.
