# Panduan Upload Google Play Console — Kasir Dapur

**App:** Kasir Dapur  
**Package:** com.kasirdapur.app  
**Developer:** Mas Rizky Iman  
**Badan Usaha:** PT Dapur Rasa Karya Nusantara  
**Website:** https://dapur-rasa.com  
**Versi:** 1.0.0+1  
**Tanggal:** 2026-08-19

> Panduan ini mencatat setiap langkah di Google Play Console secara berurutan.  
> Semua data yang diisi harus konsisten dengan dokumen ini dan source code.  
> Jangan mengisi data yang belum tersedia atau belum dapat diverifikasi.

---

## PRA-SYARAT SEBELUM MULAI

Pastikan semua item berikut sudah siap sebelum membuka Play Console:

| Item | Status | Catatan |
|---|---|---|
| Akun Google Play Developer aktif | ⬜ | Biaya registrasi USD 25, sekali bayar |
| AAB release sudah di-build dengan `--dart-define=ENV=prod` | ⬜ | Lihat `SIGNING.md` |
| Keystore upload sudah tersimpan aman | ⬜ | Lihat `SIGNING.md` |
| App icon 512×512 PNG sudah diekspor | ⬜ | Dari `tool/gen_icon.dart` |
| Feature graphic 1024×500 JPG sudah dibuat | ⬜ | Lihat `PLAY_STORE_METADATA.md` |
| Screenshot phone (min. 2, disarankan 6–8) sudah diambil | ⬜ | Lihat `PLAY_STORE_METADATA.md` |
| Privacy Policy URL aktif dan dapat diakses | ⬜ | https://dapur-rasa.com/privacy |
| Support email aktif | ⬜ | support@dapur-rasa.com |
| Harga paket Pro & Business sudah ditentukan | ⬜ | BLOCKER B-01 — wajib sebelum produksi |
| BLOCKER B-03 (Play Billing) sudah diselesaikan | ⬜ | Lihat `PLAY_STORE_AUDIT.md` |
| 20 tester closed testing sudah selesai (14 hari) | ⬜ | Syarat production access akun baru |

---

## LANGKAH 1 — CREATE APP

**Lokasi di Play Console:** Play Console → All apps → Create app

### Isian

| Field | Nilai |
|---|---|
| **App name** | `Kasir Dapur` |
| **Default language** | `Indonesian — id` |
| **App or game** | `App` |
| **Free or paid** | `Free` |

### Deklarasi (centang semua yang berlaku)

- [x] Developer Program Policies
- [x] US export laws
- [x] Kasir Dapur tidak dirancang untuk anak-anak

Klik **Create app**.

---

## LANGKAH 2 — APP DETAILS

**Lokasi:** Dashboard → Setup → App details

### Isian

| Field | Nilai |
|---|---|
| **App name** | `Kasir Dapur` |
| **Short description** | `Aplikasi kasir, stok, dan laporan usaha untuk toko dan UMKM. Bisa offline.` |
| **Full description** | Lihat Bagian 3 di `PLAY_STORE_METADATA.md` |
| **App icon** | Upload file PNG 512×512 px |
| **Feature graphic** | Upload file JPG/PNG 1024×500 px |
| **Phone screenshots** | Upload minimal 2 screenshot (disarankan 6–8) |

> Semua teks ditulis dalam Bahasa Indonesia karena default language adalah `id`.  
> Teks Inggris dapat ditambahkan sebagai terjemahan opsional di tab "Manage translations".

---

## LANGKAH 3 — STORE LISTING

**Lokasi:** Grow → Store presence → Main store listing

Isian sama dengan Langkah 2. Verifikasi setiap field:

| Field | Nilai | Cek |
|---|---|---|
| App name | `Kasir Dapur` | ⬜ |
| Short description | ≤80 karakter, sudah diisi | ⬜ |
| Full description | ≤4.000 karakter, sudah diisi | ⬜ |
| App icon | 512×512 PNG, sudah diupload | ⬜ |
| Feature graphic | 1024×500 JPG/PNG, sudah diupload | ⬜ |
| Phone screenshots | Min. 2, sudah diupload | ⬜ |
| Category | `Business` | ⬜ |
| Tags | Opsional — `kasir`, `pos`, `stok`, `umkm`, `laporan` | ⬜ |
| Contact details — email | `support@dapur-rasa.com` | ⬜ |
| Contact details — website | `https://dapur-rasa.com` | ⬜ |
| Contact details — phone | Opsional (kosongkan jika belum ada nomor bisnis) | ⬜ |

