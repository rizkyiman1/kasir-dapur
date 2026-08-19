# STAGING DEPLOYMENT REPORT — Kasir Dapur

**Tanggal:** 2026-08-20  
**Status keseluruhan:** **WAITING FOR STAGING ACCESS**  
**Pertanyaan:** *Apakah aplikasi benar-benar bisa dipakai secara nyata?* → **Belum dapat dijawab** (API staging belum hidup / tidak dapat diakses dari environment ini).

---

## A. Deployment target

| Item | Hasil | Evidence |
|---|---|---|
| Dockerfile / docker-compose | **NOT APPLICABLE** | Tidak ada di repository |
| systemd unit | **NOT APPLICABLE** | Tidak ada di repository |
| Nginx/Caddy/Apache config | **NOT APPLICABLE** | Tidak ada di repository |
| CI/CD pipeline | **NOT APPLICABLE** | Hanya checklist manual (`PRODUCTION_RELEASE_CHECKLIST.md`) |
| Cloudflare / LB config | **NOT APPLICABLE** | Tidak ada di repository |
| SSH / VPS credentials | **NOT VERIFIED** | Tidak tersedia di workspace Cursor |
| Backend `.env` staging | **NOT VERIFIED** | Hanya `backend/.env.example`; tidak ada `.env` aktual |

**Kesimpulan discovery:** Repository siap di-build, tetapi **tidak memuat artefak deployment runtime**. Deployment staging membutuhkan akses/informasi dari operator.

---

## B. Backend URL / domain

| Host | DNS | HTTP probe | HTTPS probe |
|---|---|---|---|
| `api-staging.dapur-rasa.com` | **FAILED** — NXDOMAIN | N/A | N/A |
| `api.dapur-rasa.com` | **FAILED** — NXDOMAIN | N/A | N/A |
| `api-dev.dapur-rasa.com` | **FAILED** — NXDOMAIN | N/A | N/A |
| `dapur-rasa.com` (website) | Resolves | — | **200** |

**Evidence (dari mesin build):**
```
nslookup api.dapur-rasa.com → Non-existent domain
nslookup api-staging.dapur-rasa.com → Non-existent domain
curl https://dapur-rasa.com/ → HTTP 200
```

Flutter config staging (source): `lib/config/env.dart` → `https://api-staging.dapur-rasa.com`  
**Domain belum terdaftar di DNS** → smoke test runtime **tidak dapat dilanjutkan**.

---

## C. Deployment result

| Item | Status |
|---|---|
| Backend deploy ke staging | **NOT VERIFIED** — DNS API tidak ada, tidak ada akses server |
| Startup backend | **NOT VERIFIED** |
| ENFORCE_PRODUCTION_SECRETS | **NOT VERIFIED** |

---

## D. Health check

| Test | Status |
|---|---|
| `GET /health` staging | **NOT VERIFIED** — host tidak resolve |

---

## E. TLS result

| Test | Status |
|---|---|
| Certificate valid staging API | **NOT VERIFIED** |
| Hostname match | **NOT VERIFIED** |
| HTTP → HTTPS behavior | **NOT VERIFIED** |

---

## F. Security headers

| Header | Status |
|---|---|
| Strict-Transport-Security | **NOT VERIFIED** |
| X-Content-Type-Options | **NOT VERIFIED** |
| Referrer-Policy | **NOT VERIFIED** |
| CORS | **NOT VERIFIED** |

---

## G. Trusted proxy result

| Test | Status |
|---|---|
| Remote peer benar di belakang proxy | **NOT VERIFIED** |
| XFF spoof dari public client tidak bypass rate limit | **NOT VERIFIED** |

---

## H. Authentication

| # | Test | Status |
|---|---|---|
| 1 | `/health` → 200 | **NOT VERIFIED** |
| 2 | Cloud auth valid | **NOT VERIFIED** |
| 3 | Credential invalid → 401 | **NOT VERIFIED** |
| 4 | Repeated invalid → 429 | **NOT VERIFIED** |
| 5 | Protected tanpa token → 401 | **NOT VERIFIED** |
| 6 | Protected + token valid | **NOT VERIFIED** |
| 7 | Expired/invalid token → 401 | **NOT VERIFIED** |
| 8 | Wrong issuer → 401 | **NOT VERIFIED** |
| 9 | Role tidak cukup → 403 | **NOT VERIFIED** |

---

## I. Authorization

| Test | Status |
|---|---|
| FREE → premium endpoint → 403 | **NOT VERIFIED** |
| PRO → business-only → 403 | **NOT VERIFIED** |
| BUSINESS → business endpoint | **NOT VERIFIED** |
| API access / priority support → 501 | **NOT VERIFIED** |

---

## J. Tenant isolation

| Test | Status |
|---|---|
| Cross-business backup/device/branch/subscription | **NOT VERIFIED** |
| Client override `business_id` diabaikan (JWT authority) | **NOT VERIFIED** |

---

## K. Subscription entitlement

| Plan | Status |
|---|---|
| FREE limits | **NOT VERIFIED** |
| PRO limits | **NOT VERIFIED** |
| BUSINESS limits | **NOT VERIFIED** |

---

## L. Midtrans sandbox

