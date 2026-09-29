# Demo Guide

Suggested presentation flow, capability map and known limitations. The final sales pitch, claims and pricing are the business owner's call; this is a starting script.

## The problem it shows

Dealers bargain over WhatsApp and phone, prices go out of date, the owner can't see what a salesperson promised, and the agreed deal is typed in again as an order. This demo runs that whole path in one place: dealer request, owner counter-offer, one linked order, fulfilment.

## 3–5 minute walkthrough

Prepare: `npm run demo:reset`, backend running, app installed and signed in as the wholesaler, admin panel signed in on a laptop.

1. **0:00–0:30 Problem.** Describe the WhatsApp/phone/spreadsheet situation above.
2. **0:30–1:30 Dealer side (app).** Sign in as Sunrise Trade House. Browse Power Tools, open **18V Brushless Cordless Drill Driver** (Kestrel Works, list price ₹6,499, wholesale ₹5,200). Tap **Send Requirement**, enter quantity 20, target price ₹4,900 and a delivery message, and submit.
3. **1:30–2:40 Owner side (admin).** Open **Deal Desk**. The request appears live with the dealer, product, listed and target price, and history. Send a chat message, counter at ₹5,050, then **Accept**.
4. **2:40–3:30 Automatic handoff.** One order is created and linked to the deal. In the app the dealer sees the accepted deal and the order timeline. In admin: **Confirm payment**, then move the order to **Processing** and watch stock drop from 1,200 to 1,180.
5. **3:30–4:30 Owner control.** Show Products and pricing, Customers, Wholesaler approvals (pending applicant: NewCo Traders), Orders, and the dashboard. Sign in as staff to show a restricted panel where deal approval is disabled.
6. **4:30–5:00 Customization.** Use the table below.

After the run, reset (see the README) before the next prospect.

## Already works vs customized per client

| Already works | Customized for a new client |
|---|---|
| Roles (owner, staff, wholesaler, customer); catalog, brands, categories, pricing and stock; realtime negotiation with chat and counter-offer; one order per accepted deal; order status timeline; staff restricted panel; in-app notifications; dashboard and analytics; Hindi/English app; one-click demo reset | Branding and legal text; catalog structure and data import; approval rules and who can approve; taxes/GST and invoices; payment gateway; WhatsApp, push, email and SMS; courier and ERP integration; reports; additional languages; hosting |

## Claims to avoid (what the system does not do)

- Category restrictions are applied to catalog browsing, not to cart or order creation.
- Registering as a wholesaler does not wait for approval in the current code. The demo uses a pre-approved account.
- There is no online payment. The shop confirms payment manually.
- Negotiations have an expiry date but nothing expires them automatically.
- Only order, payment and staff actions are audited. Admin counters, price and product edits are not.

## Known limitations

- **Runs locally.** No hosted link yet: hosting needs an account and owner to be decided. Until then, run it on the presenter's laptop with the APK on the presenter's phone or emulator.
- **Android only.** iOS and Flutter web are out of scope. The APK is debug-signed; a release keystore is needed for distribution.
- **No screen recording yet.** Screenshots are in `docs/screenshots/`. The on-screen message field in the app's Send Requirement sheet is covered by widget tests and the backend flow, but was not exercised by hand in the emulator.
- **Presenter-driven.** Prospects do not get their own logins.
- **Public site** is a rebranded template with placeholder content.
- **Disabled by design:** push, email, WhatsApp, admin magic-link login (password login is used), staff deal approval.
- **Some product names** truncate on small cards.
- **Admin quirks:** the wholesaler map loads tiles from OpenStreetMap and needs internet. A few status colours shifted to the brand colour. Type-check and lint have pre-existing errors that don't block the build.
- **Unreachable app screens** (old mock screens not linked from navigation) still hold generic placeholder text and stock image links.
- **Fictional phone numbers** of the form `900000000x` are used for logins because the app validates 10-digit mobile numbers. They are placeholders, not real people.
- **Photos** are free-licence stock images. Several product photos are general shots of the tool type, not exact matches (for example the impact drill and the helmet). See `backend/assets/demo-images/CREDITS.md`.

## Technical review notes (for Adarsh)

- Guard: `backend/src/config/demoGuard.js` (start-up), `assertDemoDatabase()` (seed, reset, tests).
- Seed and fixtures: `backend/scripts/demo/`. End-to-end script: `backend/scripts/demo/e2e-flow.js`.
- Demo-only changes: socket connections require a JWT; staff accept is blocked in demo mode; the client-specific catalog logic and contact constants were removed; CORS no longer allows `*.vercel.app`.
- Endpoints added: `GET /api/v1/demo/info`, `POST /api/v1/admin/demo/reset`.
- App: no hosted-URL fallback (shows a configuration screen without `API_BASE_URL`), no Firebase, app ID `com.demo.tradehub`.
