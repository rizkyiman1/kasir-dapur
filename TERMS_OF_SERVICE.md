# Syarat dan Ketentuan — Kasir Dapur

**Versi:** 1.0  
**Berlaku mulai:** 2026-08-19  
**Penyedia:** PT Dapur Rasa Karya Nusantara  
**Pengembang:** Mas Rizky Iman  
**Situs:** https://dapur-rasa.com  
**Package:** com.kasirdapur.app

---

## 1. Penerimaan Syarat

Dengan mengunduh, memasang, atau menggunakan aplikasi Kasir Dapur, Anda menyetujui syarat dan ketentuan ini. Jika Anda tidak menyetujui, jangan gunakan aplikasi ini.

## 2. Layanan

Kasir Dapur menyediakan:

- Sistem kasir (Point of Sale) berbasis Android
- Manajemen stok dan inventori
- Laporan keuangan (penjualan, pengeluaran, sesi kas)
- Manajemen pelanggan dan pemasok
- Cetak struk via printer Bluetooth thermal
- Fitur cloud opsional: cadangan data, sinkronisasi, dan langganan paket berbayar

## 3. Sifat Offline-First

Database SQLite di perangkat Anda adalah **sumber data utama** transaksi kasir. Fitur cloud (backup, sync, verifikasi langganan) bersifat tambahan dan opsional. Anda tetap dapat mencatat transaksi saat tidak ada koneksi internet, printer bermasalah, atau server tidak tersedia.

## 4. Akun Pengguna Lokal

- **Owner:** Akun pertama yang dibuat saat onboarding. Memiliki akses penuh ke semua fitur dan pengaturan
- **Admin:** Dapat mengelola produk, laporan, expense, dan stok. Tidak dapat mengubah pengaturan subscription atau menghapus akun
- **Kasir:** Akses kasir, manajemen pelanggan, sesi kas, dan printer

Semua akun adalah **pengguna lokal** di perangkat Anda. Kasir Dapur tidak mengelola akun cloud berbasis email/password untuk fungsi kasir.

Anda bertanggung jawab menjaga kerahasiaan PIN setiap pengguna.

## 5. Langganan dan Pembayaran

### 5.1 Paket

| Paket | Deskripsi |
|-------|-----------|
| Free | Fitur kasir dasar, offline, tanpa batas waktu |
| Pro | Fitur lanjutan: laporan detail, backup cloud, sync Google Sheets |
| Ultra | Semua fitur Pro plus entitlement tambahan |

Fitur spesifik per paket ditampilkan di aplikasi pada menu Pengaturan → SUBSCRIPTION.

### 5.2 Proses Pembayaran

1. Anda memilih paket dan menekan tombol Upgrade
2. Aplikasi meminta backend Kasir Dapur membuat sesi pembayaran Midtrans
3. Anda diarahkan ke halaman web Midtrans (browser) untuk menyelesaikan pembayaran
4. Setelah pembayaran dikonfirmasi oleh Midtrans, backend memverifikasi dan mengaktifkan paket

**Tombol Upgrade tidak langsung mengaktifkan paket.** Aktivasi terjadi hanya setelah konfirmasi dari Midtrans dan verifikasi backend Kasir Dapur.

### 5.3 Pembatalan dan Pengembalian Dana

Kebijakan pembatalan dan pengembalian dana mengikuti ketentuan yang tercantum di https://dapur-rasa.com. Hubungi kami melalui situs tersebut untuk pertanyaan terkait pengembalian dana.

### 5.4 Kegagalan Pembayaran

Jika pembayaran gagal atau tidak dikonfirmasi, akun Anda akan tetap pada paket sebelumnya. Status langganan dapat diverifikasi ulang di Pengaturan → SUBSCRIPTION.

## 6. Keterbatasan Layanan

Kasir Dapur tidak bertanggung jawab atas:

- Kehilangan data akibat kerusakan perangkat, penghapusan aplikasi, atau reset pabrik
- Gangguan cetak struk akibat masalah perangkat keras printer
- Ketidaktersediaan layanan cloud sementara akibat pemeliharaan server
- Ketidakakuratan data yang dimasukkan oleh pengguna

Kami sangat menyarankan Anda mengaktifkan fitur **Backup** secara rutin.

## 7. Penggunaan yang Dilarang

Dilarang menggunakan Kasir Dapur untuk:

- Aktivitas ilegal atau penipuan
- Mencatat transaksi fiktif untuk penggelapan pajak
- Mendistribusikan ulang atau memodifikasi aplikasi tanpa izin tertulis dari PT Dapur Rasa Karya Nusantara
- Melakukan reverse engineering terhadap aplikasi

## 8. Kekayaan Intelektual

Kasir Dapur, termasuk nama, logo, desain antarmuka, dan kode aplikasi adalah milik PT Dapur Rasa Karya Nusantara. Anda mendapatkan lisensi terbatas, non-eksklusif, tidak dapat dialihkan untuk menggunakan aplikasi sesuai syarat ini.

## 9. Penghapusan Akun

Anda dapat menghapus akun perangkat melalui Pengaturan → PRIVACY → Delete Account. Tindakan ini:

- Menghapus semua pengguna lokal (Owner, Admin, Kasir) di perangkat ini
- Mengakhiri sesi aktif
- Mengembalikan aplikasi ke layar onboarding
- **Tidak** menghapus data transaksi di database SQLite

Untuk menghapus semua data termasuk riwayat transaksi, gunakan: Pengaturan Android → Aplikasi → Kasir Dapur → Hapus Data.

## 10. Perubahan Layanan

PT Dapur Rasa Karya Nusantara berhak mengubah, menangguhkan, atau menghentikan layanan cloud (backup, sync, subscription) dengan pemberitahuan di https://dapur-rasa.com. Fitur offline kasir tidak terpengaruh oleh perubahan layanan cloud.

## 11. Hukum yang Berlaku

Syarat ini diatur dan ditafsirkan berdasarkan hukum Republik Indonesia. Sengketa diselesaikan sesuai ketentuan hukum yang berlaku di Indonesia.

## 12. Kontak

**PT Dapur Rasa Karya Nusantara**  
Pengembang: Mas Rizky Iman  
Situs: https://dapur-rasa.com
