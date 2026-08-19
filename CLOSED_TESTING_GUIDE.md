# Panduan Closed Testing — Kasir Dapur

**Versi App:** 1.0.0+1  
**Package ID:** com.kasirdapur.app  
**Program:** Google Play Closed Testing (Internal / Closed Track)  
**Tanggal:** 2026-08-19  
**Kontak Pengelola:** support@dapur-rasa.com

---

## BAGIAN 1 — PERSYARATAN GOOGLE PLAY (AKUN DEVELOPER BARU)

### Mengapa Closed Testing Penting untuk Akun Baru

Mulai 2023, Google Play mewajibkan akun developer **personal baru** untuk menyelesaikan periode **closed testing selama minimal 14 hari** dengan **minimal 20 tester aktif** sebelum dapat mengajukan akses ke production track.

Persyaratan lengkap:

| Syarat | Ketentuan |
|---|---|
| Durasi closed testing | Minimal **14 hari kalender** berturut-turut |
| Jumlah tester | Minimal **20 tester unik** yang menginstal dan menggunakan app |
| Opt-in tester | Tester harus opt-in via link khusus Google Play |
| Feedback | Tester harus memberikan feedback melalui Play Store atau formulir yang disediakan developer |
| Catatan | Tester menggunakan akun Google yang berbeda-beda (bukan satu akun multi-device) |

