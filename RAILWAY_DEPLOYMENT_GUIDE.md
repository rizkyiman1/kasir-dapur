# Railway Deployment Guide — Kasir Dapur Backend (Staging)

Status: **READY FOR RAILWAY DEPLOYMENT**

Scope ini hanya compatibility deploy Railway. Tidak ada perubahan arsitektur billing/payment.

## 1) Railway project setup

1. Buat project Railway baru.
2. Hubungkan repository ini.
3. Set root project tetap di repository root (karena `railway.toml` ada di root).

## 2) Service setup

- Service backend berjalan dari folder `backend/`.
- Konfigurasi minimal sudah disiapkan di `railway.toml`.

## 3) Build command

Railway akan menjalankan:

`cd backend; dart pub get; dart compile exe bin/server.dart -o server`

## 4) Start command

Railway akan menjalankan:

`cd backend; ./server`

Backend membaca `PORT` dari environment, default lokal tetap `8080`.

## 5) Required environment variables

Isi di Railway Variables (jangan commit secret):

- `PUBLIC_BASE_URL=https://api-staging.dapur-rasa.com`
- `PORT` (Railway set otomatis; optional override)
- `JWT_SECRET`
- `MIDTRANS_SERVER_KEY`
- `MIDTRANS_CLIENT_KEY`
- `MIDTRANS_MERCHANT_ID`
- `MIDTRANS_ENVIRONMENT=SANDBOX`
- `MIDTRANS_IS_PRODUCTION=false` (compatibility flag opsional)
- `BILLING_SQLITE_PATH=/data/billing.db`
- `ENFORCE_PRODUCTION_SECRETS=true`
- `PLAN_PRICE_PRO_MONTHLY=49000`
- `PLAN_PRICE_PRO_YEARLY=490000`
- `PLAN_PRICE_BUSINESS_MONTHLY=99000`
- `PLAN_PRICE_BUSINESS_YEARLY=990000`

Trusted proxy (aman dulu):

- `TRUST_PROXY_HEADERS=false`
- `TRUSTED_PROXY_IPS=`

Template siap: `deploy/env.railway.staging.example`

## 6) Persistent volume configuration

Di Railway, tambahkan Volume ke service backend.

## 7) Mount path

Set mount path volume ke:

`/data`

Lalu set:

`BILLING_SQLITE_PATH=/data/billing.db`

Ini menjaga SQLite tetap persistent antar restart/redeploy.

## 8) Health check

- Endpoint: `GET /health`
- Public, tanpa JWT.
- Tidak membocorkan secret (hanya metadata aman).
- `railway.toml` sudah set `healthcheckPath = "/health"`.

## 9) Custom domain

Tambahkan custom domain Railway:

`api-staging.dapur-rasa.com`

## 10) DNS requirement

Set record DNS sesuai target Railway yang diberikan dashboard:

- CNAME (atau A/AAAA sesuai instruksi Railway)
- Host: `api-staging.dapur-rasa.com`
- Target: `<railway-provided-domain>`

Jangan klaim aktif sebelum `nslookup` resolve dan `https://api-staging.dapur-rasa.com/health` return 200.

## 11) Midtrans sandbox webhook

Set Notification URL pada Midtrans sandbox:

`https://api-staging.dapur-rasa.com/v1/billing/midtrans/notification`

Wajib sandbox credential di staging.

## 12) Staging smoke test

Setelah URL hidup:

```powershell
$env:STAGING_API_URL = "https://api-staging.dapur-rasa.com"
$env:STAGING_USER_A = "<dummy-user-id>"
$env:STAGING_PIN_A = "<dummy-pin>"
.\scripts\staging_smoke_test.ps1
```

Lanjutkan test matrix entitlement/isolation/midtrans sesuai checklist staging.

## 13) Rollback procedure

1. Railway Deployments → pilih deployment terakhir yang sehat.
2. Klik rollback/redeploy deployment sehat.
3. Verifikasi `GET /health` dan endpoint auth/subscription.

## 14) Backup / restore SQLite

- Volume persistence aktif, tetapi tetap lakukan backup rutin.
- Ikuti `DEPLOYMENT_BACKUP_RUNBOOK.md`.
- Minimal: backup file SQLite sebelum perubahan besar konfigurasi atau release backend.

## 15) Security notes

- Jangan simpan secret di repo.
- Set `ENFORCE_PRODUCTION_SECRETS=true`.
- Staging wajib Midtrans sandbox.
- Jangan ubah pricing/subscription matrix dari nilai yang sudah ditetapkan.
- Jangan ubah authority model: SQLite backend (billing), Midtrans (payment), JWT business_id (tenant).
- Trusted proxy jangan diaktifkan agresif sebelum topology Railway diverifikasi.

---

## Compatibility result

- `PORT` sudah env-driven (`BackendConfig.fromMap`).
- `BILLING_SQLITE_PATH` sudah env-driven.
- Binary build berhasil: `dart compile exe bin/server.dart`.
- Analyze/test backend lulus.

Kesimpulan: **READY FOR RAILWAY DEPLOYMENT**.
