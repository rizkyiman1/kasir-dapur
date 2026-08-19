import 'package:kasir_dapur/config/brand.dart';

/// Teks legal resmi aplikasi. Konten mencerminkan arsitektur data aktual:
/// offline-first SQLite, PIN hash PBKDF2, subscription via Midtrans backend.
abstract final class LegalDocuments {
  static const String privacyTitle = 'Kebijakan Privasi';
  static const String termsTitle = 'Syarat dan Ketentuan';
  static const String supportTitle = 'Dukungan & Kontak';
  static const String dataSafetyTitle = 'Data & Keamanan';
  static const String accountDeletionTitle = 'Hapus Akun';
  static const String appAccessTitle = 'Cara Menggunakan Aplikasi';

  // ---------------------------------------------------------------------------
  // Kebijakan Privasi
  // ---------------------------------------------------------------------------

  static const String privacyBody =
      '''Kebijakan Privasi ${Brand.appName}
Versi 1.0 · Berlaku mulai 2026-08-19

Pengendali data : ${Brand.companyName}
Pengembang      : ${Brand.ownerName}
Situs           : ${Brand.websiteUrl}
Package         : ${Brand.packageId}

─────────────────────────────────────────
1. PENDAHULUAN
─────────────────────────────────────────
${Brand.appName} adalah aplikasi kasir, manajemen stok, dan laporan keuangan untuk usaha kecil menengah. Aplikasi beroperasi secara offline-first: seluruh data transaksi disimpan di SQLite pada perangkat Anda.

─────────────────────────────────────────
2. DATA YANG DISIMPAN LOKAL DI PERANGKAT
─────────────────────────────────────────
Data berikut HANYA disimpan di SQLite perangkat Anda dan tidak pernah dikirim ke server tanpa tindakan eksplisit:

• Transaksi penjualan (tanggal, item, harga, total, metode bayar)
• Produk dan stok (nama, harga, kategori, jumlah)
• Pelanggan (nama, telepon, riwayat beli)
• Pemasok (nama, telepon, riwayat pembelian)
• Pengeluaran (kategori, jumlah, keterangan)
• Sesi kas (saldo awal, pemasukan, pengeluaran, laporan)
• Profil toko (nama toko, alamat, telepon, footer struk, logo)
• Akun pengguna lokal (nama, peran)
• Hash PIN (PBKDF2-HMAC-SHA256 + salt 16-byte — bukan PIN asli)
• Pengaturan aplikasi dan preferensi pengguna
• Profil printer Bluetooth (nama, alamat MAC)

─────────────────────────────────────────
3. DATA YANG DIKIRIM KE SERVER (FITUR CLOUD OPSIONAL)
─────────────────────────────────────────
Hanya saat Anda menggunakan subscription, backup, atau sync:

• business_id (UUID perangkat) — identifikasi bisnis
• client_uuid (UUID sesi) — deduplikasi cadangan
• plan_code (kode paket) — penentuan harga
• Snapshot data bisnis — hanya jika fitur Backup cloud diaktifkan
• Sync jobs (delta perubahan) — hanya jika fitur Sync diaktifkan

Data yang TIDAK dikirim ke server kami:
• PIN atau hash PIN
• Detail kartu kredit/debit atau rekening bank
• Informasi identitas pribadi (nama, email, KTP)

─────────────────────────────────────────
4. PEMBAYARAN SUBSCRIPTION (MIDTRANS)
─────────────────────────────────────────
Pembayaran subscription diproses oleh Midtrans. Alur:
1. Aplikasi meminta backend ${Brand.appName} membuat sesi pembayaran
2. Backend menghubungi Midtrans menggunakan business_id dan plan_code
3. Anda menerima Snap Token dan diarahkan ke halaman web Midtrans
4. Pembayaran diselesaikan di halaman Midtrans (bukan di dalam aplikasi)
5. Midtrans mengirim konfirmasi webhook ke backend kami
6. Backend memverifikasi dan mengaktifkan subscription

${Brand.appName} tidak melihat detail kartu atau rekening Anda. Kebijakan privasi Midtrans berlaku untuk data di halaman pembayaran mereka.

Server Key Midtrans tidak pernah ada di aplikasi Flutter ini. Hanya di server backend ${Brand.appName}.

─────────────────────────────────────────
5. SINKRONISASI GOOGLE SHEETS (OPSIONAL)
─────────────────────────────────────────
Jika Anda mengaktifkan Sync Google Sheets (paket Pro/Business), data laporan dikirim ke server ${Brand.appName} lalu diteruskan ke Spreadsheet yang Anda pilih dan otorisasi. ${Brand.appName} tidak mengakses Spreadsheet di luar data yang Anda otorisasi.

─────────────────────────────────────────
6. HAK ANDA
─────────────────────────────────────────
• Akses data: semua data dapat dilihat langsung di aplikasi
• Ubah data: melalui menu Pengaturan
• Hapus akun perangkat: Pengaturan → PRIVACY → Hapus Akun
  (menghapus semua pengguna lokal dan sesi; database tidak di-DROP)
• Hapus semua data: Pengaturan Android → Aplikasi → ${Brand.packageId} → Hapus Data
• Ekspor data: Pengaturan → BACKUP

─────────────────────────────────────────
7. KEAMANAN
─────────────────────────────────────────
• SQLite disimpan di direktori privat Android (tidak dapat diakses aplikasi lain tanpa root)
• PIN di-hash dengan PBKDF2-HMAC-SHA256; tidak disimpan dalam bentuk asli
• Semua koneksi server menggunakan HTTPS/TLS
• Log tidak mencatat PIN, token, atau secret

─────────────────────────────────────────
8. KONTAK
─────────────────────────────────────────
${Brand.companyName}
${Brand.ownerName}
${Brand.websiteUrl}
''';

