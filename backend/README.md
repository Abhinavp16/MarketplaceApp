# DemoMart Distribution - Backend API

Node/Express/Mongoose API for the **DemoMart** sales demonstration
(a generic B2B/B2C industrial-supplies distribution platform). Everything in
this project is synthetic: fictional brands, people, phones, emails and
addresses. It only ever talks to a **local** MongoDB and has no third-party
credentials (no Firebase, SMTP, translation API, WhatsApp).

- API base URL: `http://localhost:5050/api/v1`
- Admin panel: `http://localhost:3000`, storefront/site: `http://localhost:3001`
- Database: `demomart_demo` on a local single-node replica set (`rs0`; the code uses transactions)
- Based on a production B2B distribution API (hardened: JWT token types, rate limits, CORS allow-list, input safety), made generic and offline for demos

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
| `MONGODB_URI` | `mongodb://127.0.0.1:27018/demomart_demo?replicaSet=rs0` | Must be local and the DB name must contain `demo` |
| `JWT_SECRET` | random string, **32+ characters** | Demo-only; `assertJwtConfig()` rejects short secrets in production |
| `JWT_REFRESH_SECRET` | *(blank)* | Optional separate secret for refresh tokens (32+ chars when set) |
| `EXPOSE_ERROR_STACK` | `false` | Stack traces in error responses; **ignored (always off) in demo mode** |
| `RATE_LIMIT_WINDOW_MS` / `RATE_LIMIT_MAX_REQUESTS` | `60000` / `1000` | General API limit per user/IP; sign-in/register/refresh limits are switched off in demo mode |
| `TRUST_PROXY_HOPS` | `1` | Reverse proxies in front of the API |
| `JWT_ACCESS_EXPIRY` / `JWT_REFRESH_EXPIRY` | `2h` / `7d` | |
| `CORS_ORIGIN` / `ADMIN_PANEL_URL` / `FRONTEND_URL` | `http://localhost:3000,http://localhost:3001` | The only browser origins allowed (exact match, no built-in sites, no wildcards); localhost is also allowed outside production |
| `FILE_STORAGE_DRIVER` | `local` | |
| `PUBLIC_BASE_URL` | `http://localhost:5050` | Base for absolute media URLs |
| `SMTP_*`, `GOOGLE_TRANSLATE_API_KEY` | *(blank)* | Must stay blank in demo mode |
| `FIREBASE_*`, `DEMO_FIREBASE_PROJECT_ID` | *(blank)* | Optional push; see "Firebase push (optional)" |

### Startup guard (`src/config/demoGuard.js`)

With `DEMO_MODE=true` the server calls `enforceDemoGuard()` before it connects
to any database and exits with code 1 (and a clear message) unless:

- the Mongo URI is a plain `mongodb://` URI on `127.0.0.1`/`localhost` (no `mongodb+srv`, no `*.mongodb.net`),
- the database name contains `demo`,
- no `SMTP_*` or `GOOGLE_TRANSLATE_API_KEY` values are set, and any `FIREBASE_*` value comes with
  `FIREBASE_PROJECT_ID` equal to `DEMO_FIREBASE_PROJECT_ID` (see "Firebase push (optional)"),
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
| Admin (business owner) | Demo Business Owner | `admin@demomart.example` | password login via `POST /auth/login` |
| Wholesaler | Rohan Mehta - **Sunrise Trade House** | `rohan.mehta@sunrise-trade.example` or phone `9000000002` | verified, complete address, no open negotiation (live-run account) |
| Buyer | Priya Sharma | `priya.sharma@demomart.example` or phone `9000000003` | |
| Staff | Demo Operator | username `demo.operator` (`POST /auth/staff/login`) | no forced password change |
| Wholesaler | Anita Desai - Metro Hardware Traders | `anita.desai@metro-hardware.example` (phone `9000000005`) | has an open request |
| Wholesaler | Vikram Rao - Bluepeak Construction Supplies | `vikram.rao@bluepeak-supplies.example` (phone `9000000006`) | |
| Buyers | Arjun Nair, Sneha Kapoor | `arjun.nair@` / `sneha.kapoor@demomart.example` | Arjun has an open account-deletion request; **Sneha has Brightguard Safety hidden** (per-customer hidden brand) |
| Pending applicant | Kabir Singh - NewCo Traders | `kabir.singh@newco-traders.example` | wholesaler application awaiting review (private proof images) |

