# SQLite Backup & Disaster Recovery — Kasir Dapur Backend

**Scope:** Backend billing SQLite (`BILLING_SQLITE_PATH`).  
**Authority:** SQLite is the billing/subscription source of truth.  
**Automation:** Manual procedures below — no automated backup job is included in this repository.

---

## 1. What to backup

| File | Notes |
|---|---|
| `billing.db` | Main database |
| `billing.db-wal` | WAL file (if WAL mode active) |
| `billing.db-shm` | Shared memory (optional; recreated) |

Default production path: `/var/lib/dapur-kasir/billing.db`

---

## 2. Pre-backup checklist

- [ ] Confirm **only one** backend instance uses this DB path
- [ ] Prefer **graceful stop** before cold copy:
  ```bash
  sudo systemctl stop dapur-kasir-backend
  ```
- [ ] Verify disk space for backup destination
- [ ] Record backup timestamp and backend version/git commit

---

## 3. Backup procedure (recommended — graceful stop)

```bash
sudo systemctl stop dapur-kasir-backend

BACKUP_DIR="/var/backups/dapur-kasir/$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "${BACKUP_DIR}"
sudo cp -a /var/lib/dapur-kasir/billing.db* "${BACKUP_DIR}/"
sudo chown -R root:root "${BACKUP_DIR}"
sudo chmod -R 600 "${BACKUP_DIR}"/*

sudo systemctl start dapur-kasir-backend
bash /opt/dapur-kasir/backend/deploy/health-check.sh
```

---

## 4. Online backup (alternative — hot backup, use with care)

If downtime must be minimized:

```bash
sqlite3 /var/lib/dapur-kasir/billing.db ".backup '/var/backups/dapur-kasir/billing-hot-$(date +%Y%m%d).db'"
```

Requires `sqlite3` CLI on server. Verify backup file opens and `schema_meta` readable.

**Risk:** concurrent writes during hot backup on busy systems — prefer graceful stop for MVP.

---

## 5. Backup verification

```bash
sqlite3 /path/to/backup.db "SELECT schema_version FROM schema_meta WHERE id=1;"
sqlite3 /path/to/backup.db "SELECT COUNT(*) FROM subscriptions;"
sqlite3 /path/to/backup.db "SELECT COUNT(*) FROM payments;"
```

- File size > 0
- Queries succeed without `database disk image is malformed`

---

## 6. Restore procedure

```bash
sudo systemctl stop dapur-kasir-backend

sudo cp -a /var/lib/dapur-kasir/billing.db /var/lib/dapur-kasir/billing.db.before-restore.$(date +%s)
sudo cp -a /path/to/verified-backup.db /var/lib/dapur-kasir/billing.db
sudo chown dapur-kasir:dapur-kasir /var/lib/dapur-kasir/billing.db
sudo chmod 640 /var/lib/dapur-kasir/billing.db

sudo systemctl start dapur-kasir-backend
curl -sS http://127.0.0.1:8080/health
```

Run smoke test on subscription/billing endpoints after restore.

---

## 7. Retention recommendation (manual)

| Tier | Retention | Frequency |
|---|---|---|
| Daily | 7 days | Before each deploy |
| Weekly | 4 weeks | Scheduled ops task |
| Pre-deploy | Keep until next successful deploy | Mandatory |

Store backups off-server (object storage / separate VPS) when available.

---

## 8. Database corrupt / backend won't start

1. Stop backend: `systemctl stop dapur-kasir-backend`
2. Check logs: `journalctl -u dapur-kasir-backend -n 200 --no-pager`
3. Try integrity check:
   ```bash
   sqlite3 /var/lib/dapur-kasir/billing.db "PRAGMA integrity_check;"
   ```
4. If corrupt → restore from latest **verified** backup (section 6)
5. Do **not** delete WAL/SHM blindly while process running
6. Do **not** run two backend instances on same DB path

---

## 9. Before backend update/deploy

1. Backup SQLite (section 3)
2. Verify backup (section 5)
3. Deploy new binary
4. `systemctl restart dapur-kasir-backend`
5. Health check + billing smoke test
6. Keep previous binary at `/opt/dapur-kasir/bin/kasir-dapur-backend.prev` for rollback

---

## 10. WAL considerations

Backend enables WAL (`PRAGMA journal_mode=WAL`). For file copy backup:

- **Best:** stop backend first
- **Hot backup:** use `.backup` command
- After restore, backend recreates WAL on next start

---

## 11. What is NOT automated

- Scheduled cron backup
- Off-site replication
- Point-in-time recovery

Implement these at infrastructure level when moving beyond MVP.
