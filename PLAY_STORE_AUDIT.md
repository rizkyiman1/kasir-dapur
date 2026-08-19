# PLAY STORE AUDIT — Kasir Dapur

**Versi Aplikasi:** 1.0.0+1  
**Package ID:** com.kasirdapur.app  
**Tanggal Audit:** 2026-08-19  
**Auditor:** Internal (STEP 27)  
**Target:** Google Play Store Release

---

## RINGKASAN EKSEKUTIF

| Kategori | Status |
|---|---|
| Crash / Navigation | ✅ PASS |
| Login & Auth | ✅ PASS |
| Permissions | ✅ PASS |
| Privacy Policy | ✅ PASS |
| Account Deletion | ✅ PASS |
| Security | ✅ PASS |
| Data Safety | ✅ PASS |
| Placeholder / Fake Content | ⚠️ WARNING |
| Subscription & Payment | 🔴 BLOCKER (3 item) |
| App Access / Navigation | ✅ PASS |
| Branding Consistency | ⚠️ WARNING |
| Misleading Claim | ⚠️ WARNING |
| Excessive Permission | ✅ PASS |

> **KESIMPULAN: BELUM PRODUCTION-READY.** Terdapat 3 BLOCKER yang harus diselesaikan sebelum submit ke Google Play.

---

## DETAIL PER KATEGORI

---

### 1. CRASH & BROKEN NAVIGATION

**Status: ✅ PASS**

| Item | Hasil | Catatan |
|---|---|---|
| GoRouter fallback | PASS | Semua route tidak dikenal di-redirect ke `/dashboard` atau `/splash` |
| Back button dari halaman root | PASS | `SubscriptionPage`, `SettingsPage`, `DashboardPage` semua handle `canPop()` sebelum `context.pop()` |
| Auth redirect loop | PASS | `AuthState` → splash → onboarding / login / lock / main — tidak ada loop |
| Deep link tanpa login | PASS | `PermissionGuard` redirect ke `/lock` jika sesi tidak aktif |
| `mounted` check async | PASS | `cashier_page.dart` memiliki `if (!mounted) return` setelah `await` |

---

### 2. LOGIN & AUTH

**Status: ✅ PASS**

| Item | Hasil | Catatan |
|---|---|---|
| Onboarding PIN setup | PASS | Minimum 4 digit, hashed PBKDF2-HMAC-SHA256 dengan 16-byte random salt |
| Login screen | PASS | PIN-only, tidak ada plaintext password |
| Session lock | PASS | Timer watchdog + manual lock dari settings |
| Role enforcement | PASS | Owner / Admin / Cashier — `PermissionGuard` + `GuardedRepository` di semua layer |
| No default/test credentials | PASS | Tidak ada PIN hardcoded, tidak ada akun test tersisa |
| Biometric | INFO | Tidak diimplementasikan. Bukan blocker Play Store tapi UX limitation |

---

### 3. PERMISSIONS

**Status: ✅ PASS**

| Permission | Justifikasi | Status |
|---|---|---|
| `INTERNET` | Sync Google Sheets, verifikasi subscription via backend | PASS |
| `ACCESS_NETWORK_STATE` | Deteksi offline untuk offline-first mode | PASS |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` (≤ API 30) | Printer thermal Bluetooth Classic | PASS |
| `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` (API 31+) | Printer thermal BT5/LE — `neverForLocation` flag sudah benar | PASS |
| `CAMERA` | Scan barcode produk via `mobile_scanner` | PASS |
| Hardware features | Semua `required="false"` — app berjalan tanpa BT/kamera | PASS |

**Tidak ada permission berlebihan.** Tidak ada `READ_CONTACTS`, `ACCESS_FINE_LOCATION`, `READ_PHONE_STATE`, atau permission sensitif lainnya.

---

### 4. PRIVACY POLICY

**Status: ✅ PASS**

| Item | Hasil | Catatan |
|---|---|---|
| Ada privacy policy | PASS | `PRIVACY_POLICY.md` + in-app via Settings → Privacy Policy |
| Bukan placeholder | PASS | Isi nyata, substantif, Bahasa Indonesia + English summary |
| Identitas controller | PASS | PT Dapur Rasa Karya Nusantara / Mas Rizky Iman |
| Data lokal vs server | PASS | Didokumentasikan dengan jelas |
| PIN handling | PASS | PBKDF2-HMAC-SHA256 dijelaskan eksplisit |
| Midtrans flow | PASS | Disebutkan — data pembayaran diproses Midtrans, tidak disimpan app |
| User rights | PASS | Akses, edit, hapus, backup, export |
| Kontak privasi | ⚠️ WARNING | Website `dapur-rasa.com` disebut, tapi tidak ada **email** kontak eksplisit. Google Play Data Safety form mensyaratkan email. |
| URL live | ⚠️ WARNING | `https://dapur-rasa.com` harus aktif dan dapat diakses saat submission |

