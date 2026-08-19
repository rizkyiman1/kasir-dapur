# Render Deployment Guide — Kasir Dapur Backend (Staging)

Status: **READY FOR RENDER DEPLOYMENT**

Scope ini hanya compatibility deploy Render. Tidak ada perubahan arsitektur billing/payment.

## 1) Prasyarat

1. Akun Render (workspace **Mas Rizky's workspace** sudah terhubung ke API key).
2. Repository Git (GitHub/GitLab/Bitbucket) berisi project ini — Render deploy dari repo, bukan upload zip.
3. Plan **Starter** atau lebih tinggi — **persistent disk wajib** untuk SQLite (`/data/billing.db`).
4. Jangan gunakan free tier untuk staging API (sleep memutus webhook Midtrans).

## 2) File deploy di repo

| File | Fungsi |
|------|--------|
| `Dockerfile` | Build Dart backend jadi binary `/app/server` |
| `render.yaml` | Blueprint: web service, disk, env, health check |
| `deploy/env.render.staging.example` | Template env vars (tanpa secret) |

## 3) Setup via Blueprint (disarankan)

1. Push repo ke GitHub (atau Git provider yang sudah di-connect ke Render).
2. Dashboard Render → **New** → **Blueprint**.
3. Pilih repo + branch `main`.
4. Render membaca `render.yaml` dan membuat service `kasir-dapur-backend-staging`.
5. Saat prompt env `sync: false`, isi:
   - `PUBLIC_BASE_URL` → URL Render (`https://<service>.onrender.com`) atau custom domain nanti
   - `MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_MERCHANT_ID` (sandbox)
6. Deploy pertama ~5–10 menit (Docker build Dart).

## 4) Service configuration

- **Runtime:** Docker (`Dockerfile` di root)
- **Region:** Singapore (dekat Indonesia)
- **Instances:** 1 (SQLite single-writer)
- **Health check:** `GET /health`
- **Persistent disk:** mount `/data`, size 1 GB
- **SQLite path:** `BILLING_SQLITE_PATH=/data/billing.db`

## 5) Required environment variables

Isi di Render Dashboard → Environment (jangan commit secret):

- `PUBLIC_BASE_URL=https://api-staging.dapur-rasa.com` (atau `.onrender.com` sementara)
- `PORT` — Render set otomatis
- `JWT_SECRET` — min 32 karakter (`render.yaml` bisa auto-generate)
- `MIDTRANS_SERVER_KEY`, `MIDTRANS_CLIENT_KEY`, `MIDTRANS_MERCHANT_ID`
- `MIDTRANS_ENVIRONMENT=SANDBOX`
- `MIDTRANS_IS_PRODUCTION=false`
- `BILLING_SQLITE_PATH=/data/billing.db`
- `ENFORCE_PRODUCTION_SECRETS=true`
- `PLAN_PRICE_PRO_MONTHLY=49000`
- `PLAN_PRICE_PRO_YEARLY=490000`
- `PLAN_PRICE_BUSINESS_MONTHLY=99000`
- `PLAN_PRICE_BUSINESS_YEARLY=990000`

Trusted proxy (aman dulu):

- `TRUST_PROXY_HEADERS=false`
- `TRUSTED_PROXY_IPS=`

Template: `deploy/env.render.staging.example`

## 6) Custom domain (opsional)

Dashboard → service → **Settings** → **Custom Domains** → tambah `api-staging.dapur-rasa.com`.

Catat CNAME/A record dari Render, update DNS provider, tunggu propagasi.

Update `PUBLIC_BASE_URL` ke domain final setelah DNS live.

## 7) Midtrans webhook

Set Notification URL di Midtrans Dashboard (sandbox):

`https://<PUBLIC_BASE_URL>/v1/billing/webhooks/midtrans`

Ganti `<PUBLIC_BASE_URL>` dengan URL yang benar-benar live.

## 8) Verifikasi setelah deploy

Jalankan smoke test dari mesin lokal:

```powershell
.\scripts\staging_smoke_test.ps1 -BaseUrl "https://<service>.onrender.com"
```

Cek:

- `GET /health` → 200
- Auth JWT + tenant isolation
- Entitlement endpoint
- Midtrans sandbox create transaction (jika key sudah diisi)
- Restart service → data SQLite tetap ada (disk persistence)

## 9) Render vs Railway

| Aspek | Render | Railway |
|-------|--------|---------|
| Config file | `render.yaml` + `Dockerfile` | `railway.toml` |
| SQLite persistence | Persistent Disk `/data` | Volume `/data` |
| Health check | `healthCheckPath: /health` | `healthcheckPath` di toml |
| Free tier | Sleep → webhook putus | Resource limit berbeda |

Keduanya compatible; pilih salah satu PaaS.

## 10) Keamanan API key Render

- Simpan API key di password manager, **bukan** di repo atau chat.
- Rotasi key di Dashboard → Account Settings → API Keys jika pernah terexpose.
- Gunakan key hanya untuk otomasi/CLI, never commit.

## 11) Troubleshooting

**Build gagal — Dart compile error**

- Pastikan `backend/pubspec.lock` ter-commit.
- Cek log build di Render Events.

**502 / health check fail**

- Pastikan `PORT` dari env dipakai (backend sudah support).
- Cek `ENFORCE_PRODUCTION_SECRETS` — JWT/Midtrans harus terisi.

**Data hilang setelah redeploy**

- Disk belum attach atau `BILLING_SQLITE_PATH` di luar `/data`.

**Webhook Midtrans tidak masuk**

- Service sleep (free tier) atau `PUBLIC_BASE_URL` salah.
- URL webhook harus HTTPS publik.