User, product, brand, category ids are **deterministic** (derived from fixture
keys), so they are identical after every reset and existing access tokens stay
valid across a reset. Example: admin `e571894737a3bc8b6bfbd355`, Sunrise Trade
House `7494c63ccea2e6b34c7f0d37`.

### Ready for the live run

- Product: **18V Brushless Cordless Drill Driver, 13 mm Chuck (2 x 2.0 Ah)** (`KW-DRL-18V`, id `4c9b6c13b563939db112bc9e`) - retail 6499, wholesale 5200, MRP 7499, min wholesale qty 5, stock 1200, negotiation enabled.
- Wholesaler: **Sunrise Trade House** (Rohan Mehta) has **no open negotiation** and one past delivered order, so its address is known and the admin can accept without typing an address.
- Suggested run: Sunrise requests 20 x the 18V cordless drill driver at 4900 with a message -> admin counters 5050 -> admin accepts -> one order is created -> mark payment complete -> set order to processing (stock 1200 -> 1180).

## Login (admin/wholesaler/buyer)

`POST /api/v1/auth/login`

```json
{ "email": "admin@demomart.example", "password": "Demo@12345" }
```

Response `200`:

```json
{ "success": true,
  "data": { "user": { "_id": "...", "name": "Demo Business Owner", "email": "...", "role": "admin", ... },
            "accessToken": "<jwt>", "refreshToken": "<jwt>" } }
```

Send `Authorization: Bearer <accessToken>`. Refresh with `POST /auth/refresh-token {"refreshToken": ...}`
(only a refresh token is accepted there; a refresh token never works as an access token).
Phone login: `POST /auth/login-phone {"phone","password","expectedRole"?}` (customers and wholesalers only).
Staff: `POST /auth/staff/login {"username":"demo.operator","password":"Demo@12345"}` (session lasts 6 hours).

**Admin password login is a demo-only exception.** The production API refuses admin passwords (admins sign in with
an emailed magic link); in demo mode (`DEMO_MODE=true`) `POST /auth/login` accepts the demo admin's password because
the demo has no SMTP. Phone login stays closed to admins. Sign-in rate limits are off in demo mode.
Email validation accepts any TLD (the demo uses `*.example`).

## Demo endpoints (only when `DEMO_MODE=true`, otherwise 404)

- `GET /api/v1/demo/info` (public) ->
  `{ "success": true, "demoMode": true, "brand": "DemoMart Distribution", "version": "<dataset version>", "seededAt": "<ISO>", "apiVersion": "1.0.0", "business": { name, legalName, tagline, email, phone, address, website } }`
  (use it to show a "Demonstration Environment" banner).
- `POST /api/v1/admin/demo/reset` (admin token) with body `{"confirm":"RESET DEMO"}` ->
  `{ "success": true, "message": "...", "data": { "brands": 3, "categories": 17, "products": 29, "users": 9, "orders": 9, "negotiations": 12, ..., "seededAt": "<ISO>", "version": "..." } }`.
  Wrong/missing confirmation -> `400`, non-admin -> `403`, no token -> `401`. Takes ~3 s (password hashing).
- Health: `GET /health` and `GET /api/v1/health` return only `{ success, status, timestamp }` (the production API hides
  hosts and versions); `GET /api/v1/health/details` is admin-only. Do not rely on the old, richer payload.

## Features beyond the basics (all in the seeded data)