---

## LANGKAH 4 — APP CONTENT

**Lokasi:** Policy → App content

Bagian ini terdiri dari beberapa sub-section. Selesaikan semua sebelum lanjut.

---

## LANGKAH 5 — PRIVACY POLICY

**Lokasi:** Policy → App content → Privacy policy

| Field | Nilai |
|---|---|
| **Privacy policy URL** | `https://dapur-rasa.com/privacy` |

> URL harus aktif, dapat diakses publik tanpa login, dan memuat kebijakan privasi dalam Bahasa Indonesia.  
> Konten lengkap ada di `PRIVACY_POLICY.md` — deploy ke URL tersebut sebelum submit.

---

## LANGKAH 6 — DATA SAFETY

**Lokasi:** Policy → App content → Data safety

Isi formulir berdasarkan `DATA_SAFETY.md`. Ringkasan pengisian:

### 6.1 Data Collection & Sharing

**Does your app collect or share any of the required user data types?**  
→ **Yes**

**Is all of the user data collected by your app encrypted in transit?**  
→ **Yes**

**Do you provide a way for users to request that their data is deleted?**  
→ **Yes** (melalui Pengaturan → Privacy → Hapus Akun)

---

### 6.2 Data Types yang Dikumpulkan

| Data Type | Collected | Shared | Purpose |
|---|---|---|---|
| **Personal info — Name** | No | No | — |
| **Personal info — Email** | No | No | — |
| **Personal info — Phone number** | No | No | — |
| **Financial info — Purchase history** | Yes (lokal) | No | App functionality |
| **App activity — App interactions** | No | No | — |
| **Device or other IDs** | Yes | Yes (ke backend) | Analytics, fraud prevention |

> Catatan: "Device ID" yang dimaksud adalah UUID yang di-generate oleh app untuk keperluan subscription, bukan IMEI atau advertising ID.

### 6.3 Data yang Tidak Dikumpulkan

Deklarasikan **Not collected** untuk semua item berikut:
- Location (precise atau approximate)
- Contacts
- Photos and videos
- Audio files
- Calendar events
- Web browsing history
- Installed apps

---

## LANGKAH 7 — CONTENT RATING

**Lokasi:** Policy → App content → Content rating

Ikuti kuesioner IARC (International Age Rating Coalition):

| Pertanyaan | Jawaban |
|---|---|
| Category | **Utility / Productivity** |
| Violence | No |
| Sexual content | No |
| Profanity | No |
| Controlled substances | No |
| User interaction (chat, UGC) | No |
| Location sharing | No |
| Digital purchases | Yes — in-app subscription |

**Hasil rating yang diharapkan:** Everyone (semua usia) di semua wilayah.

Klik **Submit questionnaire** setelah selesai.

---

## LANGKAH 8 — TARGET AUDIENCE

**Lokasi:** Policy → App content → Target audience and content

| Field | Jawaban |
|---|---|
| **Target age group** | `18 and over` |
| **Does the app appeal to children?** | No |

> Pilih 18+ karena app ditujukan untuk pemilik usaha dan kasir dewasa.  
> Memilih usia yang mencakup anak-anak akan memicu review tambahan yang tidak perlu.

---

## LANGKAH 9 — ADS DECLARATION

**Lokasi:** Policy → App content → Ads

| Field | Jawaban |
|---|---|
| **Does your app contain ads?** | **No** |

Kasir Dapur tidak mengandung iklan dari pihak ketiga (Google AdMob, Meta Audience Network, dll.).

---

## LANGKAH 10 — APP ACCESS

**Lokasi:** Policy → App content → App access

Google memerlukan instruksi untuk reviewer agar bisa mengakses app.

| Field | Nilai |
|---|---|
| **All or some functionality is restricted** | Yes — login dengan PIN diperlukan |

### Instruksi untuk Reviewer

