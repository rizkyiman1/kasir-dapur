# Security Overview — Kasir Dapur

**App:** Kasir Dapur  
**Package:** com.kasirdapur.app  
**Developer:** Mas Rizky Iman — PT Dapur Rasa Karya Nusantara

> Dokumen ini merangkum postur keamanan Kasir Dapur untuk keperluan release.  
> Dokumen lengkap ada di `SECURITY.md` di root proyek.  
> Dokumen ini tidak memuat secret, API key, atau credentials.

---

## Ringkasan Keamanan

| Area | Status | Keterangan |
|---|---|---|
| Secret di kode client | ✅ Aman | Tidak ada secret di `lib/`, `assets/`, atau APK/AAB |
| PIN hashing | ✅ Aman | PBKDF2-HMAC-SHA256, random salt 16 byte |
| HTTPS enforced | ✅ Aman | `network_security_config.xml` — cleartext diblokir |
| Midtrans Server Key | ✅ Aman | Hanya di backend, tidak pernah ada di client |
| Log sanitization | ✅ Aman | `AppLogger` menyensor pin, password, secret, token, key |
| Backup exclusion | ✅ Aman | `data_extraction_rules.xml` — DB tidak masuk cloud backup Android |
| ProGuard/R8 | ✅ Aktif | `isMinifyEnabled = true`, `isShrinkResources = true` |
| `allowBackup` | ✅ Nonaktif | `android:allowBackup="false"` di manifest |
| Role-based access | ✅ Aman | `PermissionGuard` + `Guarded*Repository` di setiap layer |

---

## Arsitektur Pembayaran

```
[App Flutter]  ──── HTTPS ────▶  [Backend Kasir Dapur]
                                        │
                                        │ Server Key (tidak pernah ke client)
                                        ▼
                                   [Midtrans API]
                                        │
                                        │ Snap URL
                                        ▼
                                  [Browser eksternal]
                                  (pengguna bayar di sini)
                                        │
                                        │ Webhook
                                        ▼
                               [Backend verifikasi]
                                        │
                                        ▼
                               [App update status lokal]
```

**Midtrans credentials yang digunakan:**
- Client Key: ada di app (hanya untuk referensi — tidak dikirim ke Midtrans langsung dari Flutter)
- Server Key: **hanya di backend** — tidak pernah ada di kode Flutter atau bundle APK/AAB

---

## Data yang Disimpan Lokal (SQLite)

| Data | Enkripsi | Dapat Dihapus |
|---|---|---|
| PIN pengguna | Ya — PBKDF2 hash + salt | Ya — hapus akun |
| Data produk | Tidak (SQLite plaintext) | Ya — clear data Android |
| Data transaksi | Tidak (SQLite plaintext) | Ya — clear data Android |
| Setting app | Tidak (SQLite plaintext) | Ya — clear data Android |

> Data SQLite disimpan di storage internal app (`/data/data/com.kasirdapur.app/`).  
> Tidak dapat diakses oleh app lain tanpa root.

---

## Data yang Dikirim ke Server

| Data | Tujuan | Enkripsi |
|---|---|---|
| Device UUID | Verifikasi subscription | HTTPS |
| Business ID | Sinkronisasi & backup | HTTPS |
| Order ID | Konfirmasi pembayaran | HTTPS |
| Data transaksi (sync) | Google Sheets via backend | HTTPS |
| Data backup | Cadangan cloud | HTTPS |

**Tidak pernah dikirim:** PIN, nama pengguna, kontak, lokasi.

---

## Permissions Android

| Permission | Alasan | Wajib? |
|---|---|---|
| `INTERNET` | Sync, subscription, backup | Ya |
| `ACCESS_NETWORK_STATE` | Deteksi offline | Ya |
| `BLUETOOTH` / `BLUETOOTH_ADMIN` | Printer thermal (API ≤30) | Tidak (opsional) |
| `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` | Printer thermal (API 31+) | Tidak (opsional) |
| `CAMERA` | Scan barcode | Tidak (opsional) |

Semua `uses-feature` di manifest menggunakan `android:required="false"` — app berjalan tanpa Bluetooth dan kamera.

---

## Vulnerability Disclosure

Jika menemukan celah keamanan di Kasir Dapur:

- Email: privacy@dapur-rasa.com
- Subject: `[SECURITY] Nama Temuan`
- Jangan publish temuan sebelum ada respons dari tim (responsible disclosure)

---

*Dokumen ini tidak memuat Midtrans Server Key, API secret, keystore password, atau credentials aktual.*  
*Lihat `SECURITY.md` di root proyek untuk panduan keamanan lengkap.*
