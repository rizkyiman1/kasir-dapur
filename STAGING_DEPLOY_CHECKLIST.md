# Staging Deploy Checklist — Kasir Dapur

Gunakan checklist ini saat VPS + DNS + secrets sudah tersedia.  
Smoke test script: `scripts/staging_smoke_test.ps1`

---

## Phase A — Server provision

- [ ] **1. Provision VPS** (Linux x64, 1+ vCPU, 1–2 GB RAM, persistent disk)
- [ ] **2. Create non-root user** `dapur-kasir` (system user)
- [ ] **3. Install Dart SDK** ^3.13.0 + curl + nginx (or Caddy)
- [ ] **4. Upload backend** to `/opt/dapur-kasir/backend`
- [ ] **5. Create SQLite path** `/var/lib/dapur-kasir` owned by `dapur-kasir`

## Phase B — Backend configuration

- [ ] **6. Configure secrets** — copy `deploy/env.staging.example` → `/etc/dapur-kasir/backend.env`
  - [ ] `JWT_SECRET` (staging, strong)
  - [ ] Midtrans **sandbox** keys
  - [ ] `ENFORCE_PRODUCTION_SECRETS=true`
  - [ ] `PUBLIC_BASE_URL=https://api-staging.dapur-rasa.com`
  - [ ] `BILLING_SQLITE_PATH=/var/lib/dapur-kasir/billing.db`
  - [ ] `TRUST_PROXY_HEADERS=true`, `TRUSTED_PROXY_IPS=127.0.0.1`
- [ ] **7. Build binary** — `bash deploy/build-linux.sh`
- [ ] **8. Install systemd** — `deploy/dapur-kasir-backend.service.example`
- [ ] **9. Start backend** — `systemctl enable --now dapur-kasir-backend`

## Phase C — Local verification

- [ ] **10. Check localhost health** — `curl http://127.0.0.1:8080/health` → 200, `ok:true`
- [ ] **11. Check logs** — `journalctl -u dapur-kasir-backend -f` (no secrets printed)

## Phase D — Public edge

- [ ] **12. Configure DNS** — `api-staging.dapur-rasa.com` → VPS IP (A/AAAA)
- [ ] **13. Configure TLS** — Let's Encrypt or trusted cert
- [ ] **14. Configure reverse proxy** — `deploy/reverse-proxy.nginx.example.conf`
- [ ] **15. Check public HTTPS** — `curl https://api-staging.dapur-rasa.com/health`

## Phase E — Smoke tests

- [ ] **16. Run smoke script** — `scripts/staging_smoke_test.ps1`
- [ ] **17. Test auth** — valid/invalid/429/token/protected
- [ ] **18. Test tenant isolation** — User A vs User B
- [ ] **19. Test entitlement** — FREE/PRO/BUSINESS matrix
- [ ] **20. Test Midtrans sandbox** — checkout + webhook (no real money)
- [ ] **21. Test backup/sync** — with Bearer token + entitlement
- [ ] **22. Test APK** — `--dart-define=ENV=staging`, login, subscription read

## Phase F — Evidence & decision

- [ ] **23. Record evidence** — update `STAGING_DEPLOYMENT_REPORT.md`
- [ ] **24. Decide** — READY FOR PRODUCTION CANDIDATE / BLOCKED / WAITING

---

## Security gates (must pass)

- [ ] Backend **not** running as root
- [ ] Port 8080 **not** publicly exposed (firewall allows 80/443 only)
- [ ] SQLite **not** exposed to network
- [ ] `/etc/dapur-kasir/backend.env` mode **600**
- [ ] No secrets in git
- [ ] `ENFORCE_PRODUCTION_SECRETS=true` active
- [ ] Midtrans sandbox only on staging

---

## Staging domain plan

| Item | Target |
|---|---|
| API hostname | `api-staging.dapur-rasa.com` |
| DNS | A/AAAA → `<VPS_IP>` |
| TLS | Let's Encrypt (certbot) or provider cert |
| Backend upstream | `127.0.0.1:8080` |
| Midtrans notification | `https://api-staging.dapur-rasa.com/v1/billing/midtrans/notification` |

---

## Rollback

1. Stop service
2. Restore previous binary + restore SQLite backup (see `DEPLOYMENT_BACKUP_RUNBOOK.md`)
3. Restart + health check
