# Backend Kasir Dapur

Kasir, Stok & Laporan Usaha  
PT Dapur Rasa Karya Nusantara · Mas Rizky Iman · [dapur-rasa.com](https://dapur-rasa.com)

Backend ini memegang **Server Key Midtrans**. Aplikasi Flutter tidak boleh berisi secret itu.

## Tanggung jawab

| Modul | Peran |
| --- | --- |
| Autentikasi cloud | Sesi perangkat/akun, terpisah dari PIN lokal |
| Subscription | Paket `FREE` / `PRO_*` / `BUSINESS_*` |
| Entitlement | Hak fitur setelah pembayaran terverifikasi |
| Midtrans | Snap checkout + Get Status |
| Webhook | Notifikasi resmi, idempotent |
| Google Sheets | Ekspor salinan, **bukan** database transaksi |
| Sync | Antrian push/pull; SQLite tetap sumber utama |
| Backup | Snapshot cadangan |
| Audit | Jejak checkout, webhook, aktivasi |

## Alur pembayaran

```text
Flutter
  → POST /v1/billing/checkout          (buat payment pending)
  → Midtrans Snap (token dari backend)
  → Pelanggan membayar
  → Midtrans webhook
       POST /v1/billing/midtrans/notification
  → Backend cek signature + Get Status
  → Subscription + entitlement
  → Flutter GET /v1/billing/subscription
```

Bukti bayar **bukan** callback di aplikasi. Hanya webhook yang sudah diverifikasi.

Status Midtrans yang diproses: `pending`, `settlement`, `capture`, `expire`, `cancel`, `deny`, `failure`.

Hanya `settlement` dan `capture` yang mengaktifkan paket. Notifikasi duplikat mengembalikan HTTP 200 tanpa menambah langganan.

## Lingkungan Midtrans

| `MIDTRANS_ENVIRONMENT` | Snap | API status |
| --- | --- | --- |
| `SANDBOX` | `https://app.sandbox.midtrans.com` | `https://api.sandbox.midtrans.com` |
| `PRODUCTION` | `https://app.midtrans.com` | `https://api.midtrans.com` |

Secret (hanya di `.env` backend):

- `MIDTRANS_SERVER_KEY`
- `MIDTRANS_CLIENT_KEY`
- `MIDTRANS_MERCHANT_ID`

Client Key **tidak** dikirim ke Flutter. Aplikasi memakai Snap token dari backend.

## Setup sandbox

1. Daftar [Midtrans Dashboard](https://dashboard.midtrans.com) → mode **Sandbox**.
2. Buka Settings → Access Keys. Salin Server Key, Client Key, Merchant ID.
3. Di folder `backend/`:

   ```bash
   copy .env.example .env
   ```

   Isi ketiga secret. Jangan commit `.env`.
4. Isi harga integer Rupiah (`PLAN_PRICE_PRO_MONTHLY`, dst). Kosong = checkout ditolak.
5. Jalankan backend:

   ```bash
   dart pub get
   dart run bin/server.dart
   ```

6. Expose HTTPS untuk webhook (contoh ngrok):

   ```text
   https://<host>/v1/billing/midtrans/notification
   ```

   Tempel URL itu di Midtrans Dashboard → Settings → Configuration → Payment Notification URL.
7. Kartu/uji sandbox: [Testing Midtrans](https://docs.midtrans.com/docs/testing-payment-on-sandbox).
8. Flutter tetap memakai `--dart-define=ENV=dev` dan `apiBaseUrl` ke backend ini. **Tanpa** Server Key.

## API klien (Flutter)

- `POST /v1/billing/checkout` `{ business_id, plan_code, client_uuid }`
- `GET /v1/billing/subscription?business_id=`
- `POST /v1/sync/push` `{ business_id, jobs: [{ client_uuid, aggregate, operation, payload }] }`
- `GET /v1/sync/pull?business_id=`
- `GET /v1/sheets/tabs?business_id=` (salinan tab, bukan sumber transaksi)
- `GET /v1/billing/payments?business_id=`
- `POST /v1/billing/midtrans/notification` (hanya Midtrans)

Nominal `amount` di checkout dihitung server. Body klien tidak dipercaya sebagai harga.

## Sinkronisasi (SQLite → Google Sheets)

SQLite di perangkat adalah **database transaksi utama**. Google Sheets hanya salinan untuk laporan, cadangan, pemantauan, dan ekspor.

```text
SQLite
  → tabel sync_queue
  → POST /v1/sync/push
  → tab Google Sheets (salinan)
```

Tab: `Products`, `Transactions`, `TransactionItems`, `StockMovements`, `Expenses`, `Customers`, `DailyReports`.

Idempoten per `client_uuid` (dan id baris): push ulang meng-upsert, tidak menambah baris ganda. Kasir tetap berjalan saat offline; antrian menunggu koneksi.

Jika `GOOGLE_SHEETS_SPREADSHEET_ID` dan `GOOGLE_SHEETS_ACCESS_TOKEN` kosong, backend menyimpan salinan tab di memori proses (untuk tes/pemantauan). Jangan commit `.env`.

## Cadangan cloud

SQLite tetap **database transaksi**. Cadangan adalah salinan ke backend (`POST /v1/backup`).

Isi: `products`, `transactions`, `transaction_items`, `stock`, `stock_movements`, `expenses`, `customers`, `settings`.

- Backup gagal tidak memblokir kasir.
- Restore membutuhkan konfirmasi di aplikasi. Baris ditimpa menurut id; transaksi lokal yang lebih baru tidak dihapus.
- Idempoten per `client_uuid`.

```bash
POST /v1/backup
GET  /v1/backup?business_id=
GET  /v1/backup/{id}?business_id=
```

## Pemeriksaan

```bash
dart test
```