  // ---------------------------------------------------------------------------
  // Syarat dan Ketentuan
  // ---------------------------------------------------------------------------

  static const String termsBody =
      '''Syarat dan Ketentuan ${Brand.appName}
Versi 1.0 · Berlaku mulai 2026-08-19

Penyedia  : ${Brand.companyName}
Pengembang: ${Brand.ownerName}
Situs     : ${Brand.websiteUrl}
Package   : ${Brand.packageId}

─────────────────────────────────────────
1. PENERIMAAN SYARAT
─────────────────────────────────────────
Dengan menggunakan ${Brand.appName}, Anda menyetujui syarat ini. Jika tidak setuju, jangan gunakan aplikasi.

─────────────────────────────────────────
2. LAYANAN
─────────────────────────────────────────
${Brand.appName} menyediakan:
• Sistem kasir (Point of Sale) berbasis Android
• Manajemen stok dan inventori
• Laporan keuangan (penjualan, pengeluaran, sesi kas)
• Manajemen pelanggan dan pemasok
• Cetak struk via printer Bluetooth thermal
• Fitur cloud opsional: backup, sync, dan subscription berbayar

─────────────────────────────────────────
3. OFFLINE-FIRST
─────────────────────────────────────────
SQLite di perangkat adalah sumber data utama transaksi. Fitur cloud (backup, sync, verifikasi subscription) bersifat tambahan dan opsional. Anda tetap dapat mencatat transaksi tanpa koneksi internet.

─────────────────────────────────────────
4. AKUN PENGGUNA LOKAL
─────────────────────────────────────────
• Owner: akun pertama saat onboarding; akses penuh
• Admin: manajemen produk, laporan, expense, stok
• Kasir: kasir, pelanggan, sesi kas, printer

Semua akun adalah pengguna lokal di perangkat Anda. Anda bertanggung jawab menjaga kerahasiaan PIN.

─────────────────────────────────────────
5. SUBSCRIPTION DAN PEMBAYARAN
─────────────────────────────────────────
Paket: Free, Pro, Business — fitur per paket ditampilkan di aplikasi.

Proses aktivasi:
1. Pilih paket → tekan Upgrade
2. Diarahkan ke halaman web Midtrans
3. Selesaikan pembayaran di Midtrans
4. Backend kami memverifikasi konfirmasi Midtrans
5. Paket aktif setelah verifikasi berhasil

Tombol Upgrade TIDAK langsung mengaktifkan paket. Aktivasi hanya setelah konfirmasi Midtrans dan verifikasi backend.

Kebijakan pengembalian dana: lihat ${Brand.websiteUrl}

─────────────────────────────────────────
6. KETERBATASAN TANGGUNG JAWAB
─────────────────────────────────────────
${Brand.companyName} tidak bertanggung jawab atas:
• Kehilangan data akibat kerusakan perangkat, reset pabrik, atau penghapusan aplikasi
• Gangguan cetak akibat masalah printer
• Gangguan layanan cloud sementara akibat pemeliharaan server
• Ketidakakuratan data yang dimasukkan pengguna

Kami sangat menyarankan mengaktifkan fitur Backup secara rutin.

─────────────────────────────────────────
7. PENGHAPUSAN AKUN
─────────────────────────────────────────
Pengaturan → PRIVACY → Hapus Akun:
• Menghapus semua pengguna lokal di perangkat ini
• Mengakhiri sesi aktif
• Kembali ke layar onboarding
• Data transaksi SQLite TIDAK di-DROP

Untuk hapus semua data termasuk transaksi:
Pengaturan Android → Aplikasi → Kasir Dapur → Hapus Data

─────────────────────────────────────────
8. HUKUM YANG BERLAKU
─────────────────────────────────────────
Syarat ini diatur berdasarkan hukum Republik Indonesia.

─────────────────────────────────────────
9. KONTAK
─────────────────────────────────────────
${Brand.companyName}
${Brand.ownerName}
${Brand.websiteUrl}
''';

