# Panduan Signing — Kasir Dapur

**Aplikasi:** Kasir Dapur  
**Package:** `com.kasirdapur.app`  
**Developer:** Mas Rizky Iman  
**Perusahaan:** PT Dapur Rasa Karya Nusantara

---

## 1. Prasyarat

Pastikan `keytool` tersedia (bagian dari JDK):

```bash
keytool -version
```

Jika belum ada, install JDK 17:

```bash
# Windows (via Winget)
winget install Microsoft.OpenJDK.17

# macOS (via Homebrew)
brew install openjdk@17
```

---

## 2. Buat Upload Keystore (Satu Kali)

> **Penting:** Keystore untuk Google Play disebut *upload key*. Google Play mengelola signing key tersendiri setelah AAB diunggah.

```bash
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -dname "CN=Kasir Dapur, OU=Mobile, O=PT Dapur Rasa Karya Nusantara, L=Jakarta, ST=DKI Jakarta, C=ID"
```

Saat diminta:
- **Store password:** gunakan password kuat (min. 16 karakter)
- **Key password:** boleh sama dengan store password

> **Simpan keystore dan password di tempat aman.** Jika hilang, Anda tidak bisa menerbitkan update ke Google Play.

---

## 3. Buat `android/key.properties`

```bash
# Dari root project:
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:

```properties
storePassword=PASSWORD_STORE_ANDA
keyPassword=PASSWORD_KEY_ANDA
keyAlias=upload
storeFile=../upload-keystore.jks
```

> `key.properties` sudah ada di `.gitignore` — tidak akan ter-commit.

---

## 4. Build Release AAB (Google Play)

```bash
# ⚠️ WAJIB: gunakan --dart-define=ENV=prod untuk mengarahkan ke production API
# Tanpa flag ini, app akan menggunakan api-dev.dapur-rasa.com (development)
flutter build appbundle --release --dart-define=ENV=prod

# Output: build/app/outputs/bundle/release/app-release.aab
```

## 5. Build Release APK (Distribusi Langsung)

```bash
# Split APK per ABI (lebih kecil)
flutter build apk --release --split-per-abi --dart-define=ENV=prod

# Output:
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#   build/app/outputs/flutter-apk/app-x86_64-release.apk

# Universal APK (satu file, lebih besar)
flutter build apk --release
```

---

## 6. Verifikasi Signing

```bash
# Verifikasi AAB
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Verifikasi APK
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Lihat detail keystore
keytool -list -v -keystore android/upload-keystore.jks
```

---

## 7. CI/CD (GitHub Actions / Codemagic)

Jangan commit keystore ke repo. Gunakan environment secrets:

### GitHub Actions

```yaml
# .github/workflows/release.yml
- name: Decode keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/upload-keystore.jks

- name: Write key.properties
  run: |
    cat > android/key.properties <<EOF
    storePassword=${{ secrets.STORE_PASSWORD }}
    keyPassword=${{ secrets.KEY_PASSWORD }}
    keyAlias=upload
    storeFile=../upload-keystore.jks
    EOF

- name: Build AAB
  run: flutter build appbundle --release
```

Secrets yang perlu diset di GitHub:
| Secret | Isi |
|---|---|
| `KEYSTORE_BASE64` | `base64 android/upload-keystore.jks` |
| `STORE_PASSWORD` | Store password keystore |
| `KEY_PASSWORD` | Key password keystore |

---

## 8. Google Play App Signing

Google Play mengelola **app signing key** tersendiri (berbeda dari upload key).

1. Saat pertama upload AAB, aktifkan **Google Play App Signing**
2. Upload key Anda = upload key (yang dibuat di langkah 2)
3. Google Play menyimpan app signing key dengan aman
4. Jika upload key hilang, Anda masih bisa meminta reset ke Google

---

## 9. SDK Versions (Per Google Play Policy)

| Parameter | Nilai | Keterangan |
|---|---|---|
| `minSdk` | 21 | Android 5.0+ (coversekitar 99% perangkat aktif) |
| `targetSdk` | 35 | Android 15 — memenuhi requirement Nov 2025 |
| `compileSdk` | 37 | Harus ≥ targetSdk; permission_handler_android membutuhkan min 37 |

> Google Play mensyaratkan targetSdk ≥ 35 untuk **app baru** yang submit setelah November 2025, dan untuk **update** mulai Agustus 2026.

---

## 10. Catatan Keamanan

- ❌ Jangan commit `key.properties`, `*.jks`, `*.keystore` ke repository
- ❌ Jangan gunakan debug signing untuk release
- ❌ Jangan menyimpan password di kode atau environment variable CI yang tidak terenkripsi
- ✅ Gunakan password manager (Bitwarden, 1Password, dll.)
- ✅ Backup keystore di minimal 2 tempat terpisah
- ✅ Upload key berbeda dari app signing key di Google Play
- ✅ Aktifkan Google Play App Signing sejak upload pertama

---

*Dokumen ini aman untuk di-commit — tidak mengandung credential.*  
*Terakhir diperbarui: 2026 · PT Dapur Rasa Karya Nusantara*
