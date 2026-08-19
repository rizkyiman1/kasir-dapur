# Signing Guide — Kasir Dapur

**Package:** com.kasirdapur.app  
**Developer:** Mas Rizky Iman — PT Dapur Rasa Karya Nusantara

> Dokumen ini menjelaskan konfigurasi signing tanpa memuat password, secret, atau kredensial aktual.  
> Lihat `android/SIGNING.md` di source code untuk panduan teknis lengkap.

---

## File Signing yang Dibutuhkan

| File | Lokasi | Di-commit? | Keterangan |
|---|---|---|---|
| `upload-keystore.jks` | `android/` | ❌ Tidak | Keystore PKCS12 untuk signing |
| `key.properties` | `android/` | ❌ Tidak | Password & alias keystore |
| `key.properties.example` | `android/` | ✅ Ya | Template tanpa nilai sensitif |

> **Penting:** Keystore dan `key.properties` tidak boleh ada di repository.  
> Kedua file ini ada di `.gitignore`.

---

## Setup Signing untuk Build Baru

1. Pastikan `android/upload-keystore.jks` ada di mesin build
2. Buat `android/key.properties` dari `android/key.properties.example`
3. Isi nilai yang sesuai di `key.properties` (tanpa tanda petik):
   ```
   storePassword=<password keystore>
   keyPassword=<password key>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```
4. Jalankan build:
   ```powershell
   flutter build appbundle --release --dart-define=ENV=prod
   ```

---

## Verifikasi Signing

Gunakan `apksigner` atau `jarsigner` untuk verifikasi:

```powershell
# Cek signing info dari AAB (via bundletool)
java -jar bundletool.jar validate --bundle=release\kasir-dapur.aab
```

Atau cek via Play Console → App signing → Upload key certificate.

---

## Backup Keystore

> **Kehilangan keystore = tidak bisa update app di Play Store.**

Backup keystore ke minimal 2 lokasi terpisah:
- Password manager (Bitwarden, 1Password, dll.)
- Cloud storage terenkripsi (Google Drive dengan enkripsi lokal)
- Storage fisik (USB terenkripsi)

Jangan simpan di:
- Repository Git
- Email tanpa enkripsi
- Chat (WhatsApp, Telegram)

---

## Informasi Keystore (Non-Sensitif)

| Field | Nilai |
|---|---|
| Format | PKCS12 |
| Key alias | `upload` |
| Validity | 10.000 hari (~27 tahun) |
| Key algorithm | RSA 2048 |
| Signature algorithm | SHA256withRSA |
| Common Name (CN) | Mas Rizky Iman |
| Organization (O) | PT Dapur Rasa Karya Nusantara |
| Country (C) | ID |

---

## Google Play App Signing

Google Play menggunakan **Google-managed app signing**.  
AAB yang diupload di-re-sign oleh Google dengan kunci yang mereka kelola.  
Keystore upload digunakan hanya untuk **autentikasi upload** ke Play Console.

Ini berarti:
- Jika keystore upload hilang, Play Console dapat melakukan **key reset** dengan proses verifikasi identitas
- APK yang diunduh pengguna di-sign dengan kunci Google, bukan kunci upload

---

*Dokumen ini tidak memuat password, secret, atau credential aktual.*
