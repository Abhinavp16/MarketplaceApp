# Per-client deployment (Docker Compose)

Runs one **isolated** DemoMart stack per client on a single server: own API, admin panel, public site,
reverse proxy, secrets, uploads volume and host ports. **MongoDB is not part of the stack**: each client
brings its own MongoDB URL (for example an Atlas cluster, which is a replica set, so transactions work).
Every client is a compose project named `demomart-<slug>`; the scripts never touch anything
without that prefix, and never touch your database.

```
deploy/
  new-client.sh        create + build + start a client
  update-client.sh     rebuild and restart, keeping volumes
  stop-client.sh       stop (keep data) or --destroy-data (asks twice)
  list-clients.sh      clients and their state
  backup-client.sh     mongodump + uploads tar  -> backups/<slug>/<timestamp>/
  export-client.sh     hand-over export         -> exports/<slug>-<YYYYmmdd-HHMM>/
  admin-login.sh       one-time admin sign-in link (no SMTP needed)
  docker-compose.yml, Caddyfile, *.Dockerfile
  clients/<slug>/      generated config and secrets (gitignored; only clients/example/ is tracked)
```

## Prerequisites

- Docker with the compose plugin (v2), `openssl`, `curl`, bash 3.2+ (macOS or Linux).
- A MongoDB replica set per client and its URL (see "MongoDB URL").
- About 2 GB free RAM per client while building, then roughly 300 MB per running client.
- Internet access for the first build (base images, npm packages).

## MongoDB URL

How the URL is supplied to `new-client.sh` (stored only in `clients/<slug>/.env`, mode 0600, gitignored;
never printed in full, only as `mongodb://***:***@host/db`):

1. `--mongo-uri "<url>"` (convenient, but visible in `ps` while the script runs), or
2. the environment variable `NEW_CLIENT_MONGO_URI`, or
3. a hidden prompt (no echo) when neither is given.

Rules: the scheme must be `mongodb://` or `mongodb+srv://`; the URL should name the database
(`.../acme_prod`). If it has none, `/<slug>_prod` is appended and you are told. Percent-encode special
characters in the password. `localhost`/`127.0.0.1` are refused because inside a container they mean the
container itself.

A MongoDB running on the Docker host: use `host.docker.internal` (Docker Desktop provides it; on Linux the
compose file maps it with `extra_hosts: host-gateway`). Local replica sets advertise members such as
`127.0.0.1:27017` that a container cannot reach, so add `?directConnection=true`:
`mongodb://host.docker.internal:27017/acme_prod?directConnection=true`. The MongoDB must listen on an
address Docker can reach (on Linux not only 127.0.0.1). Atlas needs nothing special (allow the server's IP
in the Atlas access list).

Backups and exports run `mongodump --uri` from a one-shot throw-away container (`mongo:7`, `--rm`, named
`demomart-<slug>-tools-<pid>`, no server started) that receives the URL through its environment.

## Quick start

```bash
cd deploy
# local test client on a *.localhost domain (plain HTTP); the MongoDB URL is asked for (hidden input)
./new-client.sh acme "Acme Traders" acme.localhost

# the same, URL from the environment, plus a product catalog imported after start-up
NEW_CLIENT_MONGO_URI='mongodb+srv://user:pw@cluster0.example.mongodb.net/acme_prod' \
  ./new-client.sh acme "Acme Traders" acme.localhost --catalog ../docs/catalog-import-sample.xlsx

# real domain on a public server (ports 80/443, automatic HTTPS)
./new-client.sh acme "Acme Traders" acme-trade.example --standard-ports --admin-email owner@acme-trade.example
```

`new-client.sh` validates the slug (`^[a-z0-9-]{2,30}$`), refuses an existing `clients/<slug>`,
writes `clients/<slug>/.env` (fresh 64-character JWT secrets, your MongoDB URL, mode 0600), builds the three
images with the client's URLs baked in, starts everything, waits for health, creates the admin, optionally
imports the catalog and prints the URLs. If it stops half-way, fix the cause and re-run the same command with
`--resume`.

| Option | Meaning |
| --- | --- |
| `--mongo-uri <url>` | MongoDB URL (see above). |
| `--catalog <file>` | After start-up runs `catalog-import.js --dry-run`, then `--create-missing`. The file is mounted read-only at `/import/` in a throw-away container. |
| `--port-base N` | Five consecutive host ports: N proxy http, N+1 proxy https, N+2 API, N+3 admin, N+4 site. Default is derived from the slug (20000-23990); busy blocks are skipped. |
| `--standard-ports` | Proxy on 80/443, needed for automatic HTTPS on a real domain. |
| `--behind-proxy` | TLS is ended by another proxy on the same host; this stack serves plain HTTP on `--port-base`. |
| `--admin-email`, `--brand-short`, `--brand-email`, `--brand-phone`, `--brand-address` | First admin and brand values (all have defaults). |

