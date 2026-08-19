# Data Safety — Kasir Dapur (Google Play)

Dokumen ini mengisi formulir **Data Safety** di Google Play Console untuk `com.kasirdapur.app`.  
Referensi: https://support.google.com/googleplay/android-developer/answer/10787469

---

## Ringkasan

| Pertanyaan | Jawaban |
|------------|---------|
| Apakah aplikasi mengumpulkan atau berbagi data pengguna? | **Ya** — hanya untuk fitur cloud opsional (subscription, backup, sync) |
| Apakah semua transmisi data dienkripsi? | **Ya** — semua koneksi menggunakan HTTPS/TLS |
| Apakah pengguna dapat meminta penghapusan data? | **Ya** — via Settings → PRIVACY → Delete Account |

---

## Bagian 1: Pengumpulan Data

### Data yang Dikumpulkan

Aplikasi **tidak mengumpulkan** data berikut ke server kami:
- Nama lengkap atau informasi identitas pribadi pengguna
- Alamat email
- Nomor telepon pengguna (hanya data telepon toko — disimpan lokal)
- Lokasi presisi maupun kasar
- Kontak perangkat
- Foto atau media dari galeri (logo toko disimpan lokal, tidak diunggah)
- Audio atau video
- Data kesehatan atau aktivitas fisik
- Data keuangan pribadi (nomor kartu, rekening bank)

### Data yang Dikumpulkan (Untuk Fitur Cloud Opsional)

#### Identifikasi Aplikasi & Performa
| Kolom | Dikumpulkan? | Dibagikan? | Dienkripsi? | Penghapusan? | Tujuan |
|-------|-------------|-----------|------------|-------------|--------|
| ID Perangkat / Business ID (UUID) | Ya | Tidak | Ya (HTTPS) | Ya | Layanan akun, verifikasi subscription |

#### Aktivitas Aplikasi
| Kolom | Dikumpulkan? | Dibagikan? | Dienkripsi? | Penghapusan? | Tujuan |
|-------|-------------|-----------|------------|-------------|--------|
| Riwayat pembelian in-app (order_id, paket, jumlah) | Ya | Tidak | Ya (HTTPS) | Ya | Rekonsiliasi pembayaran |

#### Data Bisnis (hanya jika fitur Backup/Sync diaktifkan)
| Kolom | Dikumpulkan? | Dibagikan? | Dienkripsi? | Penghapusan? | Tujuan |
|-------|-------------|-----------|------------|-------------|--------|
| Snapshot data bisnis (transaksi, produk, stok, pengeluaran) | Ya (opsional) | Tidak | Ya (HTTPS) | Ya | Cadangan cloud, pemulihan data |
| Sync jobs (delta perubahan data) | Ya (opsional) | Tidak | Ya (HTTPS) | Ya | Sinkronisasi multi-perangkat |

---

## Bagian 2: Data yang Tidak Dikumpulkan (Disimpan Lokal Saja)

Data berikut **disimpan hanya di perangkat pengguna** (SQLite privat) dan **tidak pernah dikirim** ke server Kasir Dapur tanpa tindakan eksplisit pengguna:

- Transaksi penjualan
- Data produk dan inventori  
- Data pelanggan dan pemasok
- Data pengeluaran dan sesi kas
- Profil toko (nama, alamat, telepon, logo)
- Akun pengguna lokal (hash PIN — bukan PIN asli)
- Pengaturan aplikasi dan preferensi

---

## Bagian 3: Berbagi Data

Kasir Dapur **tidak menjual data pengguna** kepada pihak ketiga.

Data **tidak dibagikan** kepada pihak ketiga kecuali:

| Pihak Ketiga | Data yang Dibagikan | Tujuan | Kebijakan Privasi |
|-------------|--------------------|---------|--------------------|
| **Midtrans** (penyedia pembayaran) | `order_id`, `gross_amount`, metode bayar | Pemrosesan pembayaran subscription | https://midtrans.com/privacy-policy |

Midtrans hanya menerima data yang diperlukan untuk memproses pembayaran. Kasir Dapur tidak memberikan data transaksi kasir, data pelanggan, atau data inventori ke Midtrans.

---

## Bagian 4: Praktik Keamanan

| Praktik | Status |
|---------|--------|
| Enkripsi data dalam transit | ✅ Ya — HTTPS/TLS untuk semua koneksi server |
| Enkripsi data saat disimpan | ✅ Sebagian — PIN di-hash (PBKDF2-HMAC-SHA256); SQLite di direktori privat Android |
| Dapat meminta penghapusan data | ✅ Ya |

---

## Bagian 5: Mekanisme Penghapusan Data

### Penghapusan Akun Pengguna Lokal

**Cara:** Settings → PRIVACY → Delete Account → Ketik "HAPUS" → Konfirmasi

**Efek:**
- Menghapus semua pengguna lokal (Owner, Admin, Kasir) dari perangkat
- Mengakhiri sesi aktif
- Aplikasi kembali ke layar onboarding

**Yang tidak terhapus:** Data transaksi SQLite (tetap di perangkat)

### Penghapusan Semua Data Aplikasi

**Cara:** Pengaturan Android → Aplikasi → Kasir Dapur → Hapus Data

**Efek:** Menghapus seluruh database SQLite, pengaturan, dan file aplikasi secara permanen dari perangkat.

### Penghapusan Data di Server

Untuk menghapus data yang tersimpan di server Kasir Dapur (backup cloud, riwayat subscription):

**Hubungi:** https://dapur-rasa.com  
Kami akan memproses permintaan dalam 30 hari kerja sesuai hak subjek data.

---

## Bagian 6: URL untuk Google Play Console

Saat mengisi Data Safety di Google Play Console, gunakan URL berikut:

| Field | URL |
|-------|-----|
| Privacy Policy URL | https://dapur-rasa.com/privacy |
| Data deletion instructions URL | https://dapur-rasa.com/delete-account |

---

## Bagian 7: Izin Aplikasi Android

| Izin | Kegunaan |
|------|----------|
| `BLUETOOTH` / `BLUETOOTH_CONNECT` / `BLUETOOTH_SCAN` | Menghubungkan printer Bluetooth thermal untuk cetak struk |
| `INTERNET` | Mengakses backend Kasir Dapur untuk verifikasi subscription, backup, dan sync |
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` | Memilih foto logo toko dari galeri |
| `VIBRATE` | Notifikasi visual/haptic opsional |

Izin diminta hanya saat fitur terkait digunakan pertama kali dan dapat dicabut melalui pengaturan Android.
