# Kebijakan Privasi — Kasir Dapur

**Versi:** 1.0  
**Berlaku mulai:** 2026-08-19  
**Pengendali data:** PT Dapur Rasa Karya Nusantara  
**Pengembang:** Mas Rizky Iman  
**Situs:** https://dapur-rasa.com  
**Package:** com.kasirdapur.app

---

## Bahasa Indonesia

### 1. Pendahuluan

Kasir Dapur adalah aplikasi kasir, manajemen stok, dan laporan keuangan untuk usaha kecil menengah. Aplikasi ini beroperasi secara **offline-first**: seluruh data transaksi disimpan di SQLite pada perangkat Anda. Kebijakan ini menjelaskan secara jujur data apa yang diproses, di mana disimpan, dan untuk tujuan apa.

### 2. Data yang Disimpan Lokal di Perangkat

Data berikut **hanya disimpan di perangkat Anda** dalam database SQLite privat aplikasi dan tidak pernah dikirim ke server tanpa tindakan eksplisit dari Anda:

| Data | Tujuan |
|------|--------|
| Data transaksi penjualan (tanggal, item, harga, total) | Operasional kasir |
| Data produk dan stok (nama, harga, kategori, jumlah stok) | Manajemen inventori |
| Data pelanggan (nama, telepon, riwayat pembelian) | Program loyalitas opsional |
| Data pemasok (nama, telepon, riwayat pembelian) | Manajemen pembelian |
| Data pengeluaran (kategori, jumlah, keterangan) | Laporan keuangan |
| Sesi kas (saldo awal, pemasukan, pengeluaran, saldo akhir) | Manajemen kas |
| Profil toko (nama toko, alamat, telepon, footer struk, logo) | Tampilan struk |
| Pengguna lokal (nama, peran: Owner/Admin/Kasir) | Akses berbasis peran |
| Hash PIN pengguna (PBKDF2-HMAC-SHA256 + salt, bukan PIN asli) | Autentikasi lokal |
| Pengaturan aplikasi (tema, stok negatif, metode bayar default) | Preferensi pengguna |
| Profil printer Bluetooth (nama, alamat MAC) | Cetak struk |

**Catatan penting:** PIN Anda tidak pernah disimpan dalam bentuk asli. Hanya hash kriptografis yang disimpan.

### 3. Data yang Dikirim ke Server Kasir Dapur

Data berikut dikirim ke server backend Kasir Dapur **hanya saat Anda menggunakan fitur berlangganan atau cadangan cloud**:

| Data | Kapan Dikirim | Tujuan |
|------|---------------|--------|
| `business_id` (UUID perangkat) | Checkout, verifikasi langganan | Identifikasi bisnis tanpa nama pribadi |
| `client_uuid` (UUID sesi) | Cadangan cloud | Idempoten deduplikasi cadangan |
| `plan_code` (kode paket: free/pro/ultra) | Checkout | Penentuan harga |
| Snapshot data bisnis (tabel SQLite) | Fitur Backup cloud (jika diaktifkan) | Cadangan data |
| Sync jobs (perubahan data) | Fitur Sync (jika diaktifkan) | Sinkronisasi multi-perangkat |

**Data yang TIDAK dikirim ke server kami:**
- PIN atau hash PIN
- Data kartu kredit/debit
- Kata sandi
- Informasi identitas pribadi pengguna (nama, email, KTP)

### 4. Data yang Digunakan untuk Pembayaran (Midtrans)

Kasir Dapur menggunakan **Midtrans** sebagai penyedia pembayaran untuk langganan. Proses pembayaran:

1. Aplikasi meminta backend Kasir Dapur membuat sesi Snap Midtrans
2. Backend membuat transaksi di Midtrans menggunakan `business_id` dan `plan_code`
3. Aplikasi menerima **Snap Token** (token sementara) dari backend
4. Pembayaran dilakukan di halaman web Midtrans (browser) — bukan di dalam aplikasi
5. Midtrans mengirim notifikasi webhook ke backend Kasir Dapur
6. Backend memverifikasi tanda tangan webhook dan mengaktifkan langganan

**Data yang diproses Midtrans:**
- `order_id` (ID transaksi unik)
- `gross_amount` (jumlah pembayaran dalam Rupiah)
- Metode pembayaran yang Anda pilih (diproses langsung oleh Midtrans)

**Kasir Dapur tidak melihat atau menyimpan detail kartu, rekening bank, atau kredensial pembayaran Anda.** Data pembayaran diproses langsung antara Anda dan Midtrans. Kebijakan privasi Midtrans berlaku untuk data yang Anda masukkan di halaman Midtrans: https://midtrans.com/privacy-policy

