# Example client configuration

`./new-client.sh <slug> "<Client Name>" <domain>` creates `deploy/clients/<slug>/` containing:

| File | What it is |
| --- | --- |
| `.env` | All settings, the client's MongoDB URL and freshly generated secrets for that client (mode 0600, gitignored). Documented in `.env.example` here. |
| `brand.json` | Reference copy of the brand values (name, contact details). The running API reads the `BRAND_*` variables in `.env`; change them there and run `./update-client.sh <slug>`. |
| `ADMIN_CREDENTIALS.txt` | How to sign in as admin (mode 0600, gitignored). Never contains a password (admins sign in with a one-time link). |
| `setup.log`, `update.log` | Build and start-up output. |

Only this `example/` folder is tracked by git; everything else under `clients/` is ignored.