  // ---------------------------------------------------------------------------
  // Data & Keamanan
  // ---------------------------------------------------------------------------

  static const String dataSafetyBody =
      '''Data & Keamanan ${Brand.appName}

─────────────────────────────────────────
DATA YANG DISIMPAN LOKAL (tidak dikirim ke server)
─────────────────────────────────────────
• Transaksi penjualan
• Produk dan stok
• Pelanggan dan pemasok
• Pengeluaran dan sesi kas
• Profil toko (nama, alamat, telepon, logo)
• Pengguna lokal (hash PIN — bukan PIN asli)
• Pengaturan dan preferensi
• Profil printer Bluetooth

─────────────────────────────────────────
DATA YANG DIKIRIM KE SERVER (fitur cloud opsional)
─────────────────────────────────────────
• business_id (UUID) — untuk subscription dan backup
• Riwayat pembayaran (order_id, paket, jumlah) — rekonsiliasi
• Snapshot data bisnis — hanya jika Backup cloud diaktifkan
• Sync jobs — hanya jika Sync diaktifkan

─────────────────────────────────────────
DATA YANG DIPROSES MIDTRANS (pembayaran)
─────────────────────────────────────────
• order_id dan gross_amount — untuk pemrosesan pembayaran
• Metode bayar yang Anda pilih — diproses langsung oleh Midtrans
• ${Brand.appName} tidak melihat detail kartu atau rekening Anda

─────────────────────────────────────────
DATA YANG TIDAK PERNAH DIKIRIM
─────────────────────────────────────────
• PIN atau hash PIN
• Detail kartu kredit/debit
• Informasi identitas pribadi (email, KTP)
• Data lokasi

─────────────────────────────────────────
KEAMANAN
─────────────────────────────────────────
• PIN: hash PBKDF2-HMAC-SHA256 + salt 16-byte
• Koneksi: HTTPS/TLS untuk semua server
• Log: tidak mencatat PIN, token, atau secret
• SQLite: direktori privat Android

─────────────────────────────────────────
HAK PENGGUNA
─────────────────────────────────────────
• Lihat data: langsung di aplikasi
• Ubah data: menu Pengaturan
• Hapus akun: Pengaturan → PRIVACY → Hapus Akun
• Hapus semua data: Pengaturan Android → Aplikasi → Kasir Dapur → Hapus Data
• Ekspor data: Pengaturan → BACKUP
• Minta hapus data server: ${Brand.websiteUrl}

─────────────────────────────────────────
KONTAK
─────────────────────────────────────────
${Brand.companyName} · ${Brand.ownerName}
${Brand.websiteUrl}
''';

  // ---------------------------------------------------------------------------
  // Hapus Akun
  // ---------------------------------------------------------------------------

  static const String accountDeletionBody =
      '''Hapus Akun — ${Brand.appName}

─────────────────────────────────────────
CARA MENGHAPUS AKUN PERANGKAT
─────────────────────────────────────────
1. Buka Pengaturan (ikon roda gigi di navigasi bawah)
2. Gulir ke bagian PRIVACY
3. Ketuk "Hapus Akun"
4. Baca peringatan yang muncul
5. Ketik kata HAPUS di kolom konfirmasi
6. Ketuk tombol "Hapus akun"

EFEK PENGHAPUSAN AKUN:
✓ Semua pengguna lokal (Owner, Admin, Kasir) dihapus dari perangkat ini
✓ Sesi aktif diakhiri
✓ Aplikasi kembali ke layar onboarding (pengaturan awal)

YANG TIDAK TERHAPUS:
• Data transaksi, stok, pelanggan, pengeluaran di database SQLite
  → Data ini tetap ada di perangkat sampai Anda menghapus data aplikasi

─────────────────────────────────────────
CARA MENGHAPUS SEMUA DATA APLIKASI
─────────────────────────────────────────
Untuk menghapus seluruh data termasuk riwayat transaksi:
1. Buka Pengaturan Android (bukan pengaturan di dalam aplikasi)
2. Ketuk Aplikasi atau Manajemen Aplikasi
3. Cari dan ketuk "Kasir Dapur"
4. Ketuk "Hapus Data" atau "Clear Data"
5. Konfirmasi penghapusan

PERINGATAN: Tindakan ini permanen dan tidak dapat dibatalkan.
Pastikan Anda sudah melakukan backup sebelum menghapus data.

─────────────────────────────────────────
HAPUS DATA DI SERVER
─────────────────────────────────────────
Untuk menghapus data yang tersimpan di server kami
(backup cloud, riwayat subscription):

Hubungi: ${Brand.websiteUrl}

Kami akan memproses permintaan dalam 30 hari kerja.

─────────────────────────────────────────
KONTAK
─────────────────────────────────────────
${Brand.companyName} · ${Brand.ownerName}
Email: privacy@dapur-rasa.com
${Brand.websiteUrl}
''';

