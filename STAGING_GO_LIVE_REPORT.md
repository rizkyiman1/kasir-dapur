# STAGING GO-LIVE REPORT — Kasir Dapur (Tahap 3.8)

**Tanggal:** 2026-08-20  
**Target:** `https://api-staging.dapur-rasa.com`  
**Verdict:** **ACCESS BLOCKED — deployment not started**

---

## Tahap 3.8 — Phase 1 verify access

Anda menyatakan infra **akan disediakan**, tetapi nilai aktual **belum tersedia** di environment Cursor saat verifikasi.

| # | Check | Status | Evidence |
|---|---|---|---|
| 1 | SSH berhasil | **BLOCKED** | Tidak ada host/user/key; `STAGING_SSH_HOST=unset` |
| 2 | OS / architecture | **BLOCKED** | Tidak ada koneksi VPS |
| 3 | RAM / disk | **BLOCKED** | Tidak ada koneksi VPS |
| 4 | User sudo | **BLOCKED** | Tidak ada koneksi VPS |
| 5 | DNS `api-staging.dapur-rasa.com` | **BLOCKED** | `nslookup` → **Non-existent domain** |
| 6 | Port 80/443 | **NOT VERIFIED** | VPS tidak reachable |
| 7 | Dart availability | **NOT VERIFIED** | Perlu SSH ke VPS |
| 8 | nginx availability | **NOT VERIFIED** | Perlu SSH ke VPS |

**Public probe:**
```
curl https://api-staging.dapur-rasa.com/health → Could not resolve host
STAGING_VPS_IP=unset
STAGING_SSH_HOST=unset
```

**Phase 1 result:** **STOP — ACCESS BLOCKED**

Phases 2–14 **tidak dijalankan** (provision, build, env, systemd, nginx, smoke test, Midtrans, Flutter, backup).

---

## Status matrix (unchanged from 3.7 — runtime not executed)

| Area | Status |
|---|---|
| VPS | **BLOCKED** |
| DNS | **BLOCKED** |
| TLS / nginx | **NOT VERIFIED** |
| Backend live | **NOT VERIFIED** |
| systemd | **NOT VERIFIED** |
| SQLite on VPS | **NOT VERIFIED** |
| Staging secrets on server | **BLOCKED** |
| Auth / isolation / entitlement (runtime) | **NOT VERIFIED** |
| Midtrans sandbox (runtime) | **NOT VERIFIED** |
| Flutter → staging API | **NOT VERIFIED** |
| Backup/restore (runtime) | **NOT VERIFIED** |

---

## GO / NO-GO

### **NO-GO — STAGING NOT LIVE**

Bukan karena kualitas source, melainkan **akses deploy belum diberikan**.

---

## Minimum data required to proceed (please provide)

Isi placeholder yang Anda sebutkan di Tahap 3.8:

### A. SSH (wajib)

```
STAGING_SSH_HOST=<VPS_IP_or_hostname>
STAGING_SSH_USER=<user>          # prefer non-root with sudo
STAGING_SSH_PORT=22              # optional
```

Metode auth (pilih satu):
- SSH private key path di mesin ini, **atau**
- Cursor Remote SSH sudah terhubung ke VPS, **atau**
- Password via secure channel (kurang disarankan)

### B. DNS (wajib sebelum HTTPS public)

```
api-staging.dapur-rasa.com  A/AAAA  →  <VPS_IP>
```

Konfirmasi setelah propagate: `nslookup api-staging.dapur-rasa.com` resolves.

### C. Secrets on server only (jangan paste ke repo/chat jika bisa dihindari)

Buat di VPS: `/etc/dapur-kasir/backend.env` (chmod 600) dari `deploy/env.staging.example`:

- `JWT_SECRET` (staging, min 32 chars)
- `MIDTRANS_SERVER_KEY` / `MIDTRANS_CLIENT_KEY` / `MIDTRANS_MERCHANT_ID` (sandbox)
- `ENFORCE_PRODUCTION_SECRETS=true`
- `PUBLIC_BASE_URL=https://api-staging.dapur-rasa.com`
- `BILLING_SQLITE_PATH=/var/lib/dapur-kasir/billing.db`
- `TRUST_PROXY_HEADERS=true`
- `TRUSTED_PROXY_IPS=127.0.0.1`

**Alternatif:** Anda isi file di VPS sendiri; Cursor hanya butuh konfirmasi file sudah ada (tanpa menampilkan nilai).

### D. Dummy test users (wajib untuk smoke test)

```
STAGING_USER_A=<user-id>   PIN=<pin>
STAGING_USER_B=<user-id>   PIN=<pin>   # optional, isolation
```

Catatan: Backend `UserStore` in-memory — user harus **didaftarkan di server** (via seed script atau endpoint yang Anda setup). Jika belum ada mekanisme register di production deploy, beri tahu agar kami seed minimal test users tanpa mengubah billing architecture.

---

## What happens immediately after access is granted

1. SSH → provision `dapur-kasir`, dirs, firewall  
2. Upload `backend/` → `bash deploy/build-linux.sh`  
3. systemd → `curl http://127.0.0.1:8080/health` = 200  
4. nginx + certbot → public HTTPS health = 200  
5. `scripts/staging_smoke_test.ps1` + extended tests  
6. Midtrans sandbox webhook  
7. Flutter `--dart-define=ENV=staging` device test  
8. Update this report with **VERIFIED** / **FAILED** + evidence  

---

## Ready without deployment (no re-audit)

| Item | Status |
|---|---|
| Source + tests | **READY** (prior tahap) |
| `deploy/` package | **READY** |
| Smoke script | **READY** |
| Checklists / runbooks | **READY** |

---

## Important

- **No source code changes** in Tahap 3.8 (blocked on access).  
- **No fake staging deployed** claim.  
- Kirim **VPS IP + SSH + konfirmasi DNS** (dan test users) → deployment langsung dilanjutkan dari Phase 2.

**Status:** **WAITING FOR ACCESS** — siap deploy begitu data di atas tersedia.
