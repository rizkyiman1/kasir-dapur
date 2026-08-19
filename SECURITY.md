# Security Policy — Kasir Dapur

**Pemilik:** PT Dapur Rasa Karya Nusantara · Mas Rizky Iman  
**Website:** https://dapur-rasa.com  
**Audit terakhir:** 2026-08-19

---

## 1. Cakupan Audit

Audit ini mencakup seluruh project Kasir Dapur:

| Area | Status |
|------|--------|
| `lib/` — Flutter client | ✅ Diaudit |
| `backend/` — Dart Shelf server | ✅ Diaudit |
| `assets/` | ✅ Diaudit |
| Android source (`android/`) | ✅ Diaudit |
| File konfigurasi (`.gitignore`, `.env.example`) | ✅ Diaudit |

---

## 2. Temuan dan Status

### 2.1 Secret & API Key

| Item | Temuan | Status |
|------|--------|--------|
| Midtrans Server Key | **Tidak ditemukan** di `lib/`, `assets/`, atau Android source | ✅ Aman |
| Midtrans Client Key | **Tidak ditemukan** di kode Flutter | ✅ Aman |
| Midtrans Merchant ID | **Tidak ditemukan** di kode Flutter | ✅ Aman |
| JWT Secret | Hanya dibaca dari `env['JWT_SECRET']` di backend | ✅ Aman |
| Google Sheets credentials | Hanya dibaca dari environment di backend | ✅ Aman |
| `.env` | Tidak ada di repository; ada di `.gitignore` | ✅ Aman |

**Mekanisme yang benar:**  
Semua secret Midtrans (Server Key, Client Key, Merchant ID) hanya ada di file `.env` backend yang **tidak di-commit**. File contoh tersedia di `backend/.env.example` dengan nilai kosong.

```
# backend/.env (JANGAN COMMIT)
MIDTRANS_SERVER_KEY=<isi di server produksi>
MIDTRANS_CLIENT_KEY=<isi di server produksi>
MIDTRANS_MERCHANT_ID=<isi di server produksi>
```

### 2.2 PIN & Password

| Item | Temuan | Status |
|------|--------|--------|
| Algoritma hash PIN | PBKDF2-HMAC-SHA256 dengan salt acak 16 byte | ✅ Aman |
| Iterasi PBKDF2 | Dikonfigurasi di `AppConstants.pinHashIterations` | ✅ Aman |
| PIN plaintext di log | Logger menyensor `pin=`, `password=`, `token=`, `key=` | ✅ Aman |
| PIN hardcoded | Tidak ditemukan | ✅ Aman |
| Verifikasi timing-safe | Constant-time XOR comparison (`mismatch \|= a ^ b`) | ✅ Aman |

### 2.3 Logging

| Item | Temuan | Status |
|------|--------|--------|
| `AppLogger._sanitize()` | Meredact `pin/password/secret/token/key` dari semua log | ✅ Aman |
| Backend `_safeLog()` | Meredact `Mid-server-*` dan `SB-Mid-server-*` dari request log | ✅ Aman |
| `debugPrint()` / `print()` | Tidak ditemukan di `lib/` production code | ✅ Aman |
| Log level production | `enableVerboseLog: false` di `EnvConfig.production` | ✅ Aman |

### 2.4 HTTPS & Komunikasi Jaringan

| Item | Temuan | Status |
|------|--------|--------|
| URL API development | `https://api-dev.dapur-rasa.com` | ✅ HTTPS |
| URL API staging | `https://api-staging.dapur-rasa.com` | ✅ HTTPS |
| URL API production | `https://api.dapur-rasa.com` | ✅ HTTPS |
| URL Midtrans Snap | `https://app.sandbox.midtrans.com/snap/...` | ✅ HTTPS |
| HTTP plaintext di `lib/` | **Tidak ditemukan** | ✅ Aman |
| Header Authorization di Flutter | Flutter tidak mengirim Server Key; hanya `Accept` + `Content-Type` | ✅ Aman |

### 2.5 Backend Authorization & Role Permission

| Item | Temuan | Status |
|------|--------|--------|
| Midtrans webhook signature | SHA-512 `orderId + statusCode + grossAmount + serverKey` diverifikasi sebelum diproses | ✅ Aman |
| `SignatureException` → HTTP 403 | Webhook ditolak jika signature tidak cocok | ✅ Aman |
| Role-based access (Flutter) | `PermissionGuard` + `GuardedRepository` pattern untuk semua repo | ✅ Aman |
| Role: Owner | Akses semua `AppPermission` | ✅ Benar |
| Role: Admin | Akses manajemen produk, laporan, expense, tanpa manage-users | ✅ Benar |
| Role: Cashier | Akses kasir, pelanggan, cash session, barcode, printer | ✅ Benar |
| JWT Cloud | Diaktifkan hanya jika `JWT_SECRET` tidak kosong; fallback ke PIN lokal | ✅ Aman |

### 2.6 SQL Injection

| Item | Temuan | Status |
|------|--------|--------|
| Parameterized queries | Semua query SQLite menggunakan `whereArgs`, `values` map | ✅ Aman |
| String interpolasi di SQL | **Tidak ditemukan** (`execute('...'\$variable)`) | ✅ Aman |
| Input validation di backend | `business_id`, `plan_code`, `client_uuid` divalidasi sebelum dipakai | ✅ Aman |

