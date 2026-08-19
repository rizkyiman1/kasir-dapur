# Deployment Requirements — Kasir Dapur Backend

Arsitektur MVP: **single VPS, single instance, SQLite authority, reverse proxy TLS termination**.

```
Internet → HTTPS Reverse Proxy → Backend (Dart/Shelf, localhost) → SQLite (persistent disk)
```

---

## Runtime

| Item | Requirement |
|---|---|
| Dart SDK | **^3.13.0** (sesuai `backend/pubspec.yaml`) |
| OS | Linux x64 recommended (Ubuntu 22.04+ / Debian 12+) |
| CPU/RAM (MVP) | 1 vCPU, 1–2 GB RAM minimum |
| Disk | Persistent volume untuk SQLite + logs; rekomendasi ≥ 10 GB |

---

## Build

| Step | Command | Working directory |
|---|---|---|
| Resolve deps | `dart pub get` | `backend/` |
| Compile binary (recommended) | `dart compile exe bin/server.dart -o /opt/dapur-kasir/bin/kasir-dapur-backend` | `backend/` |
| Alternative (needs SDK on server) | `dart run bin/server.dart` | `backend/` |

**Verified locally:** `dart compile exe bin/server.dart` berhasil (Dart 3.13.0).

---

## Start / Stop

| Action | Command |
|---|---|
| Start (systemd) | `sudo systemctl start dapur-kasir-backend` |
| Stop | `sudo systemctl stop dapur-kasir-backend` |
| Restart | `sudo systemctl restart dapur-kasir-backend` |
| Status | `sudo systemctl status dapur-kasir-backend` |
| Health (local) | `curl -sS http://127.0.0.1:8080/health` |
| Health (public) | `curl -sS https://api-staging.dapur-rasa.com/health` |

Graceful shutdown: `SIGINT` → `runtime.close()` → billing DB closed → HTTP server closed (`backend/bin/server.dart`).

---

## Network

| Item | Default | Notes |
|---|---|---|
| Listen | `0.0.0.0:8080` | Configurable via `PORT` |
| Public exposure | **Reverse proxy only** | Jangan expose port backend langsung ke internet |
| Health endpoint | `GET /health` | Public, no auth, no secrets in body |

---

## Environment variables (required for staging/production)

Dibaca dari `Platform.environment` + optional `backend/.env` (file `.env` **tidak** di-commit).

| Variable | Required (staging/prod) | Purpose |
|---|---|---|
| `PORT` | Recommended | HTTP port (default `8080`) |
| `PUBLIC_BASE_URL` | **Yes** | Public HTTPS URL (Midtrans webhook, links) |
| `JWT_SECRET` | **Yes** | HS256 signing (min 32 chars) |
| `MIDTRANS_ENVIRONMENT` | **Yes** | `SANDBOX` (staging) / `PRODUCTION` (prod) |
| `MIDTRANS_SERVER_KEY` | **Yes** | Backend only |
| `MIDTRANS_CLIENT_KEY` | **Yes** | Backend only |
| `MIDTRANS_MERCHANT_ID` | **Yes** | Backend only |
| `PLAN_PRICE_*` | **Yes** | Integer Rupiah (catalog authority) |
| `PLAN_GRACE_DAYS` | Recommended | Default `7` |
| `BILLING_SQLITE_PATH` | **Yes** | Absolute path on persistent disk |
| `ENFORCE_PRODUCTION_SECRETS` | **Yes** | Set `true` on staging/prod |
| `TRUST_PROXY_HEADERS` | Recommended | `true` when behind nginx/Caddy |
| `TRUSTED_PROXY_IPS` | If proxy enabled | e.g. `127.0.0.1` for local nginx |
| `GOOGLE_SHEETS_*` | Optional | Only if Sheets mirror enabled |
| `BACKUP_BUCKET` | Optional | Reserved |

Startup gate: jika `ENFORCE_PRODUCTION_SECRETS=true` dan secret kosong/placeholder → process exit dengan pesan generic (nama variable saja).

---

## Writable directories

| Path | Purpose |
|---|---|
| Directory containing `BILLING_SQLITE_PATH` | SQLite DB + WAL (`billing.db`, `-wal`, `-shm`) |
| `/var/log/dapur-kasir/` (recommended) | Application logs via journald/systemd |
| `backend/var/` (dev default) | **Jangan** pakai di production VPS |

Default jika `BILLING_SQLITE_PATH` unset: `{cwd}/var/billing.db`

---

## SQLite

| Item | Requirement |
|---|---|
| Location | Persistent disk (e.g. `/var/lib/dapur-kasir/billing.db`) |
| Mode | WAL enabled (`PRAGMA journal_mode=WAL`) |
| Instances | **Exactly one** backend writer per DB file |
| Permissions | Owner = service user, mode `640` or tighter |
| Backup | File-level copy while graceful stop OR SQLite backup API (see runbook) |

---

## Logging

- Request logging via Shelf `logRequests` with redaction (Bearer tokens, Midtrans server key patterns).
- Startup log: brand, port, Midtrans environment — **no secret values**.
- Do not enable debug/trace in staging/prod.

---

## Health check response (safe fields)

`GET /health` returns: `ok`, `brand`, `owner`, `company`, `website`, `midtrans_environment`, `midtrans_configured`, `pricing_ready`, `google_sheets_configured`.

**Does not** return: JWT, Midtrans keys, DB paths, stack traces.

---

## Midtrans webhook URL

Register in Midtrans dashboard:

```
{PUBLIC_BASE_URL}/v1/billing/midtrans/notification
```

Example staging: `https://api-staging.dapur-rasa.com/v1/billing/midtrans/notification`

---

## Deployment artifacts

See `deploy/` directory:

- `build-linux.sh` — compile on Linux VPS
- `dapur-kasir-backend.service.example` — systemd unit
- `reverse-proxy.nginx.example.conf` — TLS template
- `env.staging.example` / `env.production.example` — env templates
- `health-check.sh` — local health probe

---

## Docker recommendation

**Not included by default.** For MVP single VPS, systemd + compiled binary is simpler and matches current repo.

Docker is optional later if you need reproducible builds; requires separate Dockerfile maintenance. **No Docker artifact added** unless you request it after reviewing this package.

---

## Status

| Area | Status |
|---|---|
| Deployment package | **READY TO DEPLOY** (after server provisioned) |
| Server/DNS | **NEEDS SERVER** / **NEEDS DNS** |
| Secrets on VPS | **NEEDS SECRET CONFIG** |
| Runtime smoke test | **NEEDS RUNTIME VERIFICATION** |