---

### 5. ACCOUNT DELETION

**Status: ✅ PASS**

| Item | Hasil | Catatan |
|---|---|---|
| In-app deletion path | PASS | Settings → PRIVACY → Hapus Akun |
| Konfirmasi deletion | PASS | User harus ketik "HAPUS" — mencegah accidental delete |
| Permission check | PASS | Hanya Owner yang bisa hapus akun |
| Efek deletion | PASS | Semua user lokal dihapus, sesi dikosongkan, app kembali ke onboarding |
| Disclosure data residual | PASS | Dijelaskan bahwa data bisnis SQLite tidak terhapus otomatis — user diarahkan ke Android Settings → Clear Data |
| Server deletion SLA | PASS | Didokumentasikan: request ke dapur-rasa.com, 30 hari SLA |

Memenuhi [Play Store account deletion policy](https://support.google.com/googleplay/android-developer/answer/13327111).

---

### 6. SUBSCRIPTION & PAYMENT

**Status: 🔴 BLOCKER**

#### BLOCKER #1 — Harga belum dikonfigurasi

```
// lib/features/subscription/domain/subscription_config.dart
PlanOffer(planCode: BillingPlan.proMonthly, periodDays: 30),         // priceRupiah: null
PlanOffer(planCode: BillingPlan.proYearly, periodDays: 365),         // priceRupiah: null
PlanOffer(planCode: BillingPlan.businessMonthly, periodDays: 30),    // priceRupiah: null
PlanOffer(planCode: BillingPlan.businessYearly, periodDays: 365),    // priceRupiah: null
```

`priceRupiah: null` → UI menampilkan **"Harga: menyusul konfigurasi bisnis"** di layar Subscription.  
**Ini fake content** dan akan menyebabkan penolakan oleh Play Store reviewer.  
**Wajib diisi** sebelum submission. Contoh: `priceRupiah: 79000` untuk Pro Monthly.

#### BLOCKER #2 — Default environment mengarah ke dev API

```
// lib/config/env.dart
static EnvConfig fromDartDefine({
  String env = const String.fromEnvironment('ENV', defaultValue: 'dev'),
}) { ... }
```

Build `flutter build appbundle --release` tanpa `--dart-define=ENV=prod` menggunakan `api-dev.dapur-rasa.com`.  
AAB yang di-upload ke Play Store saat ini **mengarah ke development API**, bukan production.  
**Wajib build dengan:**
```bash
flutter build appbundle --release --dart-define=ENV=prod
```

#### BLOCKER #3 — Google Play Billing Policy

Aplikasi menjual subscription digital (Pro/Business) yang memberikan akses ke fitur **dalam aplikasi Android**, menggunakan Midtrans (external payment processor) — bukan Google Play Billing.

Menurut [Google Play Billing Policy](https://support.google.com/googleplay/android-developer/answer/10281818), aplikasi yang menjual **produk/layanan digital yang digunakan dalam aplikasi Android** harus menggunakan Google Play Billing.

**Pengecualian yang mungkin berlaku:**
- Aplikasi B2B murni (pengguna adalah merchant, bukan konsumen akhir) — Google belum memberikan kejelasan eksplisit untuk kategori ini
- Subscription yang dikelola sepenuhnya di luar app (tidak ada upgrade flow di dalam app) — tidak berlaku di sini karena ada tombol upgrade di Settings

**Opsi resolusi:**
1. **Tambahkan Google Play Billing** sebagai payment method utama untuk pembelian baru dari Play Store (sambil tetap menyupport Midtrans untuk web/renewal)
2. **Konsultasikan dengan Google Play policy team** untuk konfirmasi apakah kategori B2B/UMKM tools memenuhi syarat pengecualian
3. **Publish sebagai "Paid app"** (bukan in-app subscription) — ini bukan solusi ideal tapi menghindari billing policy

| Item | Status |
|---|---|
| Checkout flow (Midtrans Snap) | PASS — payment di browser eksternal |
| Server Key tidak di client | PASS |
| Webhook verification | PASS |
| Harga pro/business | 🔴 BLOCKER — null |
| Default API environment | 🔴 BLOCKER — dev |
| Play Billing compliance | 🔴 BLOCKER — perlu resolusi |

---

### 7. APP ACCESS

**Status: ✅ PASS**

| Item | Hasil | Catatan |
|---|---|---|
| Tidak ada forced login wall untuk core features | PASS | Free plan tidak memblokir navigasi — hanya beberapa fitur Pro/Business |
| Feature lock screen | PASS | `FeatureLockPage` menjelaskan fitur apa yang perlu upgrade, tidak membingungkan |
| Navigasi balik dari feature lock | PASS | Ada tombol kembali |
| Offline mode | PASS | POS tetap bekerja offline. `KdOfflineBanner` memberikan indikasi |

---

### 8. MISLEADING CLAIM

**Status: ⚠️ WARNING**

| Item | Hasil | Catatan |
|---|---|---|
| Tagline "Kasir, Stok & Laporan Usaha" | PASS — akurat | Semua fitur ini tersedia di Free |
| Klaim fitur Free plan | PASS | Offline POS, inventori dasar, laporan harian, barcode — semua real |
| Harga subscription | ⚠️ MISLEADING saat ini | `null` → tampil "Harga: menyusul konfigurasi bisnis" — harus diisi dengan harga nyata |
| "Tak terbatas" untuk Business plan | PASS — dikonfirmasi di `PlanCatalog` | |

---

### 9. PLACEHOLDER & FAKE CONTENT

**Status: ⚠️ WARNING**

| Lokasi | Konten | Status |
|---|---|---|
| `subscription_config.dart` — `priceRupiah` | `null` → tampil "Harga: menyusul konfigurasi bisnis" | 🔴 BLOCKER (lihat #6) |
| `legal_documents.dart` line 82, 156, 386 | Menyebut "Ultra" padahal plan bernama "Business" | ⚠️ WARNING — inkonsistensi label |
| `memory_billing_gateway.dart` — `snap-token-placeholder` | Hanya digunakan di test/fake, tidak di production provider | ✅ PASS |
| Store name default | Kosong (user isi saat onboarding) | PASS — by design |

---

### 10. BRANDING CONSISTENCY

**Status: ⚠️ WARNING**

| Item | Nilai | Status |
|---|---|---|
| App name (manifest) | `Kasir Dapur` | PASS |
| App name (pubspec) | `kasir_dapur` | PASS |
| App name (Brand) | `Kasir Dapur` | PASS |
| Tagline | `Kasir, Stok & Laporan Usaha` | PASS |
| Package ID | `com.kasirdapur.app` | PASS |
| Plan names di `Plan.dart` | `Free`, `Pro`, `Business` | PASS |
| Plan names di `legal_documents.dart` | `Free`, `Pro`, **`Ultra`** (3 tempat) | ⚠️ WARNING — harus diganti ke `Business` |
| Splash screen | `Kasir Dapur` | PASS |
| Onboarding | `Kasir Dapur` + tagline | PASS |

---

### 11. SECURITY

**Status: ✅ PASS**

| Item | Hasil | Catatan |
|---|---|---|
| No hardcoded secrets | PASS | Midtrans Server Key tidak ada di Flutter code |
| HTTPS only | PASS | `network_security_config.xml` — `cleartextTrafficPermitted="false"` |
| No HTTP URLs di production | PASS | Semua URL menggunakan `https://` |
| PIN hashing | PASS | PBKDF2-HMAC-SHA256, random salt, timing-safe compare |
| Log sanitization | PASS | `AppLogger` menyensor `pin`, `password`, `secret`, `token`, `key` |
| Backup exclusion | PASS | `data_extraction_rules.xml` — database & files excluded dari cloud/device backup |
| ProGuard/R8 | PASS | `isMinifyEnabled = true`, `isShrinkResources = true` |
| `allowBackup="false"` | PASS | |

---

### 12. DATA SAFETY (Google Play Form)

**Status: ✅ PASS** (konten sudah siap, perlu diisi di Play Console)

| Data | Dikumpulkan | Dibagikan | Encrypted | Dapat Dihapus |
|---|---|---|---|---|
| PIN (hash) | Ya — lokal | Tidak | Ya (PBKDF2) | Ya (hapus akun) |
| Data transaksi | Ya — lokal | Tidak | Tidak (SQLite lokal) | Ya (Clear Data) |
| Data bisnis (nama toko, produk) | Ya — lokal | Ya (Sync cloud opsional) | Transport HTTPS | Ya |
| Payment order ID | Ya — lokal | Ya (ke backend) | Transport HTTPS | Ya |
| Device ID / UUID | Ya — lokal | Ya (ke backend untuk subscription) | Transport HTTPS | Ya |

**Tidak dikumpulkan:** nama asli, email, nomor telepon, lokasi, kontak, identitas iklan.

---

## DAFTAR ITEM YANG HARUS DIPERBAIKI SEBELUM SUBMIT

### 🔴 BLOCKER — Wajib diselesaikan

| ID | File | Masalah | Solusi |
|---|---|---|---|
| B-01 | `lib/features/subscription/domain/subscription_config.dart` | `priceRupiah: null` untuk semua paket berbayar | Isi harga nyata: `proMonthly`, `proYearly`, `businessMonthly`, `businessYearly` |
| B-02 | `lib/config/env.dart` + build command | Default environment = `dev`, AAB mengarah ke `api-dev.dapur-rasa.com` | Build dengan `--dart-define=ENV=prod` |
| B-03 | Subscription payment flow | Midtrans tidak melalui Google Play Billing | Konsultasi Google Play policy; pertimbangkan Google Play Billing integration atau konfirmasi exemption |

### ⚠️ WARNING — Harus diperbaiki sebelum submit

| ID | File | Masalah | Solusi |
|---|---|---|---|
| W-01 | `lib/features/settings/domain/legal_documents.dart` (line 82, 156, 386) | Label plan "Ultra" tidak konsisten dengan `Plan.business` | Ganti semua "Ultra" dengan "Business" |
| W-02 | `PRIVACY_POLICY.md` + `legal_documents.dart` | Tidak ada email kontak privasi eksplisit | Tambahkan `privacy@dapur-rasa.com` atau email yang sesuai |
| W-03 | Production deployment | URL `https://dapur-rasa.com` harus live saat submission | Pastikan website aktif sebelum submit |

### ℹ️ INFO — Tidak memblokir, tapi direkomendasikan

| ID | Item | Rekomendasi |
|---|---|---|
| I-01 | Tidak ada biometric login | Pertimbangkan `local_auth` untuk UX lebih baik di perangkat modern |
| I-02 | `versionCode = 1` | Pastikan increment setiap update ke Play Store |
| I-03 | `gradle.properties` — `kotlin.incremental=false` | Ini workaround Windows build issue; pertimbangkan upgrade Kotlin di plugin |

---

## CHECKLIST SEBELUM SUBMIT

```
[ ] B-01: Isi priceRupiah di subscription_config.dart
[ ] B-02: Build ulang dengan --dart-define=ENV=prod  
[ ] B-03: Resolusi Google Play Billing policy
[ ] W-01: Ganti "Ultra" → "Business" di legal_documents.dart
[ ] W-02: Tambahkan email kontak privasi di Privacy Policy
[ ] W-03: Pastikan dapur-rasa.com live
[ ] Jalankan: flutter test (186 harus passed)
[ ] Jalankan: flutter analyze --no-fatal-infos (0 errors/warnings)
[ ] Jalankan: flutter build appbundle --release --dart-define=ENV=prod
[ ] Verifikasi signing: jarsigner -verify app-release.aab
[ ] Upload ke Play Console Internal Testing terlebih dahulu
[ ] Isi Data Safety form di Play Console
[ ] Tambahkan Privacy Policy URL di Play Console listing
[ ] Screenshot minimal 2 perangkat
[ ] Isi short description dan full description
```

---

*Dokumen ini dibuat oleh internal audit (STEP 27). Semua temuan berdasarkan analisis source code dan konfigurasi build aktual.*
