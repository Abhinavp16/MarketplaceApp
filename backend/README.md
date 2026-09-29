# TradeHub Demo - Backend API

Node/Express/Mongoose API for the **TradeHub Demo** sales demonstration
(a generic B2B/B2C industrial-supplies distribution platform). Everything in
this project is synthetic: fictional brands, people, phones, emails and
addresses. It only ever talks to a **local** MongoDB and has no third-party
credentials (no Firebase, SMTP, translation API, WhatsApp).

- API base URL: `http://localhost:5050/api/v1`
- Admin panel: `http://localhost:3000`, storefront/site: `http://localhost:3001`
- Database: `tradehub_demo` on a local single-node replica set (`rs0`; the code uses transactions)

## Quick start

```bash
npm install
cp .env.example .env            # demo-only values; edit JWT_SECRET if you like
npm run demo:mongo              # start local mongod (replica set rs0) on 127.0.0.1:27018
npm run demo:reset              # wipe the demo DB and seed the dataset
npm start                       # API on http://localhost:5050
npm run demo:e2e                # optional: full API flow check (server must be running)
```

Stop everything again:

```bash
# Ctrl+C the API, then:
npm run demo:mongo:stop
```

`.data/` (mongo data + private media) and `uploads/` are git-ignored.

### About the Mongo port

`scripts/dev/start-mongo.sh` runs its own `mongod` from
`/opt/homebrew/bin/mongod` (`--replSet rs0 --bind_ip 127.0.0.1 --dbpath ./.data/db`)
on port **27018** by default, so it never collides with (or touches) another
MongoDB you may already run on 27017. Override with `DEMO_MONGO_PORT=27017`
(and adjust `MONGODB_URI`) if 27017 is free. The replica set is initiated
idempotently (via `mongosh` if installed, otherwise a small Node script that
uses the driver bundled with mongoose).

## Environment (`.env.example`)

| Variable | Demo value | Notes |
| --- | --- | --- |
| `DEMO_MODE` | `true` | Enables the demo guard, demo endpoints, offline behaviour |
| `PORT` | `5050` | |
| `MONGODB_URI` | `mongodb://127.0.0.1:27018/tradehub_demo?replicaSet=rs0` | Must be local and the DB name must contain `demo` |
| `JWT_SECRET` | random string | Demo-only |
| `JWT_ACCESS_EXPIRY` / `JWT_REFRESH_EXPIRY` | `2h` / `7d` | |
| `CORS_ORIGIN` | `http://localhost:3000,http://localhost:3001` | Localhost origins are always allowed; no wildcard hosting domains |
| `FILE_STORAGE_DRIVER` | `local` | |
| `PUBLIC_BASE_URL` | `http://localhost:5050` | Base for absolute media URLs |
| `SMTP_*`, `FIREBASE_*`, `GOOGLE_TRANSLATE_API_KEY` | *(blank)* | Must stay blank in demo mode |

### Startup guard (`src/config/demoGuard.js`)

With `DEMO_MODE=true` the server calls `enforceDemoGuard()` before it connects
to any database and exits with code 1 (and a clear message) unless:

- the Mongo URI is a plain `mongodb://` URI on `127.0.0.1`/`localhost` (no `mongodb+srv`, no `*.mongodb.net`),
- the database name contains `demo`,
- no `FIREBASE_*`, `SMTP_*` or `GOOGLE_TRANSLATE_API_KEY` values are set,
- no scanned env value (URI, CORS/panel/base URLs, admin emails, ...) contains a
  known production marker, a hosted domain (`vercel.app`, `onrender.com`, ...) or an `api.*` production hostname.

`assertDemoDatabase()` (same module) is called by the seed/reset scripts, the
reset endpoint and the DB integration tests before anything is written.
Unit tests: `npm run test:demo-guard`.

## Demo accounts

Password for **every** demo login: `Demo@12345` (demo-only, stored in
`scripts/demo/fixtures/users.json`).

