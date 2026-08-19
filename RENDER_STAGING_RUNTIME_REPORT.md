# Render Staging Runtime Report

**Date:** 2026-08-20  
**Status:** BLOCKED — menunggu Git repo + Blueprint deploy  
**API key:** verified (workspace accessible), **not stored in repo**

## Verified via Render API

| Check | Result |
|-------|--------|
| API authentication | OK — workspace `Mas Rizky's workspace` |
| Existing services | 0 (belum ada deploy) |
| Local Docker build | N/A — Docker tidak terinstall di environment ini |

## Deployment package added

- `Dockerfile` — multi-stage Dart 3.13 compile
- `.dockerignore` — exclude Flutter/build artifacts
- `render.yaml` — web service + disk `/data` + env template
- `deploy/env.render.staging.example`
- `RENDER_DEPLOYMENT_GUIDE.md`

## Blockers

1. **No Git remote** — project belum di-push ke GitHub/GitLab; Render deploy membutuhkan repo terhubung.
2. **Blueprint not applied** — service belum dibuat di Render Dashboard.
3. **Secrets not configured** — JWT + Midtrans sandbox keys harus diisi manual di Dashboard.
4. **Custom domain** — `api-staging.dapur-rasa.com` belum DNS → Render.

## Next steps (manual, ~15 min)

1. Push repo ke GitHub (connect GitHub di Render jika belum).
2. Render Dashboard → New → Blueprint → pilih repo.
3. Isi env vars saat prompt (`MIDTRANS_*`, `PUBLIC_BASE_URL`).
4. Tunggu deploy selesai, catat URL `.onrender.com`.
5. Jalankan: `.\scripts\staging_smoke_test.ps1 -BaseUrl "<url>"`
6. Update section di bawah setelah runtime verified.

## Runtime verification (pending)

- [ ] `GET /health` → 200
- [ ] JWT auth flow
- [ ] Tenant isolation
- [ ] Entitlement
- [ ] Midtrans sandbox webhook
- [ ] SQLite persistence across restart

## Security note

API key Render dibagikan di chat — **rotasi key** di [Render Dashboard → API Keys](https://dashboard.render.com/u/settings#api-keys) setelah setup selesai.