**Server Key Midtrans tidak pernah ada di aplikasi Flutter.** Hanya di server backend Kasir Dapur.

### 5. Data yang Digunakan untuk Sinkronisasi

Jika Anda mengaktifkan fitur **Sync ke Google Sheets** (tersedia di paket Pro/Ultra):

- Data laporan (transaksi, stok, pengeluaran) dikirim ke server Kasir Dapur
- Server meneruskan ke Google Spreadsheet **yang Anda pilih dan otorisasi**
- Kasir Dapur tidak mengakses Spreadsheet Google Anda di luar data yang Anda otorisasi

### 6. Data yang Digunakan untuk Langganan

| Data | Disimpan di | Tujuan |
|------|-------------|--------|
| `business_id` | Server Kasir Dapur | Menghubungkan langganan ke bisnis |
| Status langganan (aktif/gratis/kadaluarsa) | Perangkat + server | Penentuan akses fitur |
| Tanggal mulai, tanggal berakhir langganan | Server Kasir Dapur | Manajemen masa berlaku |
| Riwayat pembayaran (order_id, jumlah, status) | Server Kasir Dapur | Konfirmasi transaksi |
| Snap Token | Sementara di memori | Buka halaman Midtrans; tidak disimpan permanen |

### 7. Hak Anda

Anda berhak:

- **Mengakses data Anda:** Semua data transaksi dan pengaturan dapat dilihat langsung di aplikasi
- **Mengubah data:** Data toko, profil pengguna, dan pengaturan dapat diubah di menu Pengaturan
- **Menghapus akun perangkat:** Pengaturan → PRIVACY → Delete Account — menghapus semua pengguna lokal (Owner, Admin, Kasir) dan sesi di perangkat ini
- **Menghapus semua data:** Pengaturan Sistem Android → Aplikasi → Kasir Dapur → Hapus Data — menghapus database SQLite secara permanen
- **Mengekspor data:** Fitur Backup di Pengaturan → BACKUP

**Catatan penghapusan akun:** "Delete Account" di aplikasi menghapus pengguna lokal dan sesi, tetapi tabel database SQLite tidak di-DROP. Data transaksi tetap ada di perangkat sampai Anda menghapus data aplikasi dari pengaturan Android.

### 8. Penyimpanan dan Keamanan

- Database SQLite disimpan di direktori privat aplikasi Android (`/data/data/com.kasirdapur.app/`), tidak dapat diakses oleh aplikasi lain tanpa root
- PIN tidak disimpan dalam bentuk asli; hanya hash PBKDF2-HMAC-SHA256 dengan salt acak 16-byte
- Semua komunikasi ke server menggunakan HTTPS/TLS
- Log aplikasi tidak mencatat PIN, token, atau secret
- Backup cloud disimpan di server Kasir Dapur yang berlokasi di Indonesia

### 9. Data Anak-Anak

Kasir Dapur adalah aplikasi bisnis untuk orang dewasa. Kami tidak secara sadar mengumpulkan data dari anak-anak di bawah 13 tahun.

### 10. Perubahan Kebijakan

Perubahan material pada kebijakan ini akan diumumkan di https://dapur-rasa.com dan melalui pembaruan aplikasi. Versi terbaru selalu tersedia di situs web dan di Pengaturan → PRIVACY → Privacy Policy.

### 11. Kontak

Pertanyaan atau permintaan terkait privasi:

**PT Dapur Rasa Karya Nusantara**  
Pengembang: Mas Rizky Iman  
Situs: https://dapur-rasa.com  
Email: privacy@dapur-rasa.com

---

## English Summary

**Kasir Dapur** is an offline-first Android cashier application. Here is a concise English summary of our data practices:

**Data stored locally only (never sent without your action):**
Transaction records, product inventory, customers, suppliers, expenses, cash sessions, store profile, local user accounts (hashed PINs only — never plaintext), printer profiles, and app settings.

**Data sent to Kasir Dapur servers (only when you use cloud features):**
A device UUID (`business_id`), subscription plan code, and — only if you enable cloud backup or sync — a snapshot of your business data. No personal identity information, no PINs, no payment credentials.

**Payment data (Midtrans):**
Subscription payments are processed by Midtrans. Kasir Dapur never sees your card or bank account details. The Midtrans Server Key lives only on our backend server, never in the Flutter app.

**Your rights:**
- View all your data directly in the app
- Edit store profile, users, and settings
- Delete local accounts: Settings → PRIVACY → Delete Account
- Delete all app data: Android Settings → Apps → Kasir Dapur → Clear Data
- Export data: Settings → BACKUP

**Contact:** privacy@dapur-rasa.com · https://dapur-rasa.com  
**Controller:** PT Dapur Rasa Karya Nusantara · Mas Rizky Iman