| Role | Name | Login | Notes |
| --- | --- | --- | --- |
| Admin (business owner) | Demo Business Owner | `admin@tradehub.example` | password login via `POST /auth/login` |
| Wholesaler | Rohan Mehta - **Sunrise Trade House** | `rohan.mehta@sunrise-trade.example` or phone `9000000002` | verified, complete address, no open negotiation (live-run account) |
| Buyer | Priya Sharma | `priya.sharma@tradehub.example` or phone `9000000003` | |
| Staff | Demo Operator | username `demo.operator` (`POST /auth/staff/login`) | no forced password change |
| Wholesaler | Anita Desai - Metro Hardware Traders | `anita.desai@metro-hardware.example` (phone `9000000005`) | has an open request |
| Wholesaler | Vikram Rao - Bluepeak Construction Supplies | `vikram.rao@bluepeak-supplies.example` (phone `9000000006`) | |
| Buyers | Arjun Nair, Sneha Kapoor | `arjun.nair@` / `sneha.kapoor@tradehub.example` | |
| Pending applicant | Kabir Singh - NewCo Traders | `kabir.singh@newco-traders.example` | wholesaler application awaiting review (private proof images) |

User, product, brand, category ids are **deterministic** (derived from fixture
keys), so they are identical after every reset and existing access tokens stay
valid across a reset. Example: admin `ee02e739775db3bbacf76a80`, Sunrise Trade
House `0344883c57ef9f6af828d5d8`.

### Ready for the live run

- Product: **Cordless Drill 18V** (`KW-DRL-18V`, id `9590822567225650042dfd47`) - retail 6499, wholesale 5200, MRP 7499, min wholesale qty 5, stock 1200, negotiation enabled.
- Wholesaler: **Sunrise Trade House** (Rohan Mehta) has **no open negotiation** and one past delivered order, so its address is known and the admin can accept without typing an address.
- Suggested run: Sunrise requests 20 x Cordless Drill at 4900 with a message -> admin counters 5050 -> admin accepts -> one order is created -> mark payment complete -> set order to processing (stock 1200 -> 1180).

## Login (admin/wholesaler/buyer)

`POST /api/v1/auth/login`

```json
{ "email": "admin@tradehub.example", "password": "Demo@12345" }
```

Response `200`:

```json
{ "success": true,
  "data": { "user": { "_id": "...", "name": "Demo Business Owner", "email": "...", "role": "admin", ... },
            "accessToken": "<jwt>", "refreshToken": "<jwt>" } }
```

Send `Authorization: Bearer <accessToken>`. Refresh with `POST /auth/refresh-token {"refreshToken": ...}`.
Phone login: `POST /auth/login-phone {"phone","password","expectedRole"?}`.
Staff: `POST /auth/staff/login {"username":"demo.operator","password":"Demo@12345"}`
(session lasts 6 hours). Magic-link admin login needs SMTP and is unavailable in the demo.
Email validation accepts any TLD (the demo uses `*.example`).

## Demo endpoints (only when `DEMO_MODE=true`, otherwise 404)

- `GET /api/v1/demo/info` (public) ->
  `{ "success": true, "demoMode": true, "brand": "TradeHub Demo", "version": "<dataset version>", "seededAt": "<ISO>", "apiVersion": "1.0.0", "business": { name, legalName, tagline, email, phone, address, website } }`
  (use it to show a "Demonstration Environment" banner).
- `POST /api/v1/admin/demo/reset` (admin token) with body `{"confirm":"RESET DEMO"}` ->
  `{ "success": true, "message": "...", "data": { "brands": 3, "categories": 14, "products": 20, "users": 9, "orders": 7, "negotiations": 5, ..., "seededAt": "<ISO>", "version": "..." } }`.
  Wrong/missing confirmation -> `400`, non-admin -> `403`, no token -> `401`. Takes ~3 s (password hashing).

## Seed data

`npm run demo:seed` seeds an empty demo DB (refuses if data exists);
`npm run demo:reset` wipes **all** collections then seeds (same function as the reset endpoint).
Fixtures: `scripts/demo/fixtures/*.json` (versioned by `manifest.json`); timestamps
are relative to seed time.

- 3 fictional brands (Kestrel Works, Anvilpoint, Brightguard Safety), 4 parent categories
  (Power Tools, Hand Tools, Fasteners & Fittings, Safety Gear), 10 subcategories, 20 products
  (SKU, MRP, retail, wholesale, min wholesale qty, packing, stock 700-5200, negotiation enabled, Hindi names).
