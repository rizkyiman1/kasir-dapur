# RAILWAY STAGING RUNTIME REPORT

Status saat ini: **BLOCKER**

Alasan utama: deployment runtime ke Railway belum bisa dijalankan dari environment ini karena Railway CLI tidak tersedia dan tidak ada akses dashboard/API Railway terhubung dari Cursor.

## Runtime verification matrix

| AREA | STATUS | EVIDENCE | RESULT |
|------|--------|----------|--------|
| Railway deployment | BLOCKER | `railway --version` / `railway status` -> command not found | Deploy belum bisa dijalankan dari Cursor |
| HTTPS | NOT VERIFIED | URL Railway belum tersedia dari deployment aktif | Belum bisa diuji |
| Health | NOT VERIFIED | `/health` belum bisa di-hit pada service live Railway | Belum bisa diverifikasi |
| JWT | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| Authorization | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| Business isolation | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| IDOR | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| Premium entitlement | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| Rate limit | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| Input validation | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| Error leakage | NOT VERIFIED | Runtime endpoint belum tersedia | Belum bisa diuji |
| SQLite persistence | NOT VERIFIED | Volume Railway belum terpasang di service aktif | Belum bisa diuji |
| Midtrans sandbox | NOT VERIFIED | Webhook staging belum live | Belum bisa diuji |
| Flutter -> API | NOT VERIFIED | API staging Railway belum live | Belum bisa diuji |
| Backup | NOT VERIFIED | Endpoint live belum tersedia | Belum bisa diuji |
| Sync | NOT VERIFIED | Endpoint live belum tersedia | Belum bisa diuji |
| APK staging | NOT VERIFIED | URL staging live belum ada | Belum bisa diuji |

## GO-LIVE BLOCKERS

1. **Railway access blocker**: CLI Railway tidak terinstall di environment ini (`railway` command not found) dan tidak ada sesi dashboard Railway yang bisa dikendalikan dari Cursor.
2. **Runtime URL blocker**: belum ada URL deployment Railway live yang dapat diuji.
3. **Secrets/runtime config blocker**: variabel staging di Railway (JWT/Midtrans sandbox/BILLING_SQLITE_PATH) belum dapat diverifikasi runtime karena service belum terdeploy dari environment ini.

## NEXT ACTION

1. Deploy service via Railway Dashboard (atau beri akses Railway CLI/API ke environment ini).
2. Set Railway Variables sesuai `deploy/env.railway.staging.example`.
3. Pasang Railway Volume mount `/data` dan set `BILLING_SQLITE_PATH=/data/billing.db`.
4. Setelah deploy sukses, kirim **Railway public URL** (atau custom domain aktif `api-staging.dapur-rasa.com`).
5. Jalankan ulang tahap runtime verification + smoke test end-to-end.

## Catatan integritas arsitektur

- Tidak ada perubahan arsitektur billing/payment.
- SQLite tetap authority billing.
- Midtrans tetap authority payment.
- JWT business isolation tetap dipertahankan.
- Pricing/subscription matrix tidak diubah.
