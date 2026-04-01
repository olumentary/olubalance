# Linode Object Storage Migration — Production Runbook

This document is the definitive step-by-step guide for migrating all ActiveStorage
attachments from AWS S3 to Linode Object Storage in production.

The migration uses an **in-place strategy**: each blob is downloaded from S3, uploaded
to Linode under the same key, and then `service_name` is updated on the existing DB
record. No new blob records are created and no attachment pointers change.
`active_storage_blobs.service_name` is the single source of truth for migration
progress — the task can be interrupted at any time and re-run to pick up exactly
where it left off.

---

## Table of Contents

1. [How the migration works](#1-how-the-migration-works)
2. [Available rake tasks](#2-available-rake-tasks)
3. [Environment variables reference](#3-environment-variables-reference)
4. [Pre-migration checklist](#4-pre-migration-checklist)
5. [Phase 1 — Verify configuration](#5-phase-1--verify-configuration)
6. [Phase 2 — Dry run](#6-phase-2--dry-run)
7. [Phase 3 — Migrate in batches](#7-phase-3--migrate-in-batches)
8. [Phase 4 — Verify migration completeness](#8-phase-4--verify-migration-completeness)
9. [Phase 5 — Switch the app to Linode](#9-phase-5--switch-the-app-to-linode)
10. [Phase 6 — Post-switch smoke test](#10-phase-6--post-switch-smoke-test)
11. [Phase 7 — Clean up S3 (deferred)](#11-phase-7--clean-up-s3-deferred)
12. [Rollback procedure](#12-rollback-procedure)
13. [Troubleshooting](#13-troubleshooting)
14. [Production run checklist (quick reference)](#14-production-run-checklist-quick-reference)

---

## 1. How the migration works

```
active_storage_blobs
  ┌────┬──────────────────────────┬──────────────┬──────────────┐
  │ id │ key                      │ filename     │ service_name │
  ├────┼──────────────────────────┼──────────────┼──────────────┤
  │  1 │ abc123...                │ receipt.pdf  │ amazon       │  ← pending
  │  2 │ def456...                │ invoice.png  │ linode       │  ← done
  └────┴──────────────────────────┴──────────────┴──────────────┘
```

For each pending blob the task:

1. Downloads the file from S3 in chunks (streamed to a temp file — no full-file memory load)
2. Uploads it to the Linode bucket under the **same key**
3. Updates `service_name` from `'amazon'` to `'linode'` on the **same DB record**

The blob `id`, `key`, `filename`, `checksum`, and all `active_storage_attachments`
rows are untouched. If the task is killed mid-run, only fully completed blobs (those
whose `service_name` was updated) are counted as migrated. Every re-run picks up the
remaining blobs automatically.

---

## 2. Available rake tasks

| Task | Purpose |
|---|---|
| `storage:status` | Show blob distribution by service and attachment stats |
| `storage:diagnose_migration` | Show pending blob counts and sample blobs |
| `storage:migrate_blobs_to_linode` | **Main migration task** (resumable, chunked) |
| `storage:verify_linode_migration` | Check that every Linode blob actually exists in the bucket |
| `storage:validate_linode_bucket` | Cross-check DB records against the Linode bucket via HEAD requests |
| `storage:cleanup_aws_attachments` | Delete migrated files from S3 (destructive, deferred) |
| `storage:rollback_migration` | Re-upload from Linode → S3, revert `service_name` to `amazon` |
| `storage:recover_missing_files` | Re-upload files missing from their storage location using S3 as source |
| `storage:test_linode_upload` | Upload and verify a small test file to confirm Linode connectivity |

### Migration task options (via environment variables)

```bash
# See what would be migrated without making changes
DRY_RUN=1 rails storage:migrate_blobs_to_linode

# Migrate only the next 200 blobs (safe for first production test)
BATCH_SIZE=200 rails storage:migrate_blobs_to_linode

# Migrate 500 blobs, pausing 3 seconds every 100 to reduce peak S3 load
BATCH_SIZE=500 BATCH_PAUSE=3 rails storage:migrate_blobs_to_linode

# Migrate everything
rails storage:migrate_blobs_to_linode

# Migrate from a non-default source service
SOURCE_SERVICE=amazondev rails storage:migrate_blobs_to_linode
```

**Ctrl+C / SIGTERM**: the current blob finishes uploading, then the task prints a
summary and exits. Re-run the same command to resume — already-migrated blobs are
automatically skipped.

---

## 3. Environment variables reference

### S3 (source — must remain set throughout migration)

| Variable | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `S3_REGION` | S3 bucket region (e.g. `us-east-1`) |
| `S3_BUCKET_NAME` | Production S3 bucket name |

### Linode (destination)

| Variable | Description |
|---|---|
| `LINODE_ACCESS_KEY_ID` | Linode Object Storage access key |
| `LINODE_SECRET_ACCESS_KEY` | Linode Object Storage secret key |
| `LINODE_ENDPOINT` | e.g. `https://us-southeast-1.linodeobjects.com` |
| `LINODE_REGION` | e.g. `us-southeast-1` |
| `LINODE_BUCKET_NAME` | Production Linode bucket name |

### App storage selector

| Variable | Values | Effect |
|---|---|---|
| `STORAGE_SERVICE` | `amazon` (default) | App reads/writes S3 |
| `STORAGE_SERVICE` | `linode` | App reads/writes Linode |

**The migration can and should run while `STORAGE_SERVICE=amazon` is still active.**
The app continues serving files from S3 while blobs are being migrated in the
background. You only switch `STORAGE_SERVICE` after all blobs are migrated.

---

## 4. Pre-migration checklist

Complete every item before starting the migration.

- [ ] **Linode bucket created** with the same (or equivalent) ACL/CORS settings as the S3 bucket
- [ ] **LINODE_* env vars set** on the production server and verified (see Phase 1)
- [ ] **AWS_* env vars remain set** — they are needed throughout the migration
- [ ] **Database backup taken** (e.g. `pg_dump` snapshot)
- [ ] **S3 bucket backup** confirmed — Linode is the destination, but S3 stays intact until Phase 7
- [ ] **Low-traffic window identified** — migration does not block the app but generates S3 egress bandwidth
- [ ] **Disk space confirmed** — each blob is temporarily buffered to a temp file; ensure `/tmp` has headroom (at least a few GB)
- [ ] **`storage:test_linode_upload` passes** — proves credentials and bucket access work end-to-end (see Phase 1)
- [ ] **Total blob count noted** via `storage:status` — you need a baseline to verify 100% completion

---

## 5. Phase 1 — Verify configuration

### 1.1 Check current status

```bash
rails storage:status
```

Expected output includes:

```
Active service : amazon
Blobs pending migration : <total blobs with attachments>
Still pending           : <same number>
```

Note the **total blob count** — you will compare against this at the end.

### 1.2 Confirm Linode credentials work

```bash
rails storage:test_linode_upload
```

This uploads a small text file, reads it back, and confirms the file appears in the
bucket. If it fails, do not proceed — fix credentials or bucket permissions first.

Look for this in the output:

```
✓ Upload succeeded
✓ Download verified (N bytes, content match: true)
✓ Bucket 'your-bucket' is accessible
✓ File confirmed in bucket
```

### 1.3 Check migration readiness

```bash
rails storage:diagnose_migration
```

Confirms blobs with `service_name: 'amazon'` exist and shows a sample listing.

---

## 6. Phase 2 — Dry run

Always run in dry-run mode first to confirm the expected scope.

```bash
DRY_RUN=1 rails storage:migrate_blobs_to_linode
```

Expected output:

```
=== Linode Storage Migration ===
Source service : amazon
Mode           : DRY RUN — no changes will be made

Blobs pending migration: 1837

Blobs that would be migrated (showing up to 50):
  Blob 1: receipt.pdf (248.3 KB, key: abc123...)
  Blob 2: invoice.png (1.1 MB, key: def456...)
  ...
```

Verify:
- The pending count matches your baseline from Phase 1
- The filenames and sizes look reasonable
- No unexpected blobs (e.g. test data you didn't expect)

---

## 7. Phase 3 — Migrate in batches

### 7.1 First batch (test with a small number)

Run a small batch to confirm end-to-end behaviour in production before committing
to a full run:

```bash
BATCH_SIZE=50 rails storage:migrate_blobs_to_linode
```

Wait for it to complete (watch the ETA output). Then confirm the batch landed:

```bash
rails storage:status
```

You should see `Migrated to Linode: 50` and `Still pending: <total - 50>`.

Spot-check one of the migrated files using the validate task:

```bash
rails storage:validate_linode_bucket
```

If you see 50 files found and 0 missing, the first batch is healthy.

### 7.2 Progressive batches

Once confident, run larger batches. A reasonable cadence for ~10,000 blobs:

```bash
# 500 blobs at a time, with a 2-second pause every 100 to ease S3 egress
BATCH_SIZE=500 BATCH_PAUSE=2 rails storage:migrate_blobs_to_linode
```

Re-run the same command as many times as needed. Each run picks up where the
previous one left off. You can safely run this during off-peak hours across
multiple days.

### 7.3 Cancelling mid-run

Press **Ctrl+C** at any time. The task finishes the current blob and prints:

```
Interrupt — finishing current blob then stopping...

============================================================
MIGRATION SUMMARY
============================================================
Elapsed time          : 47.3s
Migrated this run     : 83
Failed                : 0
Still pending         : 1754
Stopped early (signal): yes

1754 blob(s) still pending. Re-run to resume (already-migrated blobs are skipped).
```

Re-running the same command resumes from blob 84 onward automatically.

### 7.4 Final pass (migrate all remaining)

When ready to complete the migration in one go:

```bash
rails storage:migrate_blobs_to_linode
```

Wait for:

```
All blobs have been migrated to Linode.
```

### 7.5 Handling failures

If some blobs fail (network blip, S3 throttle), they appear in the summary:

```
Failed blobs:
  Blob 1234 (receipt.pdf): Net::ReadTimeout
```

Those blobs retain `service_name: 'amazon'` and will be retried on the next run.
If a blob consistently fails, investigate the specific file. You can also run
`storage:recover_missing_files` to attempt recovery.

---

## 8. Phase 4 — Verify migration completeness

### 8.1 Check the database

```bash
rails storage:status
```

Expected:

```
Migrated to Linode   : 1837
Still pending        : 0
```

Double-check with a direct query:

```bash
rails runner "puts ActiveStorage::Blob.group(:service_name).count"
```

Expected: `{"linode"=>1837}` with no `"amazon"` key.

### 8.2 Verify files exist in the Linode bucket

```bash
rails storage:verify_linode_migration
```

This calls `exist?` on each blob key via the Linode service. Look for:

```
VERIFICATION SUMMARY
Total Linode blobs (DB)  : 1837
Verified in bucket       : 1837
Missing from bucket      : 0
```

### 8.3 Cross-check via direct S3 HEAD requests (most thorough)

```bash
rails storage:validate_linode_bucket
```

This issues a direct `HEAD` request per blob key to the Linode S3 API. It confirms
files are physically present even if the ActiveStorage service layer has a caching
layer. Look for zero missing files.

**Do not proceed to Phase 5 until both verification tasks show 0 missing files.**

---

## 9. Phase 5 — Switch the app to Linode

This is the only step that requires a restart/deploy. The migration itself (Phases
3–4) runs with `STORAGE_SERVICE=amazon` still active, so the app never goes down.

### 9.1 Update the environment variable

On your production server / deployment config:

```bash
STORAGE_SERVICE=linode
```

`config/environments/production.rb` reads this variable:

```ruby
config.active_storage.service = ENV.fetch('STORAGE_SERVICE', 'amazon').to_sym
```

### 9.2 Restart the application

Deploy the updated env var or restart the process. No code change is needed.

### 9.3 Verify the switch

```bash
rails storage:status
```

Expected:

```
Active service : linode
```

```bash
rails runner "puts Rails.application.config.active_storage.service"
# => linode
```

---

## 10. Phase 6 — Post-switch smoke test

Perform these checks immediately after switching to Linode:

| Check | How | Expected result |
|---|---|---|
| Existing attachments render | Open any transaction with a receipt in the app | Image/PDF loads without error |
| Download works | Click "Download" on an attachment | File downloads correctly |
| New upload goes to Linode | Create a new transaction and attach a file | Upload succeeds |
| New upload's `service_name` is `linode` | `rails runner "puts ActiveStorage::Blob.order(created_at: :desc).first.service_name"` | `linode` |
| Delete works | Delete a transaction with an attachment | No errors; file removed from Linode |

If any check fails, execute the rollback procedure immediately (Section 12).

---

## 11. Phase 7 — Clean up S3 (deferred)

**Wait at least 1–2 weeks after Phase 5 before running this.**

You want confidence that:
- No users are experiencing issues
- No background jobs are referencing old S3 keys
- You have had time to discover any edge cases

When ready:

```bash
rails storage:cleanup_aws_attachments
```

Type `YES` when prompted. This deletes every file from S3 whose blob has
`service_name: 'linode'`. It does not touch DB records or Linode files.

Confirm S3 no longer has the files (check the S3 console or bucket size).

After this step you can optionally remove the `AWS_*` environment variables from
production, but retain them until you are certain no code path references them.

---

## 12. Rollback procedure

If something goes wrong after Phase 5 (the switch), roll back by:

### Step 1: Switch the app back to S3

Set `STORAGE_SERVICE=amazon` and restart the app. Files that were already on S3
are still there (S3 was not modified). Files uploaded after Phase 5 (to Linode)
will not be accessible until rollback completes.

### Step 2: Roll back migrated blobs

```bash
rails storage:rollback_migration
```

Type `ROLLBACK` when prompted. This streams each Linode blob back to S3 and updates
`service_name` to `'amazon'`. It is also resumable — press Ctrl+C to stop, re-run to
continue.

### Step 3: Verify rollback

```bash
rails runner "puts ActiveStorage::Blob.group(:service_name).count"
# Expected: {"amazon"=>N}
rails storage:status
# Active service: amazon, Still pending: 0
```

### Step 4: Investigate root cause before re-attempting migration

---

## 13. Troubleshooting

### `Cannot load 'linode' storage service`

The `LINODE_*` environment variables are missing or `config/storage.yml` is not
deployed. Verify all required variables are set and the app has been restarted.

### `Net::ReadTimeout` / `Aws::S3::Errors::ServiceError` during migration

Transient S3 or network errors. The failed blob retains `service_name: 'amazon'`
and will be retried on the next run. If a specific blob consistently fails:

```bash
rails runner "b = ActiveStorage::Blob.find(<id>); puts b.service.exist?(b.key)"
```

If `false`, the file is missing from S3. Use `storage:recover_missing_files` or
contact AWS support.

### Files missing from Linode after migration

Run `storage:verify_linode_migration`. For each missing blob, check if the file
still exists on S3:

```bash
rails runner "
  b = ActiveStorage::Blob.find(<id>)
  svc = ActiveStorage::Blob.services.fetch('amazon')
  puts svc.exist?(b.key)
"
```

If `true`, re-run the migration — it will re-upload the missing file (the
`exist?` check on Linode will return `false`, so it proceeds with upload).

### Migration running too slowly

- Increase `BATCH_SIZE` (default is unlimited per run but `find_each` processes 100 at a time)
- Remove `BATCH_PAUSE` or reduce it
- Check S3 egress bandwidth limits on your AWS account
- Consider running during a low-traffic window

### Disk space errors (`Errno::ENOSPC`) in `/tmp`

The task streams blobs through temp files. If `/tmp` fills up, reduce `BATCH_SIZE`
so fewer concurrent temp files accumulate, or ensure at least 10% of your largest
attachment size is free in `/tmp`.

---

## 14. Production run checklist (quick reference)

### Before starting

- [ ] Linode bucket created and accessible
- [ ] `LINODE_*` env vars set on production server
- [ ] Database backup taken
- [ ] Baseline blob count noted (`rails storage:status`)
- [ ] `storage:test_linode_upload` passes

### Migration

- [ ] `DRY_RUN=1 rails storage:migrate_blobs_to_linode` — review scope
- [ ] `BATCH_SIZE=50 rails storage:migrate_blobs_to_linode` — small test batch
- [ ] `rails storage:validate_linode_bucket` — confirm first batch landed
- [ ] `BATCH_SIZE=500 BATCH_PAUSE=2 rails storage:migrate_blobs_to_linode` — progressive batches
- [ ] (Repeat until `Still pending: 0`)
- [ ] `rails storage:verify_linode_migration` — 0 missing
- [ ] `rails storage:validate_linode_bucket` — 0 missing

### Switch

- [ ] Set `STORAGE_SERVICE=linode`, restart app
- [ ] `rails storage:status` confirms `Active service: linode`
- [ ] Smoke test: existing attachments render, new upload goes to Linode

### Post-switch (deferred 1–2 weeks)

- [ ] `rails storage:cleanup_aws_attachments` — type YES to confirm
- [ ] Verify S3 bucket is now empty of app files
