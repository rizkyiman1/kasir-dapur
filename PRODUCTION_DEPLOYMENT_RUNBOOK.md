# Production Deployment Runbook — Kasir Dapur

Dokumen ini hanya berisi requirement deployment yang **dapat diverifikasi dari repository** dan kebijakan runtime yang wajib di edge/proxy. Tidak mengarang konfigurasi Nginx/Cloudflare spesifik.

## Arsitektur Target

```
Client (Flutter APK) → HTTPS → Edge (TLS termination) → Backend API (Shelf/Dart)
                                              ↘ Midtrans webhook (public endpoint)
```

## 1) HTTPS (Wajib)

- Flutter production **wajib** `--dart-define=ENV=prod` → `https://api.dapur-rasa.com`.
- HTTP publik harus **redirect ke HTTPS** atau **ditutup** di edge.
- Backend process (`bin/server.dart`) boleh HTTP internal **hanya** jika berada di trusted network/private subnet di belakang reverse proxy.
- Jangan expose port backend langsung ke internet tanpa TLS termination.

## 2) HSTS (Edge)

Untuk domain production HTTPS:

- Set `Strict-Transport-Security` di edge/reverse proxy.
- `includeSubDomains` hanya jika semua subdomain memang HTTPS-only.
- **Jangan** aktifkan HSTS preload tanpa audit domain penuh.

## 3) Security Headers (Edge/API)

Untuk API JSON:

- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: no-referrer` (atau kebijakan setara)
- CSP **tidak wajib** untuk pure JSON API.

## 4) Trusted Proxy (Backend)

Topology:

```
Client → CDN/LB/Reverse Proxy → Backend
```

Aturan backend (`.env`):

- Default aman: `TRUST_PROXY_HEADERS=false`
- Aktifkan `TRUST_PROXY_HEADERS=true` **hanya** jika backend benar-benar di belakang proxy tepercaya.
- `TRUSTED_PROXY_IPS` harus berisi IP peer proxy yang benar-benar terlihat backend.
- **Jangan** gunakan `0.0.0.0/0`.
- Jangan percaya `X-Forwarded-For` hanya karena header ada.

## 5) Rate Limit Architecture

### Single Instance (MVP production)

- In-memory limiter backend **acceptable** untuk deployment awal single instance.
- Caveat: quota reset saat restart process.
- Wajib tetap: auth brute-force endpoint `/v1/auth/cloud/session` menghasilkan `429`.

### Multi Instance (Horizontal scaling)

- In-memory limiter **TIDAK cukup**.
- Wajib distributed limiter (Redis/shared store atau rate limit di edge) **sebelum** scale horizontal.

## 6) Secret & Env Production

Checklist (tanpa menulis secret ke repo):

- [ ] `JWT_SECRET` random kuat (min 32+ chars)
- [ ] `MIDTRANS_SERVER_KEY` hanya backend env/secret manager
- [ ] Midtrans secret **tidak** masuk Flutter/APK
- [ ] `.env` tetap ignored git
- [ ] Startup production: `ENFORCE_PRODUCTION_SECRETS=true`
- [ ] Startup gagal jika secret kosong/placeholder (hanya sebut nama variable, bukan nilai)
- [ ] Tidak print secret di log/crash report
- [ ] Prosedur rotasi secret terdokumentasi operasional

### Rotasi Secret (Operasional)

1. Generate secret baru di secret manager.
2. Deploy backend dengan secret baru (rolling restart single instance).
3. Invalidate sesi lama (JWT lama otomatis invalid setelah secret diganti).
4. Verifikasi auth/checkout/webhook smoke test.
5. Revoke secret lama.

## 7) Android Release Signing

- Release build **wajib** `android/key.properties` + keystore valid.
- Tanpa keystore/config valid → build release **gagal** (tidak fallback debug).
- Keystore/password **tidak** di-commit.

Validasi lokal:

```powershell
# Harus gagal tanpa key.properties
Move-Item android\key.properties android\key.properties.bak
flutter build appbundle --release --dart-define=ENV=prod
Move-Item android\key.properties.bak android\key.properties
```

## 8) Pre-Deploy Gate

Lihat `PRODUCTION_RELEASE_CHECKLIST.md` dan `PRODUCTION_SMOKE_TEST_PLAN.md`.
