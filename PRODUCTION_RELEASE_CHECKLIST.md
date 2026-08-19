# Production Release Checklist

Checklist ini adalah gate minimum sebelum go-live. Jalankan berurutan dan jangan lanjut jika ada item gagal.

## 1) Backend Gate

- [ ] `cd backend && dart analyze`
- [ ] `cd backend && dart test`
- [ ] `ENFORCE_PRODUCTION_SECRETS=true` di environment production
- [ ] Startup backend berhasil dengan:
  - [ ] `JWT_SECRET` valid
  - [ ] `MIDTRANS_SERVER_KEY` valid
  - [ ] `MIDTRANS_CLIENT_KEY` valid
  - [ ] `MIDTRANS_MERCHANT_ID` valid
- [ ] `TRUST_PROXY_HEADERS` sesuai topology deploy (default `false`)
- [ ] Jika `TRUST_PROXY_HEADERS=true`, `TRUSTED_PROXY_IPS` berisi peer proxy aktual

## 2) Flutter Gate

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Build debug tetap sukses:
  - [ ] `flutter build apk --debug`
- [ ] Build release tidak boleh fallback ke debug signing:
  - [ ] tanpa `android/key.properties` -> release build gagal dengan pesan jelas
  - [ ] dengan `android/key.properties` valid -> release build sukses
- [ ] Build release target production:
  - [ ] `flutter build appbundle --release --dart-define=ENV=prod`

## 3) Security Gate

- [ ] Tidak ada secret production di git (`.env`, keystore, key file, token)
- [ ] Endpoint protected tanpa token -> `401`
- [ ] Token invalid/expired/wrong issuer -> `401`
- [ ] FREE -> endpoint premium -> `403`
- [ ] PRO -> endpoint business-only -> `403`
- [ ] BUSINESS -> endpoint business -> sukses
- [ ] Cross-business access -> denied
- [ ] Midtrans webhook invalid signature -> denied
- [ ] Midtrans webhook duplicate -> idempotent

## 4) Deployment Gate (Runtime)

- [ ] API publik hanya HTTPS
- [ ] HTTP ditutup atau redirect di edge
- [ ] Security headers di edge:
  - [ ] `Strict-Transport-Security`
  - [ ] `X-Content-Type-Options: nosniff`
- [ ] Monitoring/logging aktif tanpa bocor secret
- [ ] Backup/rollback plan tersedia

## 5) Go/No-Go Decision

- **READY FOR STAGING**: semua gate source-level pass, runtime belum lengkap.
- **READY FOR PRODUCTION**: semua gate source-level + runtime pass.
- **BLOCKED**: ada gate High/Critical gagal.