| Test | Status |
|---|---|
| Checkout PRO/Business plans | **NOT VERIFIED** |
| Amount tampering rejected | **NOT VERIFIED** |
| Duplicate webhook idempotent | **NOT VERIFIED** |
| Invalid signature denied | **NOT VERIFIED** |

---

## M. Backup / N. Sync / O. Business features

| Area | Status |
|---|---|
| Cloud backup (PRO+) | **NOT VERIFIED** |
| Cloud sync (BUSINESS) | **NOT VERIFIED** |
| Device / branch / role / dashboard / report | **NOT VERIFIED** |

---

## P. APK/AAB runtime

| Test | Status | Catatan |
|---|---|---|
| Release AAB build | **VERIFIED** (build lokal) | `app-release.aab` 67.9MB dengan keystore valid |
| Install + login ke staging API | **NOT VERIFIED** | API staging tidak hidup |
| `--dart-define=ENV=staging` | **NOT VERIFIED** runtime | Source: `EnvConfig.staging` → `api-staging.dapur-rasa.com` |

---

## Q. Logging / security (runtime)

| Test | Status |
|---|---|
| Log tidak bocor secret/token | **NOT VERIFIED** |
| HTTP 500 generic ke client | **VERIFIED** (source + unit test) |

---

## R. Regression tests (source)

| Suite | Status | Evidence |
|---|---|---|
| `dart test` (backend) | **VERIFIED** | 110 passed (Tahap 3.1) |
| `flutter test` | **VERIFIED** | 222 passed (Tahap 3.1) |
| Ulang setelah Tahap 3.5 | **NOT APPLICABLE** | Tidak ada perubahan source selama discovery |

---

## Yang sudah diverifikasi (bukan runtime staging)

1. Release signing: tanpa keystore → build gagal dengan pesan jelas.
2. Release AAB dapat dibuat dengan keystore valid.
3. Debug APK dapat dibuat dengan `ENV=prod`.
4. Source regression test lulus penuh (Tahap 3.1).
5. Website `https://dapur-rasa.com` merespons HTTP 200.
6. **Subdomain API belum ada di DNS** — blocker deployment staging.

---

## Informasi yang dibutuhkan dari Anda

Agar Tahap 3.5 dapat dilanjutkan (deploy + smoke test nyata), mohon sediakan:

### 1. DNS & domain
- [ ] Record DNS untuk `api-staging.dapur-rasa.com` (A/AAAA atau CNAME)
- [ ] (Opsional) `api.dapur-rasa.com` untuk production nanti
- [ ] Konfirmasi TLS certificate sudah terpasang di edge

### 2. Server / hosting
- [ ] Host staging (VPS IP, SSH user, atau panel deploy)
- [ ] Cara deploy backend (manual, Docker, systemd, platform) — **yang benar-benar dipakai**
- [ ] Port internal backend & reverse proxy target

### 3. Environment staging (via secret manager / `.env` di server — **jangan commit**)
- [ ] `JWT_SECRET` (staging, kuat)
- [ ] `MIDTRANS_SERVER_KEY` / `MIDTRANS_CLIENT_KEY` (sandbox jika tersedia)
- [ ] `MIDTRANS_MERCHANT_ID`
- [ ] `ENFORCE_PRODUCTION_SECRETS=true` (jika secret sudah valid)
- [ ] `TRUST_PROXY_HEADERS` + `TRUSTED_PROXY_IPS` (jika di belakang proxy)
- [ ] Path writable untuk `BILLING_SQLITE_PATH`

### 4. Test accounts (data dummy staging)
- [ ] User A: `user_id`, PIN, role, business_id (FREE atau PRO)
- [ ] User B: `user_id`, PIN, role, business_id (untuk isolation test)
- [ ] (Opsional) User BUSINESS untuk entitlement test

### 5. Midtrans
- [ ] Konfirmasi sandbox aktif + notification URL staging
- [ ] Server key sandbox (hanya di server, bukan repo)

### 6. Flutter staging build
- [ ] Konfirmasi APK/AAB harus `--dart-define=ENV=staging` atau `prod` dengan API staging

---

## Skrip smoke test (siap dijalankan setelah staging hidup)

Setelah DNS + backend deploy:

```powershell
$env:STAGING_API_URL = "https://api-staging.dapur-rasa.com"
$env:STAGING_USER_A = "<user-id-A>"
$env:STAGING_PIN_A = "<pin-A>"
.\scripts\staging_smoke_test.ps1
```

Laporan JSON: `staging-smoke-results.json` (tanpa secret).

---

## GO-LIVE DECISION

| Status | **WAITING FOR STAGING ACCESS** |
|---|---|
| Alasan | Subdomain API tidak resolve; tidak ada akses server/deploy; smoke test runtime tidak dapat dieksekusi |
| Blocker utama | DNS `api-staging.dapur-rasa.com` + deploy backend + test credentials |
| Setelah staging PASS | Re-evaluate → **READY FOR PRODUCTION CANDIDATE** atau **BLOCKED** berdasarkan hasil smoke test |

**Jawaban singkat:** Aplikasi **belum terbukti bisa dipakai secara nyata** end-to-end, karena backend API staging **belum hidup/terjangkau**. Source hardening sudah siap; langkah berikutnya murni operasional (DNS → deploy → smoke test).
