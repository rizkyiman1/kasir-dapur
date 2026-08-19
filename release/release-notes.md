# Release Notes — Kasir Dapur 1.0.0

**Versi:** 1.0.0+1  
**Tanggal Build:** 2026-08-19  
**Package ID:** com.kasirdapur.app  
**Min Android:** 5.0 (API 21)  
**Target Android:** 14 (API 35)  
**Developer:** Mas Rizky Iman — PT Dapur Rasa Karya Nusantara

---

## Rilis Pertama

Kasir Dapur 1.0.0 adalah rilis pertama aplikasi kasir dan manajemen usaha untuk toko retail, warung, dan UMKM Indonesia.

---

## Fitur yang Tersedia

### Kasir (POS)
- Transaksi penjualan offline tanpa internet
- Keranjang belanja dengan penambahan dan pengurangan item
- Pembayaran tunai dengan hitung kembalian otomatis
- Pembayaran non-tunai (QRIS, transfer, kartu)
- Scan barcode produk via kamera
- Sesi kasir (buka saldo, tutup saldo, laporan sesi)
- Riwayat transaksi

### Inventori & Stok
- Manajemen produk dengan nama, harga beli, harga jual, kategori
- Pergerakan stok masuk dan keluar
- Stok opname
- Riwayat stok per produk

### Laporan
- Ringkasan omzet dan transaksi (harian, mingguan, bulanan)
- Produk terlaris
- Laporan per kasir

### Struk & Printer
- Struk digital setelah transaksi
- Cetak ke printer Bluetooth thermal (ESC/POS)
- Format kertas 58mm dan 80mm

### Manajemen Pengguna
- Akun owner, admin, kasir
- Login dengan PIN (4–8 digit)
- Pengaturan izin per peran

### Pengaturan
- Profil toko (nama, alamat, telepon, logo, footer struk)
- Pengaturan POS (metode pembayaran default, stok negatif)
- Pengaturan printer (printer, ukuran kertas, auto print)

### Pengeluaran & Kas
- Pencatatan pengeluaran operasional
- Manajemen kas harian

---

## Fitur Paket Pro (berlangganan)

- Laporan lanjutan dan ekspor CSV/Excel
- Pelanggan dan riwayat pembelian pelanggan
- Pemasok dan riwayat pembelian pemasok
- Analisis laba
- Cadangan data ke cloud
- Sinkronisasi Google Sheets
- Kasir tak terbatas
- Dashboard lanjutan
- Diskon dan voucher

## Fitur Paket Business (berlangganan)

- Semua fitur Pro
- Multi cabang
- Multi perangkat
- Izin lanjutan
- Sinkronisasi cloud
- Laporan bisnis lanjutan

---

## Batasan yang Diketahui (v1.0.0)

| ID | Area | Deskripsi |
|---|---|---|
| KI-01 | Subscription | Harga paket Pro & Business dikonfigurasi di backend — pastikan backend sudah diset sebelum rilis |
| KI-02 | Play Billing | Pembayaran menggunakan Midtrans — perlu keputusan Play Billing policy sebelum live di Play Store |
| KI-03 | Sync | Sinkronisasi cloud membutuhkan backend aktif di dapur-rasa.com |
| KI-04 | Website | URL dapur-rasa.com harus live sebelum submit |

---

## Catatan Build

```
flutter build appbundle --release --dart-define=ENV=prod

compileSdk  : 36
targetSdk   : 35
minSdk      : 21
versionCode : 1
versionName : 1.0.0
signing     : upload-keystore.jks (PKCS12)
proguard    : aktif (minify + shrink resources)
```

---

## Changelog untuk Play Store (What's New)

```
Rilis pertama Kasir Dapur.

Kasir Dapur adalah aplikasi kasir dan manajemen usaha 
untuk toko retail, warung, dan UMKM Indonesia.

Fitur utama:
- Kasir offline — transaksi tetap berjalan tanpa internet
- Manajemen stok dan inventori
- Laporan penjualan harian dan mingguan
- Scan barcode produk
- Cetak struk ke printer Bluetooth thermal
- Multi kasir dengan izin berbeda
```
