# Production Smoke Test Plan

Gunakan checklist ini di environment nyata setelah deploy. Jangan menandai VERIFIED jika belum dieksekusi di runtime.

| # | Check | Expected | Status |
|---|---|---|---|
| 1 | `GET /health` | 200 + JSON sehat | NOT VERIFIED |
| 2 | HTTPS certificate | Valid, trusted CA | NOT VERIFIED |
| 3 | HTTP behavior | Redirect ke HTTPS atau ditolak | NOT VERIFIED |
| 4 | Security headers | Header sesuai kebijakan edge | NOT VERIFIED |
| 5 | Auth session endpoint valid credentials | 200 + token | NOT VERIFIED |
| 6 | Login invalid credentials | 401 | NOT VERIFIED |
| 7 | Repeated invalid login | 429 | NOT VERIFIED |
| 8 | Protected endpoint tanpa token | 401 | NOT VERIFIED |
| 9 | Protected endpoint token valid | Success | NOT VERIFIED |
| 10 | FREE ke premium endpoint | 403 | NOT VERIFIED |
| 11 | PRO ke business-only endpoint | 403 | NOT VERIFIED |
| 12 | BUSINESS ke business endpoint | Success | NOT VERIFIED |
| 13 | Cross-business resource access | Denied/empty scoped data | NOT VERIFIED |
| 14 | Checkout amount tampering | Rejected/ignored by server authority | NOT VERIFIED |
| 15 | Duplicate checkout `client_uuid` | Idempotent/safe | NOT VERIFIED |
| 16 | Invalid webhook signature | Denied | NOT VERIFIED |
| 17 | Duplicate webhook | Idempotent | NOT VERIFIED |
| 18 | Backup flow | Sukses sesuai entitlement | NOT VERIFIED |
| 19 | Sync flow | Sukses sesuai entitlement | NOT VERIFIED |
| 20 | Device/branch authorization | Role + entitlement enforced | NOT VERIFIED |
| 21 | APK release ke production API | Mengarah ke endpoint prod HTTPS | NOT VERIFIED |
| 22 | Simulasi APK mod (local entitlement) | Backend tetap authoritative | NOT VERIFIED |

## Catatan Eksekusi

- Isi kolom status dengan: `VERIFIED`, `FAILED`, atau `NOT VERIFIED`.
- Lampirkan timestamp, endpoint, dan bukti log/screenshot untuk tiap item VERIFIED.