```
Kasir Dapur menggunakan PIN lokal untuk login. Tidak ada akun cloud yang diperlukan.

Cara membuat akun baru:
1. Buka app
2. Layar onboarding tampil — masukkan nama toko (contoh: "Toko Demo")
3. Buat PIN 4 digit (contoh: 1234)
4. Konfirmasi PIN
5. App akan masuk ke dashboard secara otomatis

Untuk login setelah keluar:
1. Buka app
2. Masukkan PIN yang dibuat saat onboarding

Akun demo tidak diperlukan — reviewer membuat akun baru langsung di app.
```

---

## LANGKAH 11 — TESTING (CLOSED TESTING)

**Lokasi:** Testing → Closed testing

### 11.1 Buat Release Pertama di Closed Track

1. Klik **Create new release**
2. Upload file `build/app/outputs/bundle/release/app-release.aab`
3. Isi **Release name**: `1.0.0-closed-testing-1`
4. Isi **Release notes** (What's new):

```
Rilis pertama untuk closed testing.

Fitur yang tersedia:
- Kasir (POS) offline
- Inventori dan stok produk
- Laporan penjualan harian
- Scan barcode
- Cetak struk ke printer Bluetooth
- Multi kasir dengan PIN
- Cadangan data lokal

Catatan: Fitur subscription dan sinkronisasi cloud masih dalam pengembangan.
```

5. Klik **Save** → **Review release**
6. Selesaikan semua checklist yang diminta Play Console
7. Klik **Start rollout to closed testing**

### 11.2 Tambahkan Tester

1. Klik **Manage testers**
2. **Create email list** → beri nama: `Tester Kasir Dapur v1`
3. Tambahkan minimal 20 alamat Gmail tester
4. Salin **opt-in URL** → bagikan ke tester
5. Pantau **Active installs** di tab Testers — tunggu hingga ≥20

### 11.3 Monitor Selama 14 Hari

Pantau setiap hari di Play Console:

| Metrik | Target | Lokasi |
|---|---|---|
| Active installs | ≥ 20 | Testing → Closed testing → Testers |
| Crash rate | < 1% | Android vitals → Crash rate |
| ANR rate | < 0.47% | Android vitals → ANR rate |
| Feedback | Kumpulkan via formulir | Di luar Play Console |

---

## LANGKAH 12 — UPLOAD AAB

> AAB untuk production berbeda dari AAB testing — pastikan di-build dengan environment yang benar.

### Build Production AAB

```powershell
# Di direktori proyek
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=ENV=prod
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### Verifikasi Sebelum Upload

```powershell
# Cek ukuran file
Get-Item "build\app\outputs\bundle\release\app-release.aab" | Select-Object Name, Length

# Cek dengan bundletool (opsional)
# java -jar bundletool.jar validate --bundle=app-release.aab
```

Pastikan:
- File ada dan tidak berukuran 0 byte
- versionCode sesuai (increment dari versi sebelumnya)
- versionName = `1.0.0`
- applicationId = `com.kasirdapur.app`

### Upload ke Production Track

1. Buka **Production** → **Create new release**
2. Upload AAB production
3. Isi Release name: `1.0.0`
4. Isi Release notes:

```
Rilis pertama Kasir Dapur.

Kasir Dapur adalah aplikasi kasir dan manajemen usaha untuk toko retail, 
warung, dan UMKM Indonesia.

Fitur utama:
- Kasir offline — transaksi tetap berjalan tanpa internet
- Manajemen stok dan inventori
- Laporan penjualan harian dan mingguan
- Scan barcode produk
- Cetak struk ke printer Bluetooth thermal
- Multi kasir dengan izin berbeda
- Ekspor laporan ke CSV/Excel (Pro)
- Cadangan data cloud (Pro/Business)
```

---

## LANGKAH 13 — REVIEW

Sebelum submit, Play Console akan menampilkan daftar item yang perlu dicek.

### Checklist Review Play Console

| Section | Status |
|---|---|
| App details | ⬜ Lengkap |
| Store listing | ⬜ Lengkap |
| Privacy policy | ⬜ URL aktif |
| Data safety | ⬜ Diisi |
| Content rating | ⬜ Submit IARC |
| Target audience | ⬜ 18+ |
| Ads | ⬜ No ads |
| App access | ⬜ Instruksi reviewer diisi |
| Closed testing | ⬜ 14 hari, 20 tester |

### Potensi Penolakan dan Cara Mencegahnya

| Risiko | Pencegahan |
|---|---|
| Privacy policy URL tidak aktif | Deploy ke dapur-rasa.com/privacy sebelum submit |
| Subscription tanpa Play Billing | Selesaikan BLOCKER B-03 sebelum submit |
| Harga subscription belum diisi | Selesaikan BLOCKER B-01 sebelum submit |
| Screenshot tidak memenuhi syarat | Pastikan ukuran minimal 320×568 px, bukan PNG transparan |
| AAB menggunakan debug signing | Build ulang dengan keystore upload |
| AAB mengarah ke dev API | Build dengan `--dart-define=ENV=prod` |
| Instruksi reviewer tidak jelas | Ikuti template di Langkah 10 |

---

## LANGKAH 14 — PRODUCTION ACCESS

Untuk akun developer baru, setelah closed testing 14 hari dengan 20 tester aktif:

1. Buka **Production** → **Release dashboard**
2. Tombol **Apply for production access** akan muncul jika syarat terpenuhi
3. Klik tombol tersebut
4. Isi formulir ringkas tentang app dan tujuannya
5. Google akan mereview dalam 2–7 hari kerja
6. Notifikasi dikirim ke email developer

### Jika Production Access Ditolak

- Baca email penolakan dengan seksama
- Perbaiki alasan yang disebutkan
- Ajukan kembali (tidak ada batas pengajuan)
- Bergabung ke [Google Play Developer Forum](https://support.google.com/googleplay/android-developer/community) jika butuh klarifikasi

---

## LANGKAH 15 — PRODUCTION RELEASE

Setelah production access diberikan:

1. Buka **Production** → review release yang sudah diupload
2. Klik **Review release**
3. Jika tidak ada error, klik **Start rollout to production**
4. Pilih persentase rollout:
   - **Disarankan untuk rilis pertama:** mulai dengan **10–20%** pengguna
   - Pantau crash rate dan ANR selama 24–48 jam
   - Jika stabil, naikkan ke **50%** lalu **100%**
5. Klik **Confirm rollout**

### Setelah Live di Play Store

| Tugas | Kapan |
|---|---|
| Pantau crash rate di Android Vitals | Hari pertama — setiap jam |
| Baca ulasan pertama dari pengguna | Hari 1–7 |
| Siapkan hotfix jika ada crash kritis | Siapkan sebelum rollout |
| Increment versionCode untuk update berikutnya | Setiap rilis baru |
| Perbarui Data Safety jika ada perubahan pengumpulan data | Setiap ada fitur baru |

---

## RINGKASAN URUTAN LANGKAH

```
[1] Create app di Play Console
    ↓
[2–3] Isi App details & Store listing
    ↓
[4] App content (sub-section 5–10)
    ├── [5] Privacy policy URL
    ├── [6] Data safety form
    ├── [7] Content rating (IARC)
    ├── [8] Target audience (18+)
    ├── [9] Ads (No)
    └── [10] App access (instruksi reviewer)
    ↓
[11] Upload AAB ke Closed testing track
    → Tambah 20 tester
    → Tunggu 14 hari
    ↓
[12] Build production AAB (--dart-define=ENV=prod)
    → Upload ke Production track
    ↓
[13] Review semua section — perbaiki yang merah
    ↓
[14] Apply for production access
    → Tunggu persetujuan Google (2–7 hari kerja)
    ↓
[15] Start rollout to production (mulai 10–20%)
    → Monitor → naikkan ke 100%
```

---

## CATATAN PENTING

1. **Jangan submit ke production sebelum BLOCKER B-01, B-02, dan B-03 di `PLAY_STORE_AUDIT.md` diselesaikan.**
2. **Jangan gunakan AAB yang sama untuk closed testing dan production** — build ulang dengan `--dart-define=ENV=prod`.
3. **versionCode harus selalu di-increment** — tidak bisa upload AAB dengan versionCode yang sama dua kali.
4. **Keystore hilang = tidak bisa update app** — backup keystore ke lokasi aman yang terpisah dari repository.
5. **Play Console email = akun Google yang mendaftar** — pastikan email developer terdaftar yang aktif dan aman.

---

*Dokumen ini dibuat untuk keperluan upload Kasir Dapur ke Google Play Store (STEP 30).*  
*Data dalam dokumen ini mencerminkan kondisi aktual proyek per 2026-08-19.*
