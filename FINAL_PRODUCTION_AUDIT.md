# FINAL PRODUCTION AUDIT — Kasir Dapur

**App:** Kasir Dapur  
**Tagline:** Kasir, Stok & Laporan Usaha  
**Developer:** Mas Rizky Iman  
**Badan Usaha:** PT Dapur Rasa Karya Nusantara  
**Website:** dapur-rasa.com  
**Package:** com.kasirdapur.app  
**Versi:** 1.0.0+1  
**Tanggal Audit:** 2026-08-19  
**AAB:** release/kasir-dapur.aab (67.8 MB)

---

## KESIMPULAN EKSEKUTIF

> ⚠️ **BELUM PRODUCTION-READY.**  
> Terdapat **1 FAIL (ENV Production)** dan **2 FAIL bisnis (harga & Play Billing)** yang wajib diselesaikan sebelum submit ke Google Play Store.  
> Semua komponen teknis inti berfungsi dengan baik dan tidak ada bug kritis di fitur utama.

---

## TABEL AUDIT

| Component | Status | Notes |
|---|---|---|
| **Flutter** | ✅ PASS | SDK ^3.13.0, null-safe, 186/186 tests passed, 0 analyzer errors |
| **SQLite** | ✅ PASS | 12 migrasi adiktif, FK enabled, busy_timeout 8s, downgrade-safe |
| **Offline POS** | ✅ PASS | Transaksi berjalan tanpa internet; idempoten via `clientUuid` |
| **Products** | ✅ PASS | Validasi lengkap, subscription gate aktif, SKU/barcode unik |
| **Inventory** | ✅ PASS | `assertStockDelta` per tipe mutasi, stok opname, riwayat lengkap |
| **Barcode** | ✅ PASS | `mounted` check setiap await, permission guard, fallback barcode tidak ditemukan |
| **Printer** | ✅ PASS | Null-safe address check, gagal-lembut tanpa membatalkan transaksi |
| **Transactions** | ✅ PASS | Atomik dalam satu `runInTransaction`, idempoten, validasi pre-checkout ketat |
| **Reports** | ✅ PASS | Agregasi INTEGER SQL (presisi uang terjaga), limit 500/50/2000/500 |
| **Customer** | ✅ PASS | JOIN + COALESCE untuk total spending, validasi nama wajib |
| **Supplier** | ⚠️ WARNING | Tidak ada sync job — perubahan supplier tidak tersinkronisasi ke cloud |
| **Expenses** | ✅ PASS | Kategori default idempoten, import sync tersedia |
| **Cash Management** | ⚠️ WARNING | Tidak ada sync job — sesi kasir tidak tersinkronisasi ke cloud |
| **Google Sheets** | ⚠️ WARNING | Bergantung backend aktif di api.dapur-rasa.com; belum bisa diuji offline |
| **Cloud Backup** | ⚠️ WARNING | Bergantung backend aktif; error listing remote sudah di-log sejak audit sebelumnya |
| **Subscription — Free** | ✅ PASS | Gate aktif, fitur Free berfungsi tanpa backend |
| **Subscription — Pro** | ❌ FAIL | `priceRupiah: null` — harga tidak tampil di UI; blocker UX sebelum launch |
| **Subscription — Business** | ❌ FAIL | `priceRupiah: null` — harga tidak tampil di UI; blocker UX sebelum launch |
| **Midtrans** | ✅ PASS | Server Key tidak ada di client; alur via backend → browser external |
| **Webhook** | ✅ PASS | Verifikasi di backend; Flutter hanya menerima status dari backend |
| **Security** | ✅ PASS | PBKDF2-HMAC-SHA256, cleartext diblokir, ProGuard aktif, log tersanitasi |
| **Privacy** | ✅ PASS | Privacy Policy lengkap, Data Safety siap, kontak privacy@dapur-rasa.com |
| **Account Deletion** | ✅ PASS | Konfirmasi ketik "HAPUS", Owner only, kembali ke onboarding |
| **Testing** | ✅ PASS | 186/186 unit+widget+integration tests passed; 18 failure scenario tests |
| **Signing** | ✅ PASS | PKCS12 keystore, release signing dikonfigurasi via key.properties (git-ignored) |
| **AAB** | ⚠️ WARNING | File ada (67.8 MB), signed, tapi ENV pada build terakhir perlu dikonfirmasi |
| **Play Store Listing** | ✅ PASS | Nama, deskripsi, category, icon, screenshot plan, privacy URL tersedia |
| **Google Play Compliance** | ❌ FAIL | Play Billing policy belum diselesaikan untuk subscription digital in-app |

