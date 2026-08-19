# Kasir Dapur

Kasir, Stok & Laporan Usaha

Aplikasi kasir Android offline-first untuk UMKM.
Dikembangkan oleh Mas Rizky Iman — PT Dapur Rasa Karya Nusantara.
Situs: https://dapur-rasa.com

Package ID: `com.kasirdapur.app`

## Menjalankan

```bash
flutter pub get
flutter run
```

Lingkungan klien (tanpa secret):

```bash
flutter run --dart-define=ENV=dev
flutter run --dart-define=ENV=staging
flutter run --dart-define=ENV=prod
```

Backend (Midtrans, webhook, langganan cloud) ada di [`backend/README.md`](backend/README.md). Server Key hanya di `backend/.env`, bukan di Flutter.

## Pemeriksaan

```bash
flutter analyze
flutter test
```