| Feature | Where to look | Key API |
| --- | --- | --- |
| **Pack products** priced per piece / per metre (Packet, Coil, Bundle) | Zinc washer packet (`100 pcs`), nylon hose coil (`50 m`), utility rope bundle (`100 m`); `ORD-DEMO-1009` | product fields `priceUnit`, `packing`, `packSize`, `minCustomerQuantity`; quantities are pieces/metres, wholesalers buy whole packs |
| **Cart -> Deal Desk requirement group** (wholesalers) | `REQ-2026-DEMO01` (pending), `REQ-2026-DEMO02` (converted to `ORD-DEMO-1008`), `REQ-2026-DEMO03` (declined) | `POST /negotiations/from-cart`; `GET /admin/negotiations/groups/:groupId`; `PUT /admin/negotiations/groups/:groupId/accept {negotiationIds[], deliveryCharge}` -> one order |
| **Delivery charge set by admin** | pending customer orders have `deliveryFee: 0`; accepted ones carry the admin's fee | `PUT /admin/orders/:id/accept {deliveryCharge}`; group accept and `PUT /admin/negotiations/:id/accept {deliveryCharge}` |
| **Decline + 5-day purge** | `NGT-DEMO-1004` and the declined group have `rejectedAt` | `PUT /admin/negotiations/:id/reject {reason}` and `.../groups/:groupId/reject`; a scheduler purges declined ones after 5 days |
| **Coming Soon + Notify me** | 4 products (price shown + date; price hidden; auto-launch in 3 days; no date); 7 subscriptions (Priya, Sunrise, Metro) | product payload `comingSoon`, `expectedDate`, `priceHidden` (price fields are `null`); `POST/DELETE /products/:id/notify-me`; cart/order/requirement return `PRODUCT_COMING_SOON`; admin `PUT /admin/products/:id {comingSoon:{enabled:false}}` launches and notifies subscribers once (`launchNotified`) |
| **Hidden brands / categories** | top-level category *Contractor Bulk Range* is hidden from retail customers and guests (wholesalers + admin see it); customer Sneha has the Brightguard brand hidden | `hideFromCustomers` on brands/categories; `PUT /admin/customers/:id/brand-access {hiddenBrands[]}` |
| **Price-change notification batches** | one `sent` batch is seeded (never a pending one) | `POST /admin/price-updates/flush` |
| **Receipt PDF** | any order | `GET /admin/orders/:id/receipt`, `GET /staff/orders/:id/receipt`, `GET /orders/:id/export?format=pdf|xlsx` (customer's own); header uses the business name, watermark is a generic "DM" monogram |
| **Account-deletion reminders** | Arjun's open request is due in 5 days; matching admin notification | admin notification types `account_deletion_due_soon` / `account_deletion_overdue` |
| Leads, notifications | existing | `product_launched`, `negotiation_rejected` (single and group) notification types |

## Seed data

`npm run demo:seed` seeds an empty demo DB (refuses if data exists);
`npm run demo:reset` wipes **all** collections (including the new `ProductAlert`, `PriceChangeNotificationBatch`
and `AccountDeletionRequest` ones), re-creates indexes, then seeds (same function as the reset endpoint).
Fixtures: `scripts/demo/fixtures/*.json` (versioned by `manifest.json`, currently `2026.2`); timestamps
are relative to seed time.

- 3 fictional brands (Kestrel Works, Anvilpoint, Brightguard Safety), 5 parent categories
  (Power Tools, Hand Tools, Fasteners & Fittings, Safety Gear, Contractor Bulk Range - hidden from customers), 12 subcategories,
  **29 products** (20 base + 3 pack products + 2 hidden bulk products + 4 Coming Soon; SKU, MRP, retail, wholesale, min
  wholesale qty, packing, stock, negotiation enabled, Hindi names).
- 9 users (table above), 12 negotiations (pending, countered, converted, rejected, expired, three requirement groups, a pack request),
  9 orders (retail pending with `deliveryFee: 0`, accepted with admin-set fees, rejected, wholesale incl. a two-product group order
  and a pack order), 5 payments, stock ledger, user + admin notifications (incl. `product_launched`, group decline),
  7 Notify-me subscriptions, one sent price-change batch, one open deletion request, ~1,200 analytics events, lead-interest rows,
  reviews, one offer (`DEMO10`), hero/promo banners, Settings with `demo.seededAt`.

### Images

Product, category and banner images are **real photographs that are free for commercial use with no
attribution obligation** (CC0 / public domain from Wikimedia Commons, Pexels License from Pexels), processed with Pillow (square 800 px crops for products/categories, 1600x900
banners with no baked-in text, JPEG q82) and committed under `assets/demo-images/`. Every photo is
listed with source page, author, licence and retrieval date in `assets/demo-images/CREDITS.md`.
The brand logos (fictional brands), `logo.png` and the sample payment proof are synthetic and are
generated by `python3 scripts/demo/generate-images.py`. In demo mode the API serves that folder at
`/uploads/demo/*`, and the data stores URLs in the normal local-storage scheme:
`http://localhost:5050/uploads/demo/products/kw-drl-18v.jpg`
(`images[].publicId` = `demo/products/kw-drl-18v.jpg`). List endpoints rewrite loopback hosts to the
request host, so other devices/emulators that reach the API by IP get working URLs.
New uploads go to `./uploads` (also served at `/uploads/*`). **Private media** (wholesaler business proofs)
is stored outside the public tree (`.data/private-media`) and exposed only through HMAC-signed, expiring
URLs (`/api/v1/media/private?key=...&expires=...&sig=...`) that the admin customer endpoints generate.

## Catalog import (Excel / CSV)

Bulk-create and bulk-update products from a spreadsheet. One row = one product, matched on **SKU**: a new SKU creates a
product, an existing SKU updates it (only the columns that have a value in the file). The whole file is **all or nothing**:
if any row has an error, nothing is written. Products are written through the same functions as the admin product form
(`createProductRecord` / `updateProductRecord` in `src/controllers/admin/productController.js`), so slugs, price history,
Hindi names and the price-update notices behave exactly the same. Code: `src/services/catalogImportService.js`
(parse, validate, import), `src/utils/catalogImportWorkbook.js` (template/sample workbook),
`src/controllers/admin/catalogImportController.js` (HTTP), `scripts/catalog-import.js` (CLI).

### Endpoints (admin token required)

| Method and path | Purpose |
| --- | --- |
| `POST /api/v1/admin/products/import` | multipart field `file` (`.xlsx` or `.csv`, max 5 MB, max 5000 product rows). Query: `dryRun=true\|false` (**default `true`**: nothing is saved unless you pass `dryRun=false`), `createMissing=true\|false` (default `false`), `priceChangeMode=immediate\|schedule_24h` (default `immediate`) |
| `GET /api/v1/admin/products/import/template` | ready-to-fill `.xlsx` (Products sheet with headers + 3 example rows incl. a Packet and a Coil product, Notes sheet explaining columns, allowed values and rules); `Content-Disposition: attachment; filename="catalog-import-template.xlsx"` |

Suggested flow: upload with `dryRun=true`, show the report, let the admin fix the file, then upload again with `dryRun=false`.

```bash
TOKEN=$(curl -s -X POST localhost:5050/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"admin@demomart.example","password":"Demo@12345"}' | node -pe 'JSON.parse(require("fs").readFileSync(0)).data.accessToken')
curl -s -X POST 'localhost:5050/api/v1/admin/products/import?dryRun=true'  -H "Authorization: Bearer $TOKEN" -F file=@../docs/catalog-import-sample.xlsx
curl -s -X POST 'localhost:5050/api/v1/admin/products/import?dryRun=false' -H "Authorization: Bearer $TOKEN" -F file=@../docs/catalog-import-sample.xlsx
curl -s -o template.xlsx localhost:5050/api/v1/admin/products/import/template -H "Authorization: Bearer $TOKEN"
```

Response `200` (a file with row errors is still `200` with `committed:false`; the report is the result):

```json
{ "success": true,
  "data": {
    "dryRun": true,                 // false when ?dryRun=false
    "committed": false,             // true only when dryRun=false AND no row has an error AND the write succeeded
    "createMissing": false,
    "priceChangeMode": "immediate",
    "fileName": "catalog-import-sample.xlsx",
    "summary": { "totalRows": 12, "created": 11, "updated": 1, "skipped": 0,
                 "errors": 0, "warnings": 0,      // number of ROWS with errors / warnings
                 "errorCount": 0, "warningCount": 0,   // number of messages
                 "newBrands": 0, "newCategories": 0 },
    "newBrands": [],                 // brands created / that would be created (createMissing)
    "newCategories": [],             // "Brand: Parent > Child"
    "columns": [ { "header": "SKU Code", "field": "sku", "label": "SKU" }, ... ],   // how each header was understood
    "ignoredColumns": [ "Internal Notes" ],
    "rows": [
      { "row": 2,                    // spreadsheet row number (header = row 1)
        "sku": "KW-DRL-12V",
        "action": "create",          // create | update | skip (skip = nothing to change)
        "status": "ok",              // ok | warning | error
        "errors":   [ { "field": "retailPrice", "column": "Retail Price", "message": "Retail Price \"abc\" is not a number." } ],
        "warnings": [ { "field": "...", "column": "...", "message": "..." } ],
        "changes":  [ { "field": "stock", "column": "Stock", "from": 1200, "to": 1000 } ],   // updates only
        "normalized": { "sku": "KW-DRL-12V", "name": "...", "brand": "Kestrel Works", "category": "Power Tools > Drills & Drivers", "retailPrice": 4299, "status": "draft", ... },
        "note": "No changes: the product already matches this row.",     // skip rows only
        "productId": "..."           // after a committed import
      } ] } }
```

`summary.created/updated/skipped` count rows **without errors** (what the import does, or would do in a dry run), so a refused
import (`committed:false` with errors) shows what the valid rows would have done, but nothing was written. Row `action`
is the intended action even for a row that has errors.
Errors: no file / wrong type (`.xls`, `.pdf`, an `.xlsx` renamed to `.csv`...) `400` `FILE_REQUIRED` / `INVALID_FILE_TYPE`,
over 5 MB `400` `FILE_TOO_LARGE`, over 5000 rows `400` `TOO_MANY_ROWS`, no header row with a SKU column `400` `MISSING_COLUMNS`,
two headers that mean the same column `400` `DUPLICATE_COLUMN`, bad query value `400` `VALIDATION_ERROR`, non-admin `403`, no token `401`.

### Columns

Header matching ignores case, spaces, underscores, punctuation and anything in brackets, and understands common
alternatives (`SKU Code`, `Product Name`, `Retail Price (Rs.)`, `Selling Price`, `Dealer Price`, `MOQ`, `UOM`, `Sub Category` ...).
The first row of the `Products` sheet (or of the CSV) is the header; the first sheet is used when there is no sheet called
`Products`. Comma, semicolon or tab separated CSV, with or without a BOM, is fine. Unknown columns are listed in `ignoredColumns`
and otherwise ignored. Blank rows are skipped.

| Column | New product | Meaning / rule |
| --- | --- | --- |
| `SKU` | required | Letters, digits and `- _ . /`, no spaces, up to 64 chars; stored in capitals; unique inside the file |
| `Name` | required | Up to 200 characters; must not collide with another product's name (the web address slug is built from it) |
| `Hindi Name` | optional | Left empty it is generated where the app can (offline in demo mode) |
| `Brand` | required | Existing brand (case/space-insensitive) |
| `Category` | required | Existing category, or a path `Parent > Child` (also deeper); a single name works when it is unique under the brand |
| `Subcategory` | optional | Alternative to the path: parent in `Category`, child here |
| `Description` / `Short Description` | optional | Short up to 300 chars. A new product without a description gets a warning |
| `MRP`, `Retail Price`, `Wholesale Price` | required | Numbers `>= 0`; `1,250`, `1,00,000.50`, `Rs. 99`, `1250/-` are accepted; more than 2 decimals is rounded (warning). Retail above MRP, or wholesale above retail, is a **warning** (the admin form does not enforce an order either) |
| `Min Wholesale Qty` | optional | Whole number `>= 1` (in packs for pack products). Default 10 (model default) |
| `Min Customer Qty` | optional | Whole number `>= 1` (pieces / metres). Default 1 |
| `Unit` | optional | What the price is per (`piece`, `box`, `set`, `pair`...). New products default to `piece` |
| `Packing` | optional | Free text (`Box of 100`) or `15 pcs` / `500 m` for pack products |
| `Pack Type` | optional | `Packet`, `Coil` or `Bundle` (sets `Unit` when empty) |
| `Pack Size` | with Pack Type | Whole number `>= 2`: pieces per packet, metres per coil/bundle. Sets `Packing` to `N pcs` / `N m` when empty |
| `Stock` | optional | Whole number `>= 0` (pieces or metres for pack products). Default 0. Written to the stock history |
| `Low Stock Alert` | optional | Whole number `>= 0` |
| `Status` | optional | `active`, `draft`, `archived`. **New products default to `draft`** |
| `Negotiation`, `Featured`, `Hot` | optional | `Yes`/`No` (also `true/false`, `1/0`, `Y/N`) |
| `Tags` | optional | Comma, semicolon or pipe separated, up to 20 |

### Rules

- **SKU** is the key. Duplicate SKUs inside one file are an error on every row involved (case-insensitive).
- **Update** only touches columns that have a value; a blank cell keeps the stored value (so you cannot clear a field with an import). A row whose values already match is reported as `skip` ("No changes"), which makes re-importing the same file harmless (`created: 0, updated: 0`). Moving a product to another brand needs both `Brand` and `Category`.
- **Brand / category** must exist (name match, case-insensitive) unless `createMissing=true`: then the brand (a `Company`, next display order) and the category path (with `parent` links, as the admin controller does) are created inside the same transaction. A brand/category whose web-address slug collides with an existing one is an error.
- **Pack products** follow `src/utils/packSize.js`: `Packet` = price per piece, one packet = N pieces; `Coil`/`Bundle` = price per metre, one pack = N metres. `Pack Type` without a valid size, a size `< 2`, a `Pack Size` without a type, a unit/type conflict or a `Packing` that disagrees with `Pack Size` are errors. A unit such as `pack`/`Packet` with free text packing (`Pack of 50`) stays a normal product priced per pack (warning explains it).
- **Prices on existing products** are changed through the same price-change function as the admin form (price history row, pending/scheduled fields, "prices changed" notice batch). `priceChangeMode=immediate` (default) applies them now; `schedule_24h` schedules them 24 hours ahead like the admin form's default.
- **Stock** changes on updates (and non-zero stock on new products) write a `StockLog` row (`manual_set`, reason `Catalog import (<file>)`).
- **Transaction**: validation and writes run in one MongoDB transaction (replica set required); any failure rolls back brands, categories, products, price history and stock rows. Category product counts, Hindi-name fill and price notices run after the commit.
- **Audit**: a committed import by an admin writes an `AuditLog` row (`catalog.import`).
- **Images** are not part of the workbook. Products without images show the app's normal placeholder (the storefront/app already render products with an empty `images` array); add pictures afterwards in the admin panel. An `Image URL` column is deliberately not supported: image records need a storage key and are processed (WebP + blur hash) on upload.
- **Why `draft` by default**: `POST /admin/products` validation also defaults to `draft`, a product imported without pictures should not go live by accident, and publishing is one explicit `Status = active` away. The sample files set `active`.
- Limits: 5 MB, 5000 product rows, `.xlsx` or `.csv` only. DEMO_MODE adds nothing special beyond the startup guard.

### CLI

```bash
npm run catalog:import -- ../docs/catalog-import-sample.xlsx --dry-run
npm run catalog:import -- ../docs/catalog-import-sample.xlsx
npm run catalog:import -- my-products.csv --create-missing --price-change-mode schedule_24h --actor admin@demomart.example
npm run catalog:import -- ../docs/catalog-import-errors.csv --dry-run --json
```

Flags: `--dry-run` (check only), `--create-missing`, `--price-change-mode immediate|schedule_24h`, `--actor <admin email>` (recorded in price history and the audit log), `--json`.
It loads `.env`, connects with `src/config/database`, prints a per-row report and exits `0` (ok), `1` (the file has errors, nothing written) or `2` (could not run).
In `DEMO_MODE` it calls `assertDemoDatabase()` before and after connecting and refuses unless the database is a local demo one.

### Sample files (`../docs`)

| File | Content |
| --- | --- |
| `catalog-import-sample.xlsx` / `.csv` | 12 DemoMart rows on the seeded brands: 11 new products (incl. a Packet and a Coil pack product, one `draft`) and one update of the seeded `AP-TPE-5M` (price and stock). Imports cleanly into a freshly reset demo database (`npm run demo:reset`). |
| `catalog-import-errors.csv` | 14 rows with deliberate mistakes (missing/duplicate/invalid SKU, unknown brand and category, non-numeric and negative prices, price-order warnings, fractional stock, bad status, bad pack type/size, name clash with `KW-DRL-18V`, missing name, bad Yes/No, an ignored column) to show the validation report. |

Regenerate them (and the template look) with `npm run catalog:samples`. `npm run demo:reset` restores the seed after trying an import.

## Demo-specific behaviour (differences from the production API)

- **Admin password login** allowed only when `DEMO_MODE` (see Login). Production keeps magic-link-only admin sign-in.
- **Sign-in / register / refresh rate limits** are skipped in demo mode (repeated e2e runs must not lock out).
- **Error responses** never include stack traces or raw error text in demo mode, even with `EXPOSE_ERROR_STACK=true`.
- **CORS** has no built-in sites: only `CORS_ORIGIN`, `ADMIN_PANEL_URL`, `FRONTEND_URL` (+ localhost outside production).
- **Schedulers**: Hindi-name sweep and the banner-media sweep (deletes files) do not run. The declined-requirement purge,
  product launch sweep, account-deletion reminders and price-update notifier only touch the database and do run.
- **Socket.IO** (`src/services/negotiationSocketService.js`, same as production): the token is checked on every event
  (`io(url, { auth: { token } })` at handshake **and** `token` in `join-negotiation` / `join-admin` payloads);
  user id/role come from the token and the database, never from client fields. `join-negotiation` is authorised against
  the database (the deal's wholesaler, admin, staff); `join-admin` is admin-only. Verified by `tests/negotiationSocketReal.test.js`
  with a real `socket.io-client`.
- **Staff restrictions**: `PUT /staff/negotiations/:id/accept` always returns `403`
  `"Approval is reserved for the business owner in this demo"`; `PUT /staff/negotiations/:id/counter` returns the
  same `403` for accepted/converted negotiations; `PUT /staff/negotiations/:id/reject` and
  `PUT /staff/negotiations/groups/:groupId/reject` return the same `403` (code `DEMO_APPROVAL_RESERVED`).
- Hindi names are seeded; auto-generation (Google services) is disabled. WhatsApp checkout, FCM push and email are off.
- Private media (business proofs) uses the local driver with HMAC-signed URLs (`/api/v1/media/private`).

## Scripts

| Script | Purpose |
| --- | --- |
| `npm start` / `npm run dev` | run the API |
| `npm run demo:mongo` / `demo:mongo:stop` | start/stop local demo mongod (rs0, port 27018) |
| `npm run demo:seed` / `demo:reset` | seed / wipe+seed |
| `npm run catalog:import -- <file> [--dry-run] [--create-missing]` | import products from `.xlsx`/`.csv` (see Catalog import) |
| `npm run catalog:samples` | regenerate `docs/catalog-import-sample.*` and `docs/catalog-import-errors.csv` |
| `npm run test:catalog-import` | parsing/validation unit tests; the write-path tests run when `TEST_MONGODB_URI` (or `CATALOG_IMPORT_TEST_MONGODB_URI`) points at a local replica-set `test` database |
| `npm run demo:e2e` | full API flow (refuses unless `/demo/info` says demoMode); `BASE_URL` overrides the target |
| `npm test` | runs every `tests/*.test.js`; DB-backed parts need `TEST_MONGODB_URI` (see below), otherwise they are skipped and say so |
| `npm run test:unit` | pure unit tests only (`SKIP_DB_TESTS=1`) |
| `npm run test:demo-guard` | guard unit tests (no DB) |
| `python3 scripts/demo/generate-images.py` / `generate-watermark.py` | regenerate synthetic logos/proofs and the receipt watermark |

### Running the tests

The database-backed tests create and delete data (two of them drop the whole database), so they only run against
a MongoDB on this machine whose database name contains `test` or `demo` (`tests/helpers/testDb.js`; anything else is
refused before a single write). Use a throwaway mongod, not the demo DB:

```bash
mkdir -p /tmp/demomart-test-db
mongod --replSet rs0 --dbpath /tmp/demomart-test-db --bind_ip 127.0.0.1 --port 27019 --fork --logpath /tmp/demomart-test.log
DEMO_MONGO_PORT=27019 node scripts/dev/init-replset.js
TEST_MONGODB_URI='mongodb://127.0.0.1:27019/demomart_test?replicaSet=rs0' npm test
```

(Each test also accepts its own variable, e.g. `INVENTORY_TEST_MONGODB_URI`, which wins over `TEST_MONGODB_URI`.)

`demo:e2e` covers: demo info + health, logins (admin/wholesaler/buyer/staff), catalogue + image, wholesaler
negotiation with message, admin counter, staff accept blocked (403), admin accept -> exactly one order,
idempotent re-accept, wholesaler order + mark payment complete -> processing -> stock drops; buyer cart -> order
(delivery 0) -> admin accepts with a delivery charge (stock commits) -> paid -> shipped -> delivered; wholesaler cart ->
requirement group -> accepted with delivery -> exactly one order; decline (single + group, staff blocked with 403);
Coming Soon (cart/requirement/order refused with `PRODUCT_COMING_SOON`, hidden price `null`, manual launch notifies the three
subscribers exactly once); receipt PDFs; hidden category / hidden brand / wholesale-price visibility; reset back to baseline
(orders, negotiations, stock, notifications, coming-soon count identical), then the whole flow a second time.

## Known limitations

- Emails are not sent (no credentials by design). Push notifications (FCM) are off until you add your own Firebase project ("Firebase push (optional)"); in-app notification rows are always created.
- WhatsApp checkout is disabled: no number is configured, so `whatsappNumber` is `""` and `whatsappUrl` is `null`
  (the checkout `mode` value is still the code constant `"whatsapp"`).
- Admin magic-link login is unavailable (needs SMTP); the demo admin signs in with email + password (demo-only exception).
- Coming Soon on an already-launched product: auto-launch is evaluated on the date even without the scheduler (reads treat it as launched), but the "now available" notification is sent by the 15-minute sweep or the first admin save.
- Payment "proof" screenshots and bank/UPI details are fictional placeholders.
- Analytics events use a 90-day TTL and lead rows a 5-day TTL; re-seed to refresh dates.
- A few pre-existing Mongoose "duplicate schema index" warnings are printed at startup (harmless).

## Firebase push (optional)

Push notifications through Firebase Cloud Messaging are off by default; the in-app
notification centre works without them. To turn them on, create your own Firebase
project (step by step in `../docs/FIREBASE_SETUP.md`) and set these in `.env`:

| Variable | Value |
|----------|-------|
| `DEMO_FIREBASE_PROJECT_ID` | your Firebase project id (the allow-list for demo mode) |
| `FIREBASE_PROJECT_ID` | the same project id |
| `FIREBASE_CLIENT_EMAIL` | `client_email` from the service account JSON |
| `FIREBASE_PRIVATE_KEY` | `private_key` from the service account JSON, on one line with newlines written as `\n` (surrounding quotes are fine) |
| `FIREBASE_STORAGE_BUCKET` | optional |

Demo-mode rules (`src/config/demoGuard.js`): the server refuses to start if any `FIREBASE_*`
value is set and `FIREBASE_PROJECT_ID` is empty, is not equal to `DEMO_FIREBASE_PROJECT_ID`,
`FIREBASE_CLIENT_EMAIL` is not a service account of that project, or any Firebase value contains
one of the guard's production markers. With no Firebase values the server logs
"Firebase credentials not configured" once and skips sending push (`src/config/firebase.js` returns
`null`, `notificationService` then does nothing). Never commit the service account JSON or `.env`.

Devices register with `POST /notifications/register-token` (`{ fcmToken, platform }`, platform
`android` or `web`) and unregister with `POST /notifications/unregister-token`. Every push carries
a `notification` block plus string `data`: `type`, `title`, `body`, `click_action`, `language`, and
for product launches `productId` and `slug` (`type: product_launched`, which the app opens at
`/product/:id`). The Android channel id is `demomart_default`.