  // ---------------------------------------------------------------------------
  // App Access Instructions
  // ---------------------------------------------------------------------------

  static const String appAccessBody =
      '''Cara Menggunakan ${Brand.appName}

─────────────────────────────────────────
PERTAMA KALI MENGGUNAKAN
─────────────────────────────────────────
1. Buka aplikasi → layar onboarding muncul
2. Masukkan nama toko Anda
3. Buat PIN untuk akun Owner (minimal 4 digit)
4. Konfirmasi PIN
5. Aplikasi siap digunakan

─────────────────────────────────────────
PERAN PENGGUNA
─────────────────────────────────────────
Owner   : Akses penuh — kasir, produk, laporan, pengaturan, subscription
Admin   : Produk, stok, laporan, pengeluaran, pelanggan, pemasok
Kasir   : Kasir, pelanggan, sesi kas, printer, barcode

Menambah pengguna:
Pengaturan → USER → Tambah pengguna

─────────────────────────────────────────
TRANSAKSI KASIR
─────────────────────────────────────────
1. Ketuk ikon Kasir di navigasi bawah
2. Pilih produk dari katalog atau scan barcode
3. Atur jumlah item
4. Ketuk Bayar
5. Pilih metode pembayaran (Tunai, Transfer, dll.)
6. Masukkan jumlah bayar (untuk tunai)
7. Konfirmasi → Transaksi tersimpan

─────────────────────────────────────────
CETAK STRUK
─────────────────────────────────────────
• Printer Bluetooth thermal diperlukan
• Tambahkan printer: Pengaturan → PRINTER
• Struk dapat dicetak otomatis setelah transaksi
  (atur di Pengaturan → POS → Receipt behavior)

─────────────────────────────────────────
LAPORAN
─────────────────────────────────────────
• Dashboard: ringkasan omzet hari ini
• Transaksi: riwayat penjualan lengkap
• Laporan: omzet per periode, produk terlaris
• Pengeluaran: kategori dan total pengeluaran
• Sesi Kas: laporan kas harian

─────────────────────────────────────────
BACKUP DATA
─────────────────────────────────────────
Pengaturan → BACKUP → Backup Now
(fitur cloud tersedia di paket Pro/Business)

─────────────────────────────────────────
SUBSCRIPTION
─────────────────────────────────────────
Pengaturan → SUBSCRIPTION → Upgrade
Pembayaran diproses via Midtrans (browser)
Aktivasi otomatis setelah konfirmasi pembayaran

─────────────────────────────────────────
BANTUAN
─────────────────────────────────────────
Pengaturan → PRIVACY → Support
atau kunjungi: ${Brand.websiteUrl}
''';

  // ---------------------------------------------------------------------------
  // Dukungan
  // ---------------------------------------------------------------------------

  static const String supportBody =
      '''Dukungan & Kontak ${Brand.appName}

─────────────────────────────────────────
INFORMASI RESMI
─────────────────────────────────────────
${Brand.companyName}
Pengembang: ${Brand.ownerName}
Situs: ${Brand.websiteUrl}

─────────────────────────────────────────
TOPIK BANTUAN
─────────────────────────────────────────
• Cara menggunakan aplikasi
• Masalah printer Bluetooth
• Pertanyaan subscription dan pembayaran
• Permintaan backup atau pemulihan data
• Pertanyaan privasi dan penghapusan data
• Laporan bug atau masalah teknis

Untuk semua pertanyaan di atas, kunjungi:
${Brand.websiteUrl}

─────────────────────────────────────────
PENGHAPUSAN AKUN DAN DATA
─────────────────────────────────────────
• Hapus akun perangkat:
  Pengaturan → PRIVACY → Hapus Akun

• Hapus semua data aplikasi:
  Pengaturan Android → Aplikasi → Kasir Dapur → Hapus Data

• Permintaan hapus data di server:
  ${Brand.websiteUrl}

─────────────────────────────────────────
STATUS LAYANAN
─────────────────────────────────────────
Informasi pemeliharaan dan status layanan:
${Brand.websiteUrl}

${Brand.companyName} · ${Brand.ownerName}
''';
}