### 2.7 Input Validation

| Item | Temuan | Status |
|------|--------|--------|
| Form PIN | Minimal 4 digit, validasi di UI dan domain | ✅ Ada |
| Form harga/stok | Validasi angka positif di `KdTextField` | ✅ Ada |
| Plan code | `BillingPlan.parse()` melempar `ArgumentError` untuk nilai tidak dikenal | ✅ Ada |
| Webhook payload | Field wajib divalidasi; kosong → `FormatException` → HTTP 400 | ✅ Ada |

### 2.8 Secure Storage

| Item | Temuan | Status |
|------|--------|--------|
| Database SQLite | Disimpan di direktori privat aplikasi (bukan external storage publik) | ✅ Aman |
| Logo toko | Disimpan di `getApplicationDocumentsDirectory()` | ✅ Aman |
| Backup file | Transfer lewat backend yang terautentikasi; bukan write ke SD card | ✅ Aman |
| `.env` backend | Di luar repo; hanya di server/VM produksi | ✅ Aman |

### 2.9 Sensitive Data Exposure

| Item | Temuan | Status |
|------|--------|--------|
| `config.publicHealth` | Tidak memuat Server Key atau credential apapun | ✅ Aman |
| `/v1/audit` endpoint | Hanya events bertipe `action/entity/detail`; tidak ada secret | ✅ Aman |
| Snap token di respons | Dikembalikan ke Flutter tapi tidak disimpan ke log | ✅ Aman |
| `MemoryBillingGateway` | Gateway **tes saja**; tidak dipakai di production build | ✅ Aman |

---

## 3. Arsitektur Keamanan Pembayaran Midtrans

```
Flutter App                  Backend (Shelf)              Midtrans
─────────────────────────    ──────────────────────────   ───────────
1. POST /v1/billing/checkout ──────────────────────────►
                             2. Buat order + sign request
                             3. POST ke Midtrans Snap API ──────────►
                             4. Terima snap_token         ◄──────────
5. Terima snap_token         ◄──────────────────────────
6. Buka Snap URL (browser)
7. Bayar lewat browser                                    ──────────►
                                                          Proses pembayaran
                             8. POST webhook notifikasi   ◄──────────
                             9. Verifikasi SHA-512 signature
                             10. Update subscription
11. GET /v1/billing/subscription ────────────────────────►
12. Terima status aktif      ◄──────────────────────────

Server Key: HANYA di backend.
Flutter TIDAK PERNAH melihat, menyimpan, atau mengirim Server Key.
```

---

## 4. File yang Tidak Boleh di-Commit

File berikut **harus selalu ada di `.gitignore`** dan tidak boleh masuk ke repository:

```
.env
backend/.env
*.log
```

Verifikasi:
```bash
# Pastikan .env tidak masuk repository
git status --short | grep ".env"   # harus kosong
git log --all --full-history -- "**/.env"  # harus kosong
```

---

## 5. Checklist Deployment Production

Sebelum deploy ke production, pastikan:

- [ ] `backend/.env` berisi `MIDTRANS_SERVER_KEY` asli (bukan sandbox)
- [ ] `MIDTRANS_ENVIRONMENT=PRODUCTION` di `backend/.env`
- [ ] `MIDTRANS_CLIENT_KEY` dan `MIDTRANS_MERCHANT_ID` terisi
- [ ] `JWT_SECRET` diisi dengan string acak ≥ 32 karakter
- [ ] `PUBLIC_BASE_URL` diisi URL HTTPS production backend
- [ ] URL notifikasi webhook di dashboard Midtrans = `{PUBLIC_BASE_URL}/v1/billing/midtrans/notification`
- [ ] Flutter di-build dengan `--dart-define=ENV=prod`
- [ ] `enableVerboseLog` = `false` di production (`EnvConfig.production`)
- [ ] `.env` **tidak** di-commit ke Git
- [ ] TLS/HTTPS aktif di server backend

---

## 6. Melaporkan Kerentanan

Jika menemukan kerentanan keamanan, laporkan secara **privat** ke:

**Email:** security@dapur-rasa.com  
**Website:** https://dapur-rasa.com  
**Penanggung jawab:** Mas Rizky Iman · PT Dapur Rasa Karya Nusantara

Jangan buat GitHub issue publik untuk kerentanan keamanan.  
Berikan detail: deskripsi, langkah reproduksi, dan dampak potensial.  
Kami akan merespons dalam 72 jam.

---

## 7. Test Keamanan Otomatis

Project ini memiliki test yang berjalan di CI:

```
test/config/secret_isolation_test.dart       — pastikan lib/ tidak memuat Server Key
backend/test/secret_isolation_test.dart      — pastikan backend tidak mengekspos secret
backend/test/midtrans_signature_test.dart    — verifikasi SHA-512 signature Midtrans
backend/test/webhook_idempotency_test.dart   — webhook tidak memuat Server Key di respons
```

Jalankan sebelum setiap release:

```bash
# Flutter
flutter test test/config/secret_isolation_test.dart

# Backend
cd backend && dart test test/secret_isolation_test.dart
```