There is no demo-data mode in a deployed client: the backend's demo guard only accepts a local database whose
name contains `demo`, which an external MongoDB URL can never satisfy. To show the demo dataset run it locally:
`cd backend && npm run demo:mongo && npm run demo:reset && npm start`.

Hostnames: `<domain>` is the public site, `admin.<domain>` the admin panel, `api.<domain>` the API.

## Per-client configuration

All settings live in `clients/<slug>/.env`; `clients/example/.env.example` documents every variable.
Change a value, then run `./update-client.sh <slug>` (NEXT_PUBLIC values are compiled into the admin and
site images, so URL or port changes need that rebuild).

| Setting | Variables |
| --- | --- |
| Brand (API texts, receipts, exports) | `BRAND_NAME`, `BRAND_SHORT_NAME`, `BRAND_LEGAL_NAME`, `BRAND_EMAIL`, `BRAND_PHONE`, `BRAND_ADDRESS`, `BRAND_WEBSITE` (read by `backend/src/config/brand.js`; blank = built-in defaults) |
| Hosts and URLs | `DOMAIN`, `API_HOST`, `ADMIN_HOST`, `SITE_HOST`, `PUBLIC_API_URL`, `PUBLIC_ADMIN_URL`, `PUBLIC_SITE_URL`, `CORS_ORIGIN` |
| Ports | `PORT_BASE`, `PROXY_HTTP_PORT`, `PROXY_HTTPS_PORT`, `BACKEND_PORT`, `ADMIN_PORT`, `SITE_PORT` |
| Database | `MONGODB_URI` (single-quoted), `MONGO_DB_NAME` (database named in the URL), `MONGO_TOOLS_IMAGE` |
| Secrets | `JWT_SECRET`, `JWT_REFRESH_SECRET` (never reuse between clients) |
| Admin / mail | `ADMIN_EMAIL`, `ADMIN_EMAILS`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_FROM` |

What runs: `backend` (node 22 alpine, non-root, production dependencies, `/health` check, uploads volume
mounted at `/data`), `admin` and `site` (`next build` + `next start`, non-root) and `proxy` (Caddy). Nothing
else: no database container, no replica-set init.

## Signing in as admin (important)

With `DEMO_MODE=false` the API **refuses password sign-in for admin accounts** (`POST /auth/login`);
admins can only sign in with a single-use magic link (`/auth/magic-link/*`), which the API emails and which
needs SMTP. The admin panel's login form is a password form, so it cannot be used for an empty client.
No auth code was changed. Instead:

- `./admin-login.sh <slug>` (also run once by `new-client.sh`) stores a single-use link token directly in the
  database (only its hash) through `backend/scripts/create-admin.js` and prints
  `<admin-url>/login/verify?token=...`. Open it in a browser to sign in. Default validity 30 minutes
  (`--minutes N`). No SMTP required. Whoever can run it already has Docker/database access.
- Or set `SMTP_*` and `EMAIL_FROM` in `.env`, run `./update-client.sh <slug>`, and use the emailed link.
- Staff accounts (username + password, created inside the panel) are unaffected and can sign in normally.

Note: the admin login page still displays the demo credentials hint for every client (it is hard-coded in
the admin app).

## Backup, export, restore

```bash
./backup-client.sh <slug>                 # backups/<slug>/<timestamp>/{mongodb-<db>.archive.gz, uploads.tar.gz, SHA256SUMS, RESTORE.txt}
                                          # (database via mongodump --uri from a throw-away container; no mongo container exists)
./export-client.sh <slug> [--out dir]     # exports/<slug>-<YYYYmmdd-HHMM>/
```

An export contains: the `mongodump --archive --gzip` of the client's database, `uploads.tar.gz` (public
uploads and private media), `data/export.xlsx` plus one CSV per dataset (products, products in the catalog
import format, brands, categories, customers, orders, order items, order status history, payments,
negotiations and their history, price history, stock logs), `manifest.json` (client, database, counts, size
and SHA-256 of every file, export time) and a `README.txt` with the restore steps. The readable files contain
no password hashes, tokens, refresh tokens or FCM tokens; the export script reads customers through an
explicit field allow-list. The database dump is a full copy and does include them: store it like a secret.
`.env` (secrets) is not included in either; keep it separately.

Restore (the URL is your own MongoDB; it is also in `clients/<slug>/.env` as `MONGODB_URI`):

```bash
mongorestore --uri "<your MongoDB URL>" --archive=mongodb-<db>.archive.gz --gzip --drop --nsInclude '<db>.*'
# without mongorestore installed:
docker run --rm -i -e MONGODB_URI mongo:7 sh -c 'mongorestore --uri="$MONGODB_URI" --archive --gzip --drop --nsInclude "<db>.*"' < mongodb-<db>.archive.gz
# uploads, into the running client:
docker compose -p demomart-<slug> --env-file clients/<slug>/.env exec -T backend tar -C /data -xzf - < uploads.tar.gz
```

`backend/scripts/export-client-data.js` (`npm run export:client-data -- --out dir --slug <slug> --db <name>`)
refuses to run when `--db`/`--slug` do not match the connected database or when the connected database is
declared by a different client in `clients/*/.env`.

## Importing a catalog

At creation: `--catalog file.xlsx`. Later, on a running client:

```bash
docker compose -p demomart-<slug> --env-file clients/<slug>/.env run --rm -T --no-deps \
  -v "$PWD/catalog.xlsx:/import/catalog.xlsx:ro" backend \
  node scripts/catalog-import.js /import/catalog.xlsx --actor <admin email> --dry-run