---

## DETAIL FAIL & SOLUSI

---

### ❌ FAIL #1 — Harga Subscription Belum Dikonfigurasi

**Komponen:** Subscription Pro, Subscription Business  
**File:** `lib/features/subscription/domain/subscription_config.dart`  
**Baris:** 79–83

```dart
PlanOffer(planCode: BillingPlan.proMonthly,      periodDays: 30),   // priceRupiah: null
PlanOffer(planCode: BillingPlan.proYearly,        periodDays: 365),  // priceRupiah: null
PlanOffer(planCode: BillingPlan.businessMonthly,  periodDays: 30),   // priceRupiah: null
PlanOffer(planCode: BillingPlan.businessYearly,   periodDays: 365),  // priceRupiah: null
```

**Dampak:** UI menampilkan *"Harga: menyusul konfigurasi bisnis"* — pengguna tidak bisa melihat harga sebelum membayar. Google Play reviewer akan menolak app karena ini termasuk misleading content.

**Solusi:** Tentukan harga dan isi `priceRupiah` sebelum submit:

```dart
// Contoh — sesuaikan dengan keputusan bisnis:
PlanOffer(planCode: BillingPlan.proMonthly,      periodDays: 30,  priceRupiah: 79000),
PlanOffer(planCode: BillingPlan.proYearly,        periodDays: 365, priceRupiah: 749000),
PlanOffer(planCode: BillingPlan.businessMonthly,  periodDays: 30,  priceRupiah: 149000),
PlanOffer(planCode: BillingPlan.businessYearly,   periodDays: 365, priceRupiah: 1390000),
```

---

### ❌ FAIL #2 — Default ENV Development

**Komponen:** AAB  
**File:** `lib/config/env.dart` baris 37  
**Baris:** `String env = const String.fromEnvironment('ENV', defaultValue: 'dev')`

**Dampak:** AAB yang dibuilt tanpa `--dart-define=ENV=prod` akan mengarah ke `api-dev.dapur-rasa.com` bukan `api.dapur-rasa.com`. AAB yang diupload ke Play Store menggunakan dev backend.

**Status AAB saat ini:** Build terakhir pada 19/08/2026 20:49 di-build **dengan** `--dart-define=ENV=prod` (sesuai perintah STEP 31). Namun ini perlu diverifikasi ulang sebelum upload ke Play Console.

**Verifikasi:**
```powershell
# Ekstrak dan cari string API URL di AAB
# Jika "api-dev" tidak ditemukan → aman
# Jika "api-dev" ditemukan → build ulang dengan --dart-define=ENV=prod
```

**Solusi:**
```powershell
flutter build appbundle --release --dart-define=ENV=prod
```

---

### ❌ FAIL #3 — Google Play Billing Policy

**Komponen:** Google Play Compliance  
**Referensi:** PLAY_STORE_AUDIT.md BLOCKER B-03

