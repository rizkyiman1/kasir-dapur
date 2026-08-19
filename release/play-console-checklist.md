# Play Console Checklist — Kasir Dapur

**App:** Kasir Dapur  
**Package:** com.kasirdapur.app  
**Developer:** Mas Rizky Iman — PT Dapur Rasa Karya Nusantara  
**Versi:** 1.0.0+1

Gunakan checklist ini sebelum setiap submit ke Google Play Console.

---

## A. PRA-BUILD

- [ ] `versionCode` di-increment dari versi sebelumnya (`pubspec.yaml`)
- [ ] `versionName` diperbarui jika ada perubahan versi
- [ ] `flutter clean && flutter pub get` dijalankan
- [ ] Build menggunakan: `flutter build appbundle --release --dart-define=ENV=prod`
- [ ] File AAB ada di `build/app/outputs/bundle/release/app-release.aab`
- [ ] AAB tidak di-build dengan debug signing
- [ ] `flutter analyze` tidak ada errors
- [ ] `flutter test` semua passed

---

## B. STORE LISTING

- [ ] **App name:** `Kasir Dapur` (maks 50 karakter)
- [ ] **Short description:** ≤80 karakter, tidak ada klaim berlebihan
- [ ] **Full description:** ≤4.000 karakter, akurat, tidak ada fitur fiktif
- [ ] **Category:** Business
- [ ] **App icon:** 512×512 PNG, konten dalam safe zone
- [ ] **Feature graphic:** 1024×500 JPG/PNG, tidak ada CTA atau harga
- [ ] **Screenshots phone:** minimal 2, disarankan 6–8
- [ ] **Contact email:** `support@dapur-rasa.com` (aktif)
- [ ] **Developer website:** `https://dapur-rasa.com` (aktif)

---

## C. APP CONTENT (Policy)

- [ ] **Privacy policy URL:** `https://dapur-rasa.com/privacy` — dapat diakses publik
- [ ] **Data safety:** semua field diisi sesuai `data-safety.md` dalam folder ini
- [ ] **Content rating:** kuesioner IARC diselesaikan — hasil: Everyone
- [ ] **Target audience:** 18 and over
- [ ] **Ads:** No ads
- [ ] **App access:** instruksi reviewer diisi (onboarding + buat PIN)

---

## D. SUBSCRIPTION & BILLING

- [ ] Harga paket Pro dan Business sudah dikonfigurasi di backend
- [ ] Alur upgrade subscription bisa diuji oleh reviewer tanpa error
- [ ] Keputusan Google Play Billing policy sudah final (lihat BLOCKER B-03 di `PLAY_STORE_AUDIT.md`)

---

## E. CLOSED TESTING (Syarat Akun Baru)

- [ ] Closed testing track sudah diaktifkan
- [ ] Minimal 20 tester opt-in via link Play Console
- [ ] Program berjalan minimal 14 hari kalender
- [ ] Crash rate < 1% di Android Vitals
- [ ] ANR rate < 0.47% di Android Vitals
- [ ] Feedback dari tester sudah dikumpulkan

---

## F. SEBELUM SUBMIT KE PRODUCTION

- [ ] Semua section di Play Console menampilkan status hijau/complete
- [ ] Tidak ada warning merah di release dashboard
- [ ] AAB production di-build ulang (bukan AAB yang sama dengan closed testing)
- [ ] Production AAB diverifikasi: applicationId, versionCode, versionName, targetSdk
- [ ] Privacy policy URL live dan dapat diakses
- [ ] Website dapur-rasa.com live dan dapat diakses
- [ ] Support email aktif dan dimonitor

---

## G. SETELAH LIVE

- [ ] Pantau crash rate hari pertama (target < 1%)
- [ ] Pantau ANR rate hari pertama (target < 0.47%)
- [ ] Baca dan balas ulasan pertama dari pengguna
- [ ] Siapkan hotfix build jika ditemukan bug kritis
- [ ] Increment `versionCode` untuk update berikutnya

---

## ITEM YANG TIDAK BOLEH ADA

| Item | Keterangan |
|---|---|
| Midtrans Server Key di kode client | Harus di backend saja |
| Hardcoded API secret | Harus via dart-define atau backend |
| Debug signing di production build | Selalu gunakan upload keystore |
| Placeholder harga (`null`) di UI subscription | Harus diisi sebelum live |
| URL yang tidak aktif di privacy policy | Harus bisa dibuka sebelum submit |
| Klaim fitur yang belum tersedia | Deskripsi harus sesuai fitur aktual |