# same command without --dry-run but with --create-missing to write
```

A client's own `data/products_catalog_import.csv` from an export uses the same columns, so it can be loaded
into another client this way.

## Updating, stopping, destroying

```bash
./update-client.sh <slug> [--no-cache] [--pull]   # rebuild images, restart backend, admin, site, proxy one by one; data kept
./stop-client.sh <slug>                            # containers removed, uploads volume kept
./stop-client.sh <slug> --destroy-data [--remove-config]
```

`--destroy-data` lists what will be deleted, then asks you to type the slug and then `DELETE <slug>`
(read from stdin, so it also works with a pipe). Only that project's containers, volumes (uploads, proxy
certificates), network and locally built images are removed; there is no global prune anywhere.
**It never touches the database**: dropping `<db>` on your MongoDB is your own action. Take a backup or export
first, because the uploads are lost.

## Ports

Per client, bound as follows: proxy http and https on `--port-base`/`+1` (loopback for local domains and
`--behind-proxy`, all interfaces for automatic HTTPS), direct API/admin/site on `+2/+3/+4` (loopback only).
There is no MongoDB port (the database is external). Several clients on one server: give each a different `--port-base`. Only one stack
can own 80/443; additional public clients use `--behind-proxy` behind a shared proxy (for example one Caddy on
80/443 forwarding `<host>` to `127.0.0.1:<port-base>` with the Host header preserved).

## Security notes

- `clients/*/.env`, `ADMIN_CREDENTIALS.txt`, backups and exports are gitignored; keep them out of shared folders.
- JWT secrets are generated per client (64 hex characters) and checked by the API at start-up (32+ characters).
- The API runs in production mode: CORS only allows the client's own admin and site origins, one trusted proxy
  hop (the per-client Caddy), stack traces off, files stored locally on the `uploads` volume.
- No Firebase, push or payments. SMTP is optional and only used for the admin magic link.
- Use a dedicated database user per client with access to that client's database only; keep the Atlas access
  list to the server's address.
- Back up `uploads` and the database together; the private media signing key is derived from `JWT_SECRET`.
- The MongoDB URL contains credentials: it lives only in `clients/<slug>/.env`, is passed to containers through
  the environment and is masked in every message the scripts print.

## Troubleshooting

- `Port ... not free`: pick another `--port-base`; `./list-clients.sh` shows the ports in use.
- Backend exits right after start: `docker compose -p demomart-<slug> --env-file clients/<slug>/.env logs backend`.
  Typical causes: unreachable MongoDB (access list, `host.docker.internal` without `?directConnection=true`,
  wrong password), or a short JWT secret.
- Browser cannot open `*.localhost`: add `127.0.0.1 <domain> admin.<domain> api.<domain>` to `/etc/hosts`
  .
- Build fails in `npm ci`: the images install npm 11 for the lock files; check network access.
- Admin sign-in says invalid credentials: expected for passwords with `DEMO_MODE=false`; use `./admin-login.sh <slug>`.
- Real domain: DNS A records for `<domain>`, `admin.<domain>`, `api.<domain>` must point to the server and
  ports 80/443 must be reachable before certificates can be issued.