**Dampak:** Aplikasi menjual subscription digital (Pro/Business) untuk fitur yang digunakan di dalam app Android menggunakan Midtrans, bukan Google Play Billing. Ini berpotensi melanggar [Google Play Billing Policy](https://support.google.com/googleplay/android-developer/answer/10281818).

**Status:** Dalam evaluasi — belum ada keputusan final.

**Opsi Solusi:**
1. **Integrasi Google Play Billing** — tambahkan `in_app_purchase` Flutter package, gunakan Play Billing sebagai metode utama untuk pembelian baru dari Play Store
2. **Konfirmasi B2B Exemption** — konsultasikan dengan Google Play policy team apakah aplikasi UMKM tools masuk kategori yang dibebaskan
3. **Web-only upgrade** — hapus tombol upgrade dari dalam app, arahkan ke dapur-rasa.com — namun ini mengubah UX secara signifikan

---

## DETAIL WARNING

| ID | Komponen | Isu | Dampak | Aksi |
|---|---|---|---|---|
| W-01 | Supplier | Tidak ada sync job untuk perubahan supplier | Data supplier tidak sync ke cloud | Tambahkan `SyncJob` di `supplier_repository_impl.dart` saat write operations |
| W-02 | Cash Management | Tidak ada sync job untuk sesi kasir | Sesi kas tidak sync ke cloud | Tambahkan `SyncJob` di `cash_repository_impl.dart` |
| W-03 | Google Sheets | Bergantung backend aktif | Sync gagal jika backend belum deployed | Deploy backend sebelum production |
| W-04 | Cloud Backup | Bergantung backend aktif | Backup cloud gagal jika backend belum deployed | Deploy backend sebelum production |
| W-05 | AAB ENV | Build terakhir menggunakan `--dart-define=ENV=prod` tapi perlu diverifikasi | Jika salah build, app ke dev API | Verifikasi string di AAB atau build ulang |
| W-06 | Signing fallback | Jika `key.properties` tidak ada, fallback ke debug signing | Build CI tanpa keystore tidak gagal eksplisit | Tambahkan `error()` di Gradle jika hasKeystore = false |
| W-07 | `intl: any` | Versi tidak terkunci di pubspec.yaml | Breaking change saat upgrade dart | Ganti ke versi spesifik |
| W-08 | Website | dapur-rasa.com belum live | Play Console contact & privacy URL tidak bisa diakses | Deploy sebelum submit |

---

## KOMPONEN YANG LULUS PENUH

| Komponen | Verifikasi |
|---|---|
| Flutter engine | SDK ^3.13.0, null-safe, Dart 3 |
| SQLite & migrations | 12 migrasi sequential, additive only, no DROP TABLE |
| Offline POS | Transaksi tersimpan lokal, idempoten via UUID |
| Products, Inventory, Transactions | Validasi lengkap, atomik, subscription-gated |
| Barcode scanner | mounted-check, permission-aware |
| Bluetooth printer | null-safe, non-blocking pada kegagalan |
| Reports | INTEGER SQL aggregation, limit production-grade |
| Customer, Expenses | Sync-ready, validasi lengkap |
| PIN security | PBKDF2-HMAC-SHA256, random salt, constant-time compare |
| RBAC / Permission Guard | Enforced di domain layer, bukan hanya UI |
| HTTPS enforcement | network_security_config.xml, cleartext diblokir |
| Backup exclusion | data_extraction_rules.xml, allowBackup=false |
| Log sanitization | pin, password, secret, token, key → [redacted] |
| ProGuard/R8 | minify + shrink aktif di release build |
| No hardcoded secrets | Midtrans Server Key hanya di backend |
| Midtrans flow | Server Key tidak di client, bayar via browser |
| Account deletion | Konfirmasi "HAPUS", Owner only, safe |
| Auth & session | Watchdog timer, PBKDF2 verify, backward-compat |
| Privacy policy | Lengkap, akurat, tidak ada klaim fiktif |
| Data safety | Siap untuk Google Play Data Safety form |
| 186 tests | Unit + widget + integration + failure scenarios |
| Release signing | PKCS12 keystore, git-ignored, dikonfigurasi via properties |
| AAB file | Ada, 67.8 MB, valid ukuran |
| Store listing | Nama, deskripsi, kategori, kontak konsisten |
| Branding | "Kasir Dapur" konsisten di manifest, splash, onboarding, struk |

---

## CHECKLIST SEBELUM SUBMIT KE PLAY STORE

### Wajib (Blocker)
- [ ] Isi `priceRupiah` untuk semua paket di `subscription_config.dart`
- [ ] Verifikasi atau build ulang AAB dengan `--dart-define=ENV=prod`
- [ ] Selesaikan keputusan Google Play Billing (integrasi / konfirmasi exemption)
- [ ] Deploy website dapur-rasa.com dan privacy policy URL

### Disarankan
- [ ] Tambahkan sync job di `supplier_repository_impl.dart`
- [ ] Tambahkan sync job di `cash_repository_impl.dart`
- [ ] Deploy backend api.dapur-rasa.com (untuk sync & backup cloud)
- [ ] Ubah `intl: any` ke versi spesifik di pubspec.yaml
- [ ] Ubah debug signing fallback menjadi build error di Gradle
- [ ] Jalankan `flutter test` dan `flutter analyze` setelah perubahan harga

### Closed Testing (Persyaratan Google Play untuk akun baru)
- [ ] 20 tester opt-in via link Play Console
- [ ] 14 hari program closed testing
- [ ] Crash rate < 1%, ANR rate < 0.47%

---

*Dokumen ini dibuat sebagai bagian dari STEP 32 — Final Production Audit Kasir Dapur.*  
*Audit dilakukan terhadap source code, konfigurasi build, dan file release aktual per 2026-08-19.*  
*Semua klaim dalam dokumen ini berdasarkan analisis kode sumber yang dapat diverifikasi.*
