# DemoMart Distribution — B2B ordering platform demo (synthetic data only)

A self-contained demo showing how a distributor or manufacturer can run dealer negotiations, orders and catalog management in one system instead of WhatsApp, calls and spreadsheets.

**Everything here is fictional.** Company, people, phones, emails, catalog and prices are made up. Photos are free-licence stock photos (see `backend/assets/demo-images/CREDITS.md`). Nothing connects to any real client system. SMTP, WhatsApp and payments are off; push notifications are off until you add a Firebase project (see below).

| Folder | What it is |
|---|---|
| `backend/` | Node/Express + MongoDB API, demo seed and reset, catalog import, end-to-end flow script |
| `app/` | Flutter customer and wholesaler app (Android) |
| `admin/` | Next.js owner and staff panel |
| `site/` | Next.js public website (placeholder content) |
| `deploy/` | Docker Compose scripts to run one isolated stack per client, plus backup and data export |
| `docs/` | Demo guide, Firebase setup, catalog-import samples, screenshots |

## What the demo shows

- **Catalog and pricing:** brands, categories, products with retail and dealer prices, pack products (packets, coils, bundles priced per piece or metre), stock, Coming Soon products with Notify me, hidden brands and categories.
- **Deal Desk:** a wholesaler sends a requirement (one product or the whole cart), the owner chats, counters, accepts (with a delivery charge) or declines, and one linked order is created.
- **Orders:** customer orders approved by the owner, payment confirmation, processing, shipped, delivered, receipt PDF.
- **Owner control:** dashboard, customers and wholesaler approvals, staff panel with owner-only approval, banners, Excel/CSV catalog import, one-click demo reset.
- **Hindi and English** in the app.

## Run it locally (about 10 minutes)

Needs Node.js 22+, MongoDB (`mongod`), Flutter, and an Android emulator or phone.

```bash
# 1. Backend + database (Mongo runs as a local replica set on port 27018)
cd backend
cp .env.example .env
npm install
npm run demo:mongo        # starts local Mongo
npm run demo:reset        # wipes and seeds the demo data
npm start                 # API on http://localhost:5050

# 2. Admin panel (new terminal)
cd admin && npm install
NEXT_PUBLIC_API_BASE_URL=http://localhost:5050/api/v1 npm run dev     # http://localhost:3000

# 3. Public site (new terminal)
cd site && npm install
NEXT_PUBLIC_API_BASE_URL=http://localhost:5050/api/v1 npm run dev     # http://localhost:3001

# 4. Android app (the emulator reaches your machine at 10.0.2.2)
cd app && flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1
```

For a physical phone, use your computer's LAN address instead of `10.0.2.2`.

## Demo logins (demo-only password `Demo@12345`)

| Role | Where | Login |
|---|---|---|
| Owner (admin) | Admin panel | `admin@demomart.example` |
| Wholesaler, Sunrise Trade House | App, Wholesaler tab | phone `9000000002` |
| Customer, Priya Sharma | App, Customer tab | phone `9000000003` |
| Staff, Demo Operator | Admin panel, "Staff login" | username `demo.operator` |

## Reset for the next prospect

```bash
cd backend && npm run demo:reset
```

Or in the admin panel: Settings → **Reset Demo**, then type `RESET DEMO`. The reset restores accounts, stock, requirements, orders and notifications.

Check the whole flow automatically (it runs twice with a reset between): `npm run demo:e2e` in `backend/`.

## Import a catalog from Excel or CSV

Admin panel → Products → **Import products** (download the template there), or from the command line:

```bash
cd backend && npm run catalog:import -- ../docs/catalog-import-sample.xlsx --dry-run
```

Samples are in `docs/`. Details are in `backend/README.md`.

## Push notifications (optional)

Push is off by default and the app and admin run fine without it. To turn it on, create your own Firebase project and follow `docs/FIREBASE_SETUP.md`. No keys are stored in this repository.

## Per-client deployment

`deploy/` runs one isolated stack per client with Docker Compose (API, admin panel, site and a Caddy proxy). Each client brings its own MongoDB replica set URL (for example Atlas); MongoDB does not run in Docker. `./deploy/new-client.sh <slug> "<Client Name>" <domain>` creates, builds and starts a client; `backup-client.sh`, `export-client.sh` (database dump, uploads and readable CSV/XLSX files) and `stop-client.sh` cover the rest. See `deploy/README.md`. The deployed API runs with `DEMO_MODE=false`, so admins sign in with a one-time link (`deploy/admin-login.sh`) instead of a password.

## Safety

`DEMO_MODE=true` makes the backend refuse to start unless the database is a local one whose name contains `demo`, and unless SMTP and hosted or Atlas connection strings are absent (Firebase is allowed only for your own project id). Reset and seed refuse to run against any other database. The database-backed tests refuse to run against anything not named `...test...`.

See `docs/DEMO_GUIDE.md` for the presentation script, what already works versus what is customized per client, and known limitations.
