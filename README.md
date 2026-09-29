# TradeHub Demo — Distribution Ordering Platform (synthetic data only)

A self-contained demo that shows how a distributor or manufacturer can run dealer negotiations and orders in one system instead of WhatsApp, calls and spreadsheets.

**Everything here is fictional.** Company, people, phones, emails, catalog and prices are made up. Photos are free-licence stock photos (see `backend/assets/demo-images/CREDITS.md`). Nothing connects to any real client system. Firebase, SMTP, WhatsApp, payments and push are switched off.

| Folder | What it is |
|---|---|
| `backend/` | Node/Express + MongoDB API, demo seed, reset, end-to-end flow script |
| `app/` | Flutter customer/wholesaler app (Android) |
| `admin/` | Next.js owner and staff panel |
| `site/` | Next.js public website (placeholder content) |
| `docs/` | Presentation guide and screenshots |

## Run it locally (about 10 minutes)

Needs Node.js, MongoDB (`mongod`), Flutter, and an Android emulator or phone.

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

# 4. Android app (emulator uses 10.0.2.2 to reach your machine)
cd app && flutter pub get
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1
```

For a physical phone, use your computer's LAN address instead of `10.0.2.2`.

## Demo logins (demo-only password `Demo@12345`)

| Role | Where | Login |
|---|---|---|
| Owner (admin) | Admin panel | `admin@tradehub.example` |
| Wholesaler, Sunrise Trade House | App, Wholesaler tab | phone `9000000002` |
| Customer, Priya Sharma | App, Customer tab | phone `9000000003` |
| Staff, Demo Operator | Admin panel, "Staff login" | username `demo.operator` |

## Reset for the next prospect

```bash
cd backend && npm run demo:reset
```

Or, in the admin panel: Settings → **Reset Demo**, then type `RESET DEMO`. The reset restores all accounts, stock, negotiations and orders, and sets fresh negotiation expiry dates.

To verify the whole flow automatically (runs it twice with a reset between): `npm run demo:e2e` in `backend/`.

## Safety

`DEMO_MODE=true` makes the backend refuse to start unless the database is a local one whose name contains `demo`, and unless Firebase, SMTP and hosted or Atlas connection strings are all absent. Reset and seed refuse to run against any other database.

See `docs/DEMO_GUIDE.md` for the walkthrough, what already works vs what we customize per client, and known limitations.
