# Deployment Guide — Kasir Dapur

**App:** Kasir Dapur  
**Package:** com.kasirdapur.app  
**Developer:** Mas Rizky Iman — PT Dapur Rasa Karya Nusantara  
**Website:** https://dapur-rasa.com

---

## Urutan Deployment

```
[1] Selesaikan BLOCKER
    ↓
[2] Build Production AAB
    ↓
[3] Closed Testing (14 hari, 20 tester)
    ↓
[4] Apply Production Access
    ↓
[5] Submit ke Production
    ↓
[6] Monitor & Hotfix
```

---

## Langkah 1 — Selesaikan BLOCKER

Sebelum build production, selesaikan semua blocker dari `PLAY_STORE_AUDIT.md`:

| ID | BLOCKER | Status |
|---|---|---|
| B-01 | Isi `priceRupiah` di `subscription_config.dart` | ⬜ |
| B-02 | Build dengan `--dart-define=ENV=prod` | ⬜ |
| B-03 | Keputusan Google Play Billing policy | ⬜ |

---

## Langkah 2 — Build Production AAB

```powershell
# Di direktori proyek D:\Kasir Dapur
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=ENV=prod
```

**Output:** `build\app\outputs\bundle\release\app-release.aab`

**Salin ke folder release:**
```powershell
Copy-Item "build\app\outputs\bundle\release\app-release.aab" "release\kasir-dapur.aab"
```

**Verifikasi:**
```powershell
Get-Item "release\kasir-dapur.aab" | Select-Object Name, Length, LastWriteTime
```

AAB yang valid berukuran antara 15–50 MB untuk app Flutter.

---

## Langkah 3 — Closed Testing

1. Upload `release\kasir-dapur.aab` ke **Closed testing track** di Play Console
2. Buat email list dengan 20+ tester
3. Bagikan opt-in URL ke tester
4. Tunggu minimal 14 hari dengan ≥20 active installs
5. Pantau crash rate dan ANR di Android Vitals

Panduan detail: `CLOSED_TESTING_GUIDE.md`

---

## Langkah 4 — Apply Production Access

Setelah syarat closed testing terpenuhi:
1. Buka Play Console → Production → Release dashboard
2. Klik **Apply for production access**
3. Isi formulir (deskripsi singkat tentang app dan target pengguna)
4. Tunggu review Google: 2–7 hari kerja
5. Notifikasi via email developer

---

## Langkah 5 — Submit ke Production

Setelah production access diberikan:

1. Build **ulang** production AAB (jangan reuse AAB closed testing)
2. Increment `versionCode` jika ada perubahan sejak closed testing
3. Upload AAB baru ke Production track
4. Isi release notes (What's new in Bahasa Indonesia)
5. Start rollout: mulai **10–20%** untuk rilis pertama

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

---

## Langkah 6 — Monitor & Hotfix

### Pantau Setelah Live

| Metrik | Target | Lokasi di Play Console |
|---|---|---|
| Crash rate | < 1% | Android vitals → Crash rate |
| ANR rate | < 0.47% | Android vitals → ANR rate |
| Rating | ≥ 4.0 | Ratings and reviews |
| Install | Pantau tren | Statistics |

### Eskalasi Rollout

```
Hari 1–2:  10% — pantau crash rate
Hari 3–5:  25% — jika stabil
Hari 6–7:  50%
Hari 8+:   100%
```

### Prosedur Hotfix

Jika crash rate > 2% dalam 24 jam pertama:
1. **Hentikan rollout** segera di Play Console → Production → Halt rollout
2. Analisis crash di Android Vitals
3. Perbaiki di kode, increment `versionCode`
4. Build ulang dengan `--dart-define=ENV=prod`
5. Upload ke Production, resume rollout setelah verifikasi

---

## Increment Version untuk Update Berikutnya

Di `pubspec.yaml`:
```yaml
# Sebelum:
version: 1.0.0+1

# Setelah (contoh update):
version: 1.0.1+2
```

Format: `versionName+versionCode`
- `versionName` mengikuti semantic versioning (1.0.0, 1.0.1, 1.1.0, 2.0.0)
- `versionCode` selalu increment, tidak pernah turun

---

## Backend yang Harus Aktif Sebelum Production

| Service | URL | Diperlukan untuk |
|---|---|---|
| Health check | `https://api.dapur-rasa.com/health` | Deteksi konektivitas |
| Subscription verify | `https://api.dapur-rasa.com/v1/subscription/current` | Verifikasi paket |
| Checkout | `https://api.dapur-rasa.com/v1/subscription/checkout` | Upgrade paket |
| Sync push | `https://api.dapur-rasa.com/v1/sync/push` | Sinkronisasi cloud |
| Backup | `https://api.dapur-rasa.com/v1/backup/*` | Cadangan cloud |
| Privacy policy | `https://dapur-rasa.com/privacy` | Play Store requirement |
| Website | `https://dapur-rasa.com` | Play Console contact |

---

## Checklist Final Sebelum Setiap Rilis

- [ ] `versionCode` di-increment
- [ ] `flutter clean && flutter pub get` dijalankan
- [ ] `flutter test` semua passed
- [ ] `flutter analyze` tidak ada errors
- [ ] Build dengan `--dart-define=ENV=prod`
- [ ] AAB disalin ke `release/kasir-dapur.aab`
- [ ] Semua BLOCKER diselesaikan

---

*Dokumen ini tidak memuat password, API secret, atau credentials aktual.*