> **Referensi resmi:** [https://support.google.com/googleplay/android-developer/answer/14151465](https://support.google.com/googleplay/android-developer/answer/14151465)

### Langkah Setup Closed Testing di Play Console

1. Buka **Play Console** → pilih app → **Testing** → **Closed testing**
2. Buat **release baru** di closed track dengan upload AAB `app-release.aab`
3. Klik **Manage testers** → **Create email list**
4. Tambahkan email tester (minimal 20 alamat Gmail)
5. Salin **opt-in URL** dan bagikan ke tester
6. Tester klik link → opt-in → instal dari Play Store
7. Pantau **Testers tab** di Play Console — pastikan "Active installs" ≥ 20
8. Setelah 14 hari dan syarat terpenuhi, tombol **Apply for production access** akan tersedia

### Catatan Penting

- Tester yang diundang harus menggunakan **link opt-in** — bukan APK langsung
- Tester bisa menggunakan perangkat Android apa saja dengan minSdk 24+ (Android 7.0+)
- Internal testing track (sampai 100 orang) **tidak** memenuhi syarat 14 hari — gunakan **Closed testing track**
- Satu device/akun yang uninstall lalu install ulang tetap dihitung sebagai satu tester unik

---

## BAGIAN 2 — TESTER GUIDE

### Siapa yang Cocok Menjadi Tester

Prioritaskan orang yang:
- Memiliki usaha kecil, warung, atau toko retail
- Pernah menggunakan aplikasi kasir lain (Moka, iREAP, Olsera, dll.)
- Bersedia memberikan feedback jujur
- Dapat mengakses WhatsApp atau email untuk komunikasi

Profil tester yang disarankan (20 orang):
- 8 orang pemilik usaha / owner (warung, toko kelontong, kedai)
- 6 orang kasir atau karyawan toko
- 3 orang pengguna tech-savvy (mahasiswa, freelancer)
- 3 orang non-tech (ibu rumah tangga, pedagang tradisional)

---

### Cara Ikut Closed Testing

**Langkah untuk Tester:**

1. Pastikan menggunakan smartphone Android (Android 7.0 / API 24 ke atas)
2. Klik link opt-in yang dikirimkan pengelola:
   > `[Link opt-in akan dikirim via WhatsApp/email]`
3. Klik **"Become a tester"** di halaman yang terbuka
4. Klik **"Download it on Google Play"**
5. Instal seperti biasa dari Google Play Store
6. Buka app dan ikuti panduan testing di bawah ini
7. Catat pengalaman dan temuan menggunakan formulir feedback

**Durasi yang diharapkan:** 30–60 menit untuk testing awal, kemudian gunakan app seperti biasa selama 2 minggu.

---

### Persiapan Sebelum Mulai

- Koneksi internet aktif untuk instalasi dan verifikasi pertama
- Minimal 50 MB storage tersedia
- Izinkan kamera jika ingin uji scan barcode
- Jika punya printer Bluetooth thermal (ESC/POS), siapkan untuk uji cetak struk

---

## BAGIAN 3 — TESTING CHECKLIST

> Centang setiap langkah setelah selesai. Catat temuan di kolom **Catatan**.

---

### SKENARIO 1 — INSTALL & ONBOARDING

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 1.1 | Instal app dari Play Store via link opt-in | App terinstal tanpa error | ⬜ | |
| 1.2 | Buka app pertama kali | Muncul splash screen "Kasir Dapur" (bukan nama lain) | ⬜ | |
| 1.3 | Halaman onboarding tampil | Ada logo, nama app, dan tagline "Kasir, Stok & Laporan Usaha" | ⬜ | |
| 1.4 | Buat nama toko | Input nama toko, lanjut ke pembuatan PIN | ⬜ | |
| 1.5 | Buat PIN | Input PIN 4–8 digit, konfirmasi, tersimpan | ⬜ | |
| 1.6 | Masuk ke dashboard | Dashboard tampil dengan data kosong (normal untuk akun baru) | ⬜ | |

---

### SKENARIO 2 — LOGIN & KEAMANAN

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 2.1 | Keluar dari sesi (lock screen) | Layar PIN muncul | ⬜ | |
| 2.2 | Masukkan PIN benar | Masuk ke dashboard | ⬜ | |
| 2.3 | Coba PIN salah 3 kali berturut-turut | Ada penanganan (pesan error, jeda, atau blokir sementara) | ⬜ | |
| 2.4 | Paksa tutup app lalu buka kembali | Harus input PIN kembali (sesi terkunci) | ⬜ | |
| 2.5 | Ganti PIN dari Pengaturan | PIN baru berfungsi saat login berikutnya | ⬜ | |

---

### SKENARIO 3 — BUAT PRODUK

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 3.1 | Buka menu Produk | Daftar produk kosong dengan pesan "Belum ada produk" | ⬜ | |
| 3.2 | Tambah produk baru (nama + harga jual) | Produk muncul di daftar | ⬜ | |
| 3.3 | Tambah produk dengan harga beli dan kategori | Tersimpan dengan benar | ⬜ | |
| 3.4 | Tambah produk dengan barcode manual | Barcode tersimpan | ⬜ | |
| 3.5 | Edit produk yang sudah ada | Perubahan tersimpan | ⬜ | |
| 3.6 | Coba tambah produk tanpa nama | Muncul pesan validasi, tidak tersimpan | ⬜ | |
| 3.7 | Coba tambah produk dengan harga negatif | Muncul pesan validasi, tidak tersimpan | ⬜ | |
| 3.8 | Tambah 5–10 produk dengan nama dan harga berbeda | Semua muncul di daftar, bisa di-scroll | ⬜ | |

---

### SKENARIO 4 — STOK

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 4.1 | Buka menu Inventori / Stok | Daftar produk dengan kolom stok | ⬜ | |
| 4.2 | Tambah stok masuk untuk 1 produk (qty + harga beli) | Stok bertambah, riwayat tercatat | ⬜ | |
| 4.3 | Lihat riwayat pergerakan stok | Entri penambahan muncul dengan tanggal dan jumlah | ⬜ | |
| 4.4 | Kurangi stok (stok keluar manual) | Stok berkurang sesuai input | ⬜ | |
| 4.5 | Coba kurangi stok melebihi stok tersedia | Muncul pesan error (jika pengaturan stok negatif = nonaktif) | ⬜ | |
| 4.6 | Lakukan stok opname | Stok diperbarui sesuai nilai opname | ⬜ | |

---

### SKENARIO 5 — PENJUALAN (POS)

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 5.1 | Buka menu Kasir / POS | Layar kasir tampil dengan daftar produk | ⬜ | |
| 5.2 | Pilih 1 produk, tambah ke keranjang | Produk masuk keranjang dengan qty 1 | ⬜ | |
| 5.3 | Tambah qty produk di keranjang | Qty bertambah, total harga berubah | ⬜ | |
| 5.4 | Tambah 3 produk berbeda ke keranjang | Semua produk muncul, total dihitung benar | ⬜ | |
| 5.5 | Hapus satu item dari keranjang | Item hilang, total diperbarui | ⬜ | |
| 5.6 | Kosongkan keranjang | Keranjang kosong | ⬜ | |
| 5.7 | Scan barcode produk (jika kamera tersedia) | Produk langsung masuk keranjang | ⬜ | |
| 5.8 | Coba bayar dengan keranjang kosong | Tombol bayar tidak aktif atau ada pesan error | ⬜ | |

---

### SKENARIO 6 — PEMBAYARAN

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 6.1 | Pilih metode pembayaran Tunai | Sheet pembayaran muncul dengan input uang diterima | ⬜ | |
| 6.2 | Input nominal lebih dari total | Kembalian dihitung otomatis | ⬜ | |
| 6.3 | Input nominal kurang dari total | Tombol bayar tidak aktif atau ada pesan validasi | ⬜ | |
| 6.4 | Konfirmasi pembayaran tunai | Transaksi tersimpan, muncul dialog struk | ⬜ | |
| 6.5 | Pilih metode QRIS atau Transfer | Transaksi tercatat sebagai non-tunai | ⬜ | |
| 6.6 | Bayar transaksi non-tunai | Transaksi tersimpan | ⬜ | |
| 6.7 | Cek stok produk setelah transaksi | Stok berkurang sesuai qty yang terjual | ⬜ | |

---

### SKENARIO 7 — STRUK

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 7.1 | Lihat struk setelah transaksi | Dialog struk tampil dengan detail transaksi | ⬜ | |
| 7.2 | Nama toko muncul di struk | Nama toko yang sudah diisi tampil di header | ⬜ | |
| 7.3 | Daftar produk, harga, qty, dan total benar | Semua angka sesuai transaksi | ⬜ | |
| 7.4 | Cetak struk ke printer Bluetooth (jika tersedia) | Struk tercetak, format rapi | ⬜ | |
| 7.5 | Tutup dialog struk tanpa cetak | Kembali ke layar kasir, keranjang kosong | ⬜ | |
| 7.6 | Buka riwayat transaksi | Transaksi yang baru dibuat muncul di daftar | ⬜ | |

---

### SKENARIO 8 — MODE OFFLINE

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 8.1 | Nonaktifkan WiFi dan data seluler | Ada indikator offline di dashboard atau app tetap berjalan | ⬜ | |
| 8.2 | Buka menu Kasir saat offline | Kasir tetap bisa digunakan | ⬜ | |
| 8.3 | Buat transaksi saat offline | Transaksi tersimpan di lokal, tidak ada error | ⬜ | |
| 8.4 | Lihat riwayat transaksi saat offline | Data offline tetap tampil | ⬜ | |
| 8.5 | Tambah produk baru saat offline | Produk tersimpan lokal | ⬜ | |
| 8.6 | Tambah stok saat offline | Stok tersimpan lokal | ⬜ | |
| 8.7 | Paksa tutup app saat offline, buka kembali | Data tidak hilang | ⬜ | |

---

### SKENARIO 9 — ONLINE & SINKRONISASI

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 9.1 | Aktifkan kembali koneksi internet | Indikator offline hilang (jika ada) | ⬜ | |
| 9.2 | Cek apakah ada proses sync otomatis | Tidak ada error saat sync | ⬜ | |
| 9.3 | Buka menu Sinkronisasi (jika tersedia) | Status sync terakhir tampil | ⬜ | |
| 9.4 | Jalankan sync manual (jika tersedia) | Proses berjalan, status berubah | ⬜ | |
| 9.5 | Data yang dibuat saat offline tetap ada setelah sync | Tidak ada data yang hilang | ⬜ | |

---

### SKENARIO 10 — LAPORAN

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 10.1 | Buka menu Laporan | Halaman laporan tampil dengan filter periode | ⬜ | |
| 10.2 | Lihat laporan hari ini | Transaksi yang baru dibuat muncul di ringkasan | ⬜ | |
| 10.3 | Ganti filter ke "Minggu ini" | Laporan berubah sesuai periode | ⬜ | |
| 10.4 | Ganti filter ke "Bulan ini" | Laporan berubah sesuai periode | ⬜ | |
| 10.5 | Lihat produk terlaris | Produk dengan qty terjual terbanyak muncul di urutan pertama | ⬜ | |
| 10.6 | Lihat ringkasan omzet | Nominal sesuai transaksi yang dibuat saat testing | ⬜ | |
| 10.7 | Coba ekspor laporan (jika tersedia di paket) | File terunduh atau dibagikan | ⬜ | |

---

### SKENARIO 11 — SUBSCRIPTION / LANGGANAN

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 11.1 | Buka Pengaturan → Langganan | Halaman subscription tampil dengan paket aktif | ⬜ | |
| 11.2 | Paket Free ditampilkan sebagai aktif | Label "Free" atau "Gratis" tampil | ⬜ | |
| 11.3 | Lihat daftar paket Pro dan Business | Harga dan fitur setiap paket tampil dengan benar | ⬜ | |
| 11.4 | Coba akses fitur Pro saat di paket Free | Muncul halaman informasi upgrade (bukan crash) | ⬜ | |
| 11.5 | Jika ada tombol upgrade | Alur upgrade dapat diikuti tanpa crash | ⬜ | |

---

### SKENARIO 12 — LOGOUT

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 12.1 | Buka Pengaturan | Menu pengaturan tampil lengkap | ⬜ | |
| 12.2 | Cari opsi Kunci Layar atau Keluar | Opsi tersedia | ⬜ | |
| 12.3 | Kunci sesi / lock screen | Layar PIN muncul, harus input PIN untuk lanjut | ⬜ | |
| 12.4 | Buka app setelah dikunci | Harus input PIN | ⬜ | |
| 12.5 | Ganti ke akun kasir lain (jika ada multi-user) | Login dengan PIN kasir lain berhasil | ⬜ | |

---

### SKENARIO 13 — HAPUS AKUN

| # | Langkah | Expected | Status | Catatan |
|---|---|---|---|---|
| 13.1 | Buka Pengaturan → Privacy → Hapus Akun | Halaman atau dialog hapus akun tampil | ⬜ | |
| 13.2 | Baca informasi sebelum hapus | Ada penjelasan efek penghapusan (data lokal, server) | ⬜ | |
| 13.3 | Proses konfirmasi | Perlu mengetik kata konfirmasi (misal "HAPUS") — bukan tap sekali | ⬜ | |
| 13.4 | Batalkan penghapusan | Dapat dibatalkan tanpa efek | ⬜ | |
| 13.5 | *(Opsional — hanya jika mau)* Konfirmasi hapus | App kembali ke halaman onboarding, data terhapus | ⬜ | |

> ⚠️ **Perhatian:** Langkah 13.5 akan menghapus seluruh data lokal (produk, transaksi, pengguna). Lakukan hanya jika Anda memang ingin reset app.

---

## BAGIAN 4 — SKENARIO TESTING LANJUTAN

Skenario berikut untuk tester yang ingin melakukan pengujian lebih dalam.

---

### SKENARIO A — FAILURE SCENARIOS

| # | Skenario | Cara Menguji | Expected |
|---|---|---|---|
| A.1 | Putus koneksi di tengah transaksi | Matikan WiFi saat proses bayar | Transaksi tetap tersimpan lokal |
| A.2 | Force close saat mengetik | Tutup paksa app saat input produk | Data draft tidak menyebabkan crash saat dibuka kembali |
| A.3 | Tap tombol Bayar berkali-kali cepat | Double tap tombol konfirmasi pembayaran | Hanya satu transaksi yang terbuat |
| A.4 | Input angka sangat besar di harga | Masukkan 9999999999 sebagai harga | Ada validasi atau app tidak crash |
| A.5 | Input karakter spesial di nama produk | Nama dengan emoji atau simbol | Tersimpan atau ditolak dengan pesan jelas |
| A.6 | Buka app dengan storage hampir penuh | Uji di perangkat dengan <100 MB tersisa | App memberikan pesan atau graceful degradation |

---

### SKENARIO B — PRINTER (Jika Ada Printer Bluetooth)

| # | Langkah | Expected |
|---|---|---|
| B.1 | Sambungkan printer Bluetooth | App mendeteksi printer |
| B.2 | Konfigurasi printer di Pengaturan → Printer | Nama dan alamat printer tersimpan |
| B.3 | Cetak struk setelah transaksi | Struk tercetak, format sesuai ukuran kertas |
| B.4 | Cabut printer saat proses cetak | App menampilkan pesan error printer, transaksi tidak dibatalkan |
| B.5 | Cetak ulang struk dari riwayat | Berhasil dicetak ulang |

---

### SKENARIO C — MULTI KASIR (Jika Ada Lebih dari 1 Akun)

| # | Langkah | Expected |
|---|---|---|
| C.1 | Owner tambah akun kasir baru | Akun kasir muncul di daftar pengguna |
| C.2 | Login dengan akun kasir | Dashboard kasir tampil (mungkin lebih terbatas dari owner) |
| C.3 | Kasir coba akses menu yang dibatasi | Tidak bisa akses — ada pesan informatif |
| C.4 | Owner lihat laporan dari kasir tertentu | Filter kasir di laporan berfungsi |

---

## BAGIAN 5 — FORMULIR FEEDBACK

Gunakan formulir berikut untuk melaporkan pengalaman. Salin ke WhatsApp, email, atau Google Form yang disediakan.

---

```
FORMULIR FEEDBACK KASIR DAPUR — CLOSED TESTING
================================================

Nama (opsional): ___________________
Jenis usaha: ___________________
Perangkat: ___________________  (contoh: Samsung Galaxy A32, Android 11)
Versi app: 1.0.0

---

PENILAIAN UMUM (1–5)
Kemudahan penggunaan: ___
Kecepatan app: ___
Tampilan / desain: ___
Keandalan (tidak crash): ___
Kepuasan keseluruhan: ___

---

BUG / MASALAH YANG DITEMUKAN
(Satu isian per bug. Sertakan langkah untuk mereproduksi.)

Bug 1:
- Skenario: ___________________
- Langkah: ___________________
- Yang terjadi: ___________________
- Yang diharapkan: ___________________
- Frekuensi: Selalu / Kadang / Sekali

Bug 2: (isi jika ada)
...

---

FITUR YANG DISUKAI
___________________

FITUR YANG MEMBINGUNGKAN
___________________

FITUR YANG PALING DIBUTUHKAN (BELUM ADA)
___________________

KOMENTAR LAIN
___________________

---
Terima kasih atas waktu dan masukan Anda!
Kasir Dapur — support@dapur-rasa.com
```

---

## BAGIAN 6 — KNOWN ISSUES (Masalah yang Sudah Diketahui)

Tester tidak perlu melaporkan item di bawah ini — sudah diketahui dan sedang dalam proses penyelesaian.

| ID | Area | Deskripsi | Dampak | Status |
|---|---|---|---|---|
| KI-01 | Subscription | Harga paket Pro dan Business belum dikonfigurasi — tampil placeholder | User tidak bisa lihat harga nyata | Menunggu keputusan harga bisnis |
| KI-02 | Environment | Build testing mengarah ke API dev, bukan production | Subscription/sync mungkin tidak berfungsi penuh | Akan difix saat build production |
| KI-03 | Play Billing | Pembayaran upgrade menggunakan Midtrans, bukan Google Play Billing | Alur upgrade belum bisa diuji di closed testing | Dalam evaluasi |
| KI-04 | Sync | Sinkronisasi Google Sheets membutuhkan konfigurasi backend aktif | Fitur sync mungkin return error di environment testing | Backend dalam persiapan |
| KI-05 | Backup | Cloud backup membutuhkan backend aktif | Backup cloud mungkin gagal | Backend dalam persiapan |
| KI-06 | Website | URL dapur-rasa.com belum aktif | Link di Privacy Policy tidak bisa dibuka | Dalam persiapan deployment |

---

## BAGIAN 7 — KRITERIA KELULUSAN CLOSED TESTING

Closed testing dianggap **lulus** jika memenuhi kondisi berikut:

### Persyaratan Google Play (Wajib)
- [x] Minimal 20 tester unik yang opt-in dan menginstal app
- [x] Minimal 14 hari kalender program berjalan
- [x] Tidak ada laporan crash massal (> 1% crash rate di Play Console)
- [x] ANR rate < 0.47% (ambang Google Play)

### Persyaratan Internal (Wajib Sebelum Production)
- [ ] Semua skenario 1–12 diuji oleh minimal 10 tester tanpa blocker baru
- [ ] Tidak ada bug baru severity CRITICAL yang belum ada di Known Issues
- [ ] BLOCKER B-01 (harga subscription) diselesaikan
- [ ] BLOCKER B-02 (ENV=prod build) diselesaikan
- [ ] BLOCKER B-03 (Play Billing) diselesaikan atau ada keputusan eksplisit

### Kriteria Lulus Opsional (Disarankan)
- [ ] Rata-rata penilaian feedback ≥ 3.5/5 untuk kemudahan penggunaan
- [ ] Tidak ada keluhan berulang tentang alur yang membingungkan dari > 3 tester berbeda

---

## BAGIAN 8 — JADWAL TESTING

| Fase | Durasi | Target |
|---|---|---|
| Persiapan (rekrut tester, setup Play Console) | 3–5 hari | 20+ tester opt-in |
| Testing aktif (hari 1–7) | 7 hari | Semua tester selesai skenario 1–10 |
| Testing lanjutan (hari 8–14) | 7 hari | Kumpulkan feedback, perbaiki bug kecil |
| Review & keputusan | 2–3 hari | Evaluasi apakah siap apply production access |
| **Total minimum** | **14+ hari** | Sesuai syarat Google Play |

---

## BAGIAN 9 — KONTAK & ESKALASI

| Peran | Kontak |
|---|---|
| Pengelola testing | support@dapur-rasa.com |
| Laporan bug kritis | Langsung via WhatsApp ke koordinator tester |
| Privacy & data | privacy@dapur-rasa.com |
| Website | dapur-rasa.com |

---

*Dokumen ini dibuat untuk keperluan persiapan closed testing Kasir Dapur di Google Play Store (STEP 29).*  
*Versi dokumen: 1.0 — 2026-08-19*
