# Deploy — Kasir Dapur Backend (MVP Single VPS)

## Quick start (Linux VPS)

```bash
# 1. As user with sudo — create service user
sudo useradd --system --home /opt/dapur-kasir --shell /usr/sbin/nologin dapur-kasir || true
sudo mkdir -p /opt/dapur-kasir/{bin,backend,var,log}
sudo mkdir -p /var/lib/dapur-kasir
sudo chown -R dapur-kasir:dapur-kasir /opt/dapur-kasir /var/lib/dapur-kasir

# 2. Upload backend source to /opt/dapur-kasir/backend (rsync/scp/git)

# 3. Install Dart SDK 3.13+ on VPS, then build
cd /opt/dapur-kasir/backend
sudo -u dapur-kasir bash deploy/build-linux.sh

# 4. Configure secrets (NEVER commit)
sudo cp deploy/env.staging.example /etc/dapur-kasir/backend.env
sudo chmod 600 /etc/dapur-kasir/backend.env
sudo chown root:dapur-kasir /etc/dapur-kasir/backend.env
# Edit /etc/dapur-kasir/backend.env with real values

# 5. Install systemd unit
sudo cp deploy/dapur-kasir-backend.service.example /etc/systemd/system/dapur-kasir-backend.service
sudo systemctl daemon-reload
sudo systemctl enable --now dapur-kasir-backend

# 6. Local health
curl -sS http://127.0.0.1:8080/health

# 7. Configure nginx (see reverse-proxy.nginx.example.conf) + TLS + DNS
```

## Directory layout (recommended)

```
/opt/dapur-kasir/
  bin/kasir-dapur-backend      # compiled executable
  backend/                     # source + pubspec (for rebuilds)
  var/                         # optional runtime (avoid for DB in prod)
/var/lib/dapur-kasir/
  billing.db                   # SQLite authority (BILLING_SQLITE_PATH)
/etc/dapur-kasir/
  backend.env                  # secrets, mode 600
/etc/systemd/system/
  dapur-kasir-backend.service
```

## Files in this folder

| File | Purpose |
|---|---|
| `build-linux.sh` | Compile release binary |
| `health-check.sh` | Probe `/health` |
| `dapur-kasir-backend.service.example` | systemd unit template |
| `reverse-proxy.nginx.example.conf` | nginx TLS template |
| `env.staging.example` | Staging env template |
| `env.production.example` | Production env template |

Full checklist: `STAGING_DEPLOY_CHECKLIST.md`