- 9 users (table above), 5 negotiations (pending, countered, converted, rejected, expired - each with
  history, `expiresAt` set explicitly relative to seed time), 7 orders (retail acceptance states
  pending/accepted/rejected, wholesale + negotiated, statuses payment_uploaded/processing/shipped/delivered),
  5 payments, stock ledger, user + admin notifications, ~965 analytics events, lead-interest rows,
  reviews, one offer (`DEMO10`), hero/promo banners, Settings with `demo.seededAt`.

### Images

Placeholder PNGs are generated with Pillow (`python3 scripts/demo/generate-images.py`) and committed
under `assets/demo-images/` (products, categories, brand logos, `logo.png`, banners, a sample payment proof).
In demo mode the API serves that folder at `/uploads/demo/*`, and the data stores URLs in the normal
local-storage scheme: `http://localhost:5050/uploads/demo/products/kw-drl-18v.png`
(`images[].publicId` = `demo/products/kw-drl-18v.png`). List endpoints rewrite loopback hosts to the
request host, so other devices/emulators that reach the API by IP get working URLs.
New uploads go to `./uploads` (also served at `/uploads/*`). **Private media** (wholesaler business proofs)
is stored outside the public tree (`.data/private-media`) and exposed only through HMAC-signed, expiring
URLs (`/api/v1/media/private?key=...&expires=...&sig=...`) that the admin customer endpoints generate.

## Demo-specific behaviour and fixes

- **Socket.IO** (`src/services/negotiationSocketService.js`): every connection must present a valid access
  token (`io(url, { auth: { token } })`); user id/role come from the token, never from client fields.
  `join-negotiation` is authorized against the database (owner wholesaler, admin, staff); `join-admin` is admin-only;
  events from sockets that have not joined a room are ignored. Payloads only need `{ negotiationId }`.
- **Staff restrictions in demo mode**: `PUT /staff/negotiations/:id/accept` always returns `403`
  `"Approval is reserved for the business owner in this demo"`; `PUT /staff/negotiations/:id/counter` returns the
  same `403` for accepted/converted negotiations.
- Negotiation create accepts `message` (max 500 chars), stored on the negotiation and its first history entry.
- Refresh/access JWTs carry a unique `jti` (fixes duplicate-token errors on same-second logins).
- Offline: Hindi-name auto-generation and its scheduler (Google services) are disabled; Hindi names are seeded.
- Error responses do not include stack traces in demo mode.

## Scripts

| Script | Purpose |
| --- | --- |
| `npm start` / `npm run dev` | run the API |
| `npm run demo:mongo` / `demo:mongo:stop` | start/stop local demo mongod (rs0) |
| `npm run demo:seed` / `demo:reset` | seed / wipe+seed |
| `npm run demo:e2e` | full API flow (refuses unless `/demo/info` says demoMode); `BASE_URL` overrides the target |
| `npm test` | all tests (DB tests use the local demo DB); `npm run test:unit` skips DB tests |
| `npm run test:demo-guard` | guard unit tests (no DB) |

`demo:e2e` covers: demo info + health, logins (admin/wholesaler/buyer/staff), catalogue + image, wholesaler
negotiation with message, admin counter, staff accept blocked (403), admin accept -> exactly one order,
idempotent re-accept, wholesaler fetches the order, mark payment complete -> processing -> stock drops, reset back
to baseline, then the whole flow a second time.

## Known limitations

- Push notifications (FCM) and emails are not sent (no credentials by design); in-app notification rows are created.
- WhatsApp checkout is disabled: no number is configured, so `whatsappNumber` is `""` and `whatsappUrl` is `null`
  (the checkout `mode` value is still the code constant `"whatsapp"`).
- Admin magic-link login is unavailable (needs SMTP); use email + password.
- Payment "proof" screenshots and bank/UPI details are fictional placeholders.
- Analytics events use a 90-day TTL and lead rows a 5-day TTL; re-seed to refresh dates.
- A few pre-existing Mongoose "duplicate schema index" warnings are printed at startup (harmless).
