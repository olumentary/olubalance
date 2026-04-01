# frozen_string_literal: true

# ─── Shared helpers ───────────────────────────────────────────────────────────
# These are defined at the top level so they are available to all tasks below.

def storage_format_bytes(bytes)
  return '0 B' unless bytes&.positive?
  units = %w[B KB MB GB]
  exp   = [( Math.log(bytes) / Math.log(1024) ).floor, units.length - 1].min
  "#{(bytes.to_f / 1024**exp).round(1)} #{units[exp]}"
end

def storage_format_eta(seconds)
  return 'unknown' unless seconds&.positive? && seconds.finite?
  h, rem = seconds.divmod(3600)
  m, s   = rem.divmod(60)
  parts  = []
  parts << "#{h.to_i}h" if h >= 1
  parts << "#{m.to_i}m" if m >= 1
  parts << "#{s.to_i}s"
  parts.join(' ')
end

def storage_print_progress(count, total, start_time, blob, note = nil)
  elapsed = [Time.now - start_time, 0.001].max
  eta     = storage_format_eta((elapsed / count) * (total - count))
  pct     = total > 0 ? (count * 100.0 / total).round(1) : 0
  line    = "[#{count}/#{total} #{pct}%] Blob #{blob.id} (#{blob.filename})"
  line   += " — #{note}" if note
  line   += " | ETA #{eta}"
  puts line
end

def build_s3_client(access_key_id:, secret_access_key:, region:, endpoint:)
  require 'aws-sdk-s3'
  Aws::S3::Client.new(
    access_key_id:     access_key_id,
    secret_access_key: secret_access_key,
    region:            region,
    endpoint:          endpoint,
    force_path_style:  true
  )
end

# ─── Tasks ────────────────────────────────────────────────────────────────────

namespace :storage do
  desc 'Migrate transaction attachments from AWS S3 to Linode (DEPRECATED — use migrate_blobs_to_linode)'
  task migrate_to_linode: :environment do
    puts "This migration method is deprecated and may not work correctly."
    puts "Please use: bundle exec rails storage:migrate_blobs_to_linode"
    exit 1
  end

  desc <<~DESC
    Migrate ActiveStorage blobs to Linode object storage (resumable, chunked).

    Uses an in-place strategy: downloads each blob from the source service and
    uploads it to Linode under the SAME key, then updates service_name in the DB.
    This means active_storage_blobs.service_name is the single source of truth —
    re-running the task automatically skips already-migrated blobs.

    Options (via ENV):
      SOURCE_SERVICE=amazon   Service name to migrate from (default: amazon)
      BATCH_SIZE=N            Stop after migrating N blobs this run (default: 0 = all)
      BATCH_PAUSE=N           Sleep N seconds every 100 blobs, e.g. to throttle (default: 0)
      DRY_RUN=1               List blobs that would be migrated without making changes
  DESC
  task migrate_blobs_to_linode: :environment do
    require 'tempfile'

    batch_limit = ENV.fetch('BATCH_SIZE', 0).to_i
    batch_pause = ENV.fetch('BATCH_PAUSE', 0).to_i
    dry_run     = ENV['DRY_RUN'].present?
    source_name = ENV.fetch('SOURCE_SERVICE', 'amazon')
    dest_name   = 'linode'

    puts "=== Linode Storage Migration ==="
    puts "Source service : #{source_name}"
    puts "Batch limit    : #{batch_limit > 0 ? batch_limit : 'unlimited (all pending)'}"
    puts "Batch pause    : #{batch_pause > 0 ? "#{batch_pause}s every 100 blobs" : 'none'}"
    puts "Mode           : #{dry_run ? 'DRY RUN — no changes will be made' : 'LIVE'}"
    puts ""

    # Fail fast if the destination service is not configured
    begin
      dest_service = ActiveStorage::Blob.services.fetch(dest_name)
    rescue => e
      abort "Cannot load '#{dest_name}' storage service: #{e.message}\n" \
            "Verify config/storage.yml and LINODE_* environment variables."
    end

    # Only include blobs that belong to at least one attachment (orphan blobs are excluded)
    scope = ActiveStorage::Blob
              .joins(:attachments)
              .where(service_name: source_name)
              .distinct
              .order(:id)

    total_pending = scope.count

    puts "Current blob distribution:"
    ActiveStorage::Blob.group(:service_name).count.each { |svc, n| puts "  #{svc}: #{n}" }
    puts ""
    puts "Blobs pending migration: #{total_pending}"
    puts ""

    if total_pending == 0
      puts "Nothing to migrate — all blobs are already on Linode, or there are no blobs."
      next
    end

    if dry_run
      limit = [batch_limit > 0 ? batch_limit : 50, 50].min
      puts "Blobs that would be migrated (showing up to #{limit}):"
      scope.limit(limit).each do |blob|
        puts "  Blob #{blob.id}: #{blob.filename} (#{storage_format_bytes(blob.byte_size)}, key: #{blob.key})"
      end
      puts "  ... and #{total_pending - limit} more" if total_pending > limit
      puts ""
      puts "Re-run without DRY_RUN=1 to perform the migration."
      next
    end

    # Graceful shutdown: finish the in-flight blob, then print summary and exit
    shutdown  = false
    prev_int  = Signal.trap('INT')  { puts "\nInterrupt — finishing current blob then stopping..."; shutdown = true }
    prev_term = Signal.trap('TERM') { shutdown = true }

    migrated_count = 0
    skipped_count  = 0   # already in Linode bucket; only needed a DB update
    failed_count   = 0
    failures       = []
    start_time     = Time.now

    scope.find_each(batch_size: 100) do |blob|
      break if shutdown
      break if batch_limit > 0 && migrated_count >= batch_limit

      begin
        # If the file is already in the Linode bucket (e.g. a previous run uploaded
        # the file but crashed before updating service_name), just flip service_name.
        if dest_service.exist?(blob.key)
          blob.update_column(:service_name, dest_name)
          migrated_count += 1
          skipped_count  += 1
          storage_print_progress(migrated_count, total_pending, start_time, blob,
                                 'already in Linode bucket — DB record updated')
          next
        end

        source_service = blob.service  # resolved automatically from blob.service_name

        ext = blob.filename.extension_with_delimiter.presence || '.tmp'
        Tempfile.create(["blob-#{blob.id}", ext]) do |tmp|
          tmp.binmode
          source_service.download(blob.key) { |chunk| tmp.write(chunk) }
          tmp.rewind
          dest_service.upload(blob.key, tmp, checksum: blob.checksum)
        end

        blob.update_column(:service_name, dest_name)
        migrated_count += 1
        storage_print_progress(migrated_count, total_pending, start_time, blob,
                               storage_format_bytes(blob.byte_size))

        sleep(batch_pause) if batch_pause > 0 && (migrated_count % 100).zero?

      rescue => e
        failed_count += 1
        failures << { id: blob.id, filename: blob.filename.to_s, error: "#{e.class}: #{e.message}" }
        puts "  [FAILED] Blob #{blob.id} (#{blob.filename}): #{e.class}: #{e.message}"
      end
    end

    # Restore original signal handlers
    Signal.trap('INT',  prev_int  || 'DEFAULT')
    Signal.trap('TERM', prev_term || 'DEFAULT')

    elapsed   = (Time.now - start_time).round(1)
    remaining = scope.count   # re-query after the run for an accurate final count

    puts ""
    puts "=" * 60
    puts "MIGRATION SUMMARY"
    puts "=" * 60
    puts "Elapsed time          : #{elapsed}s"
    puts "Migrated this run     : #{migrated_count}"
    puts "  (DB-only fixes)     : #{skipped_count}" if skipped_count > 0
    puts "Failed                : #{failed_count}"
    puts "Still pending         : #{remaining}"
    puts "Stopped early (signal): yes" if shutdown

    if failures.any?
      puts ""
      puts "Failed blobs:"
      failures.each { |f| puts "  Blob #{f[:id]} (#{f[:filename]}): #{f[:error]}" }
    end

    puts ""
    if remaining > 0 && shutdown
      puts "#{remaining} blob(s) still pending. Re-run to resume (already-migrated blobs are skipped)."
    elsif remaining > 0
      puts "#{remaining} blob(s) still pending. Re-run to continue."
    else
      puts "All blobs have been migrated to Linode."
    end
  end

  desc 'Verify migration: check that every Linode blob actually exists in the Linode bucket'
  task verify_linode_migration: :environment do
    puts "Verifying Linode migration..."
    puts ""

    begin
      linode_service = ActiveStorage::Blob.services.fetch(:linode)
    rescue => e
      abort "Cannot load 'linode' service: #{e.message}"
    end

    linode_blobs  = ActiveStorage::Blob.joins(:attachments).where(service_name: 'linode').distinct
    total         = linode_blobs.count
    verified      = 0
    missing_count = 0
    missing_blobs = []

    puts "Blobs with service_name='linode': #{total}"
    puts ""

    linode_blobs.find_each(batch_size: 100) do |blob|
      if linode_service.exist?(blob.key)
        verified += 1
        puts "  ✓ Blob #{blob.id} (#{blob.filename})"
      else
        missing_count += 1
        missing_blobs << blob
        puts "  ✗ Blob #{blob.id} (#{blob.filename}) — NOT FOUND in Linode (key: #{blob.key})"
      end
    end

    puts ""
    puts "=" * 60
    puts "VERIFICATION SUMMARY"
    puts "=" * 60
    puts "Total Linode blobs (DB)  : #{total}"
    puts "Verified in bucket       : #{verified}"
    puts "Missing from bucket      : #{missing_count}"

    if missing_blobs.any?
      puts ""
      puts "Run 'rails storage:recover_missing_files' to re-upload missing files from AWS."
    end

    puts ""
    puts "Verification completed!"
  end

  desc 'Clean up old AWS S3 files after successful migration (removes files from S3, not DB records)'
  task cleanup_aws_attachments: :environment do
    puts "WARNING: This permanently deletes migrated files from AWS S3."
    puts "Only proceed after verifying the Linode migration is complete and all files are accessible."
    print "Type 'YES' to continue: "

    confirmation = $stdin.gets.chomp
    unless confirmation == 'YES'
      puts "Cleanup cancelled."
      next
    end

    begin
      amazon_service = ActiveStorage::Blob.services.fetch(:amazon)
    rescue => e
      abort "Cannot load 'amazon' service: #{e.message}"
    end

    # Only delete files for blobs that have already been successfully migrated to Linode
    migrated_blobs = ActiveStorage::Blob.where(service_name: 'linode')
    total          = migrated_blobs.count
    cleaned_count  = 0
    failed_count   = 0

    puts ""
    puts "Deleting #{total} file(s) from AWS S3 (keys that have been migrated to Linode)..."
    puts ""

    migrated_blobs.find_each(batch_size: 100) do |blob|
      begin
        amazon_service.delete(blob.key)
        cleaned_count += 1
        puts "  ✓ Deleted #{blob.filename} (key: #{blob.key})"
      rescue => e
        failed_count += 1
        puts "  ✗ Failed #{blob.filename} (key: #{blob.key}): #{e.message}"
      end
    end

    puts ""
    puts "=" * 60
    puts "CLEANUP SUMMARY"
    puts "=" * 60
    puts "Deleted from AWS S3 : #{cleaned_count}"
    puts "Failed              : #{failed_count}"
    puts ""
    puts "Note: DB blob records and Linode files are unchanged."
  end

  desc 'Validate files exist in Linode bucket by issuing HEAD requests directly via S3 client'
  task validate_linode_bucket: :environment do
    puts "Validating files in Linode bucket..."

    bucket_name = ENV['LINODE_BUCKET_NAME']

    puts "  Bucket : #{bucket_name}"
    puts ""

    s3_client = build_s3_client(
      access_key_id:     ENV['LINODE_ACCESS_KEY_ID'],
      secret_access_key: ENV['LINODE_SECRET_ACCESS_KEY'],
      region:            ENV['LINODE_REGION'],
      endpoint:          ENV['LINODE_ENDPOINT']
    )

    linode_blobs  = ActiveStorage::Blob.where(service_name: 'linode')
    total         = linode_blobs.count
    found_count   = 0
    missing_count = 0
    missing_files = []

    puts "DB shows #{total} blob(s) with service_name='linode'"
    puts ""

    linode_blobs.find_each(batch_size: 100) do |blob|
      begin
        s3_client.head_object(bucket: bucket_name, key: blob.key)
        found_count += 1
        puts "  ✓ #{blob.filename} (key: #{blob.key})"
      rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
        missing_count += 1
        missing_files << { id: blob.id, filename: blob.filename.to_s, key: blob.key }
        puts "  ✗ #{blob.filename} (key: #{blob.key}) — NOT FOUND IN BUCKET"
      rescue => e
        missing_count += 1
        missing_files << { id: blob.id, filename: blob.filename.to_s, key: blob.key, error: e.message }
        puts "  ✗ #{blob.filename} (key: #{blob.key}) — ERROR: #{e.message}"
      end
    end

    puts ""
    puts "=" * 60
    puts "BUCKET VALIDATION SUMMARY"
    puts "=" * 60
    puts "Blobs in DB (service=linode) : #{total}"
    puts "Found in bucket              : #{found_count}"
    puts "Missing from bucket          : #{missing_count}"

    if missing_files.any?
      puts ""
      puts "Missing files:"
      missing_files.each do |f|
        puts "  Blob #{f[:id]}: #{f[:filename]} (key: #{f[:key]})"
        puts "    Error: #{f[:error]}" if f[:error]
      end
    end

    puts ""
    puts "Bucket validation completed!"
  end

  desc 'Recover blobs missing from their current storage by re-uploading from AWS S3 to Linode'
  task recover_missing_files: :environment do
    puts "Recovering missing files..."
    puts "Checks every blob's current storage location and re-uploads from AWS S3 if missing."
    print "Type 'RECOVER' to continue: "

    confirmation = $stdin.gets.chomp
    unless confirmation == 'RECOVER'
      puts "Recovery cancelled."
      next
    end

    require 'tempfile'

    begin
      amazon_service = ActiveStorage::Blob.services.fetch(:amazon)
      linode_service = ActiveStorage::Blob.services.fetch(:linode)
    rescue => e
      abort "Cannot load storage services: #{e.message}"
    end

    all_blobs     = ActiveStorage::Blob.joins(:attachments).distinct
    missing_blobs = []

    puts "Scanning #{all_blobs.count} blob(s) for missing files..."
    puts ""

    all_blobs.find_each(batch_size: 100) do |blob|
      unless blob.service.exist?(blob.key)
        puts "  ✗ Blob #{blob.id} (#{blob.filename}) — missing from #{blob.service_name}"
        missing_blobs << blob
      end
    end

    if missing_blobs.empty?
      puts "No missing files found — all blobs are accessible."
      next
    end

    puts ""
    puts "Found #{missing_blobs.count} missing blob(s). Attempting recovery from AWS S3..."
    puts ""

    recovered = 0
    failed    = 0

    missing_blobs.each do |blob|
      begin
        puts "Recovering Blob #{blob.id} (#{blob.filename})..."

        unless amazon_service.exist?(blob.key)
          puts "  ✗ Not found in AWS S3 — cannot recover automatically."
          failed += 1
          next
        end

        ext = blob.filename.extension_with_delimiter.presence || '.tmp'
        Tempfile.create(["recovery-#{blob.id}", ext]) do |tmp|
          tmp.binmode
          amazon_service.download(blob.key) { |chunk| tmp.write(chunk) }
          tmp.rewind
          linode_service.upload(blob.key, tmp, checksum: blob.checksum)
        end

        blob.update_column(:service_name, 'linode')
        puts "  ✓ Recovered and uploaded to Linode"
        recovered += 1

      rescue => e
        puts "  ✗ Error recovering Blob #{blob.id}: #{e.message}"
        failed += 1
      end
    end

    puts ""
    puts "=" * 60
    puts "RECOVERY SUMMARY"
    puts "=" * 60
    puts "Missing found : #{missing_blobs.count}"
    puts "Recovered     : #{recovered}"
    puts "Failed        : #{failed}"
    puts ""
    puts "Failed blobs will need manual intervention." if failed > 0
    puts "Recovery completed!"
  end

  desc 'Rollback migration: re-upload blobs from Linode back to AWS S3 (resumable)'
  task rollback_migration: :environment do
    puts "WARNING: This re-uploads blobs from Linode back to AWS S3 and reverts service_name."
    puts "Use only if the Linode migration must be undone."
    print "Type 'ROLLBACK' to continue: "

    confirmation = $stdin.gets.chomp
    unless confirmation == 'ROLLBACK'
      puts "Rollback cancelled."
      next
    end

    require 'tempfile'

    begin
      amazon_service = ActiveStorage::Blob.services.fetch(:amazon)
      linode_service = ActiveStorage::Blob.services.fetch(:linode)
    rescue => e
      abort "Cannot load storage services: #{e.message}"
    end

    linode_blobs = ActiveStorage::Blob.where(service_name: 'linode').order(:id)
    total        = linode_blobs.count

    if total == 0
      puts "No Linode blobs found to roll back."
      next
    end

    puts ""
    puts "Rolling back #{total} blob(s) from Linode → AWS S3..."
    puts ""

    shutdown  = false
    prev_int  = Signal.trap('INT')  { puts "\nInterrupt — finishing current blob then stopping."; shutdown = true }
    prev_term = Signal.trap('TERM') { shutdown = true }

    rolled_back = 0
    failed      = 0
    failures    = []
    start_time  = Time.now

    linode_blobs.find_each(batch_size: 100) do |blob|
      break if shutdown

      begin
        ext = blob.filename.extension_with_delimiter.presence || '.tmp'
        Tempfile.create(["rollback-#{blob.id}", ext]) do |tmp|
          tmp.binmode
          linode_service.download(blob.key) { |chunk| tmp.write(chunk) }
          tmp.rewind
          amazon_service.upload(blob.key, tmp, checksum: blob.checksum)
        end

        blob.update_column(:service_name, 'amazon')
        rolled_back += 1
        storage_print_progress(rolled_back, total, start_time, blob)

      rescue => e
        failed += 1
        failures << { id: blob.id, filename: blob.filename.to_s, error: e.message }
        puts "  [FAILED] Blob #{blob.id} (#{blob.filename}): #{e.message}"
      end
    end

    Signal.trap('INT',  prev_int  || 'DEFAULT')
    Signal.trap('TERM', prev_term || 'DEFAULT')

    remaining = ActiveStorage::Blob.where(service_name: 'linode').count

    puts ""
    puts "=" * 60
    puts "ROLLBACK SUMMARY"
    puts "=" * 60
    puts "Total Linode blobs   : #{total}"
    puts "Rolled back          : #{rolled_back}"
    puts "Failed               : #{failed}"
    puts "Still on Linode      : #{remaining}"
    puts "Stopped early        : yes" if shutdown

    if failures.any?
      puts ""
      puts "Failed rollbacks:"
      failures.each { |f| puts "  Blob #{f[:id]} (#{f[:filename]}): #{f[:error]}" }
    end

    puts ""
    puts remaining > 0 ? "Re-run to continue rollback." : "All blobs rolled back to AWS S3."
    puts "Rollback completed!"
  end

  desc 'Test Linode configuration and upload a test file'
  task test_linode_upload: :environment do
    puts "Testing Linode configuration and upload..."

    puts "Environment variables:"
    puts "  LINODE_ACCESS_KEY_ID:     #{ENV['LINODE_ACCESS_KEY_ID'] ? 'SET' : 'NOT SET'}"
    puts "  LINODE_SECRET_ACCESS_KEY: #{ENV['LINODE_SECRET_ACCESS_KEY'] ? 'SET' : 'NOT SET'}"
    puts "  LINODE_ENDPOINT:          #{ENV['LINODE_ENDPOINT']}"
    puts "  LINODE_REGION:            #{ENV['LINODE_REGION']}"
    puts "  LINODE_BUCKET_NAME:       #{ENV['LINODE_BUCKET_NAME']}"
    puts ""

    # Clean up any stale test blobs first
    stale = ActiveStorage::Blob.where("key LIKE ?", "test-upload-linode-verification%")
    if stale.any?
      puts "Cleaning up #{stale.count} stale test blob(s)..."
      stale.destroy_all
    end

    test_content  = "Linode upload test. Created at #{Time.current}"
    test_key      = "test-upload-linode-verification-#{Time.current.to_i}"
    test_filename = "#{test_key}.txt"

    test_blob = ActiveStorage::Blob.create!(
      key:          test_key,
      filename:     test_filename,
      content_type: 'text/plain',
      metadata:     {},
      byte_size:    test_content.bytesize,
      checksum:     Digest::MD5.base64digest(test_content),
      service_name: 'linode'
    )

    puts "Test blob created (ID: #{test_blob.id}, key: #{test_blob.key})"

    linode_service = ActiveStorage::Blob.services.fetch(:linode)

    begin
      require 'tempfile'
      Tempfile.create(['linode-test', '.txt']) do |tmp|
        tmp.binmode
        tmp.write(test_content)
        tmp.rewind
        linode_service.upload(test_key, tmp, checksum: Digest::MD5.base64digest(test_content))
      end
      puts "✓ Upload succeeded"
    rescue => e
      puts "✗ Upload failed: #{e.message} (#{e.class})"
      test_blob.destroy
      next
    end

    begin
      content = linode_service.download(test_key)
      puts "✓ Download verified (#{content.bytesize} bytes, content match: #{content == test_content})"
    rescue => e
      puts "✗ Download verification failed: #{e.message}"
    end

    # Confirm via direct S3 client
    begin
      s3_client = build_s3_client(
        access_key_id:     ENV['LINODE_ACCESS_KEY_ID'],
        secret_access_key: ENV['LINODE_SECRET_ACCESS_KEY'],
        region:            ENV['LINODE_REGION'],
        endpoint:          ENV['LINODE_ENDPOINT']
      )
      s3_client.head_bucket(bucket: ENV['LINODE_BUCKET_NAME'])
      puts "✓ Bucket '#{ENV['LINODE_BUCKET_NAME']}' is accessible"
      s3_client.head_object(bucket: ENV['LINODE_BUCKET_NAME'], key: test_key)
      puts "✓ File confirmed in bucket"
    rescue => e
      puts "✗ Direct S3 check failed: #{e.message}"
    end

    puts ""
    puts "Test file left in Linode for inspection (key: #{test_key})."
    puts "Run 'rails storage:cleanup_test_blobs' to remove it."
    puts ""
    puts "Test completed!"
  end

  desc 'Diagnose blob service names and migration readiness'
  task diagnose_migration: :environment do
    puts "Diagnosing migration readiness..."
    puts "Environment    : #{Rails.env}"
    puts "Active service : #{Rails.application.config.active_storage.service}"
    puts ""

    puts "All blobs (by service_name):"
    ActiveStorage::Blob.group(:service_name).count.each { |svc, n| puts "  #{svc}: #{n}" }
    puts ""

    puts "Blobs with at least one attachment (by service_name):"
    ActiveStorage::Blob.joins(:attachments).group(:service_name).count.each { |svc, n| puts "  #{svc}: #{n}" }
    puts ""

    source_name = ENV.fetch('SOURCE_SERVICE', 'amazon')
    pending = ActiveStorage::Blob.joins(:attachments).where(service_name: source_name).distinct.count
    puts "Blobs pending migration (service_name='#{source_name}'): #{pending}"

    if pending == 0
      puts ""
      puts "No blobs found with service_name='#{source_name}'."
      puts "Either migration is complete, there are no attachments, or SOURCE_SERVICE is wrong."
      sample = ActiveStorage::Blob.joins(:attachments).limit(5)
      if sample.any?
        puts ""
        puts "Sample blobs:"
        sample.each { |b| puts "  Blob #{b.id}: #{b.filename} (service: #{b.service_name})" }
      end
    else
      puts ""
      puts "#{pending} blob(s) ready to migrate. Run 'rails storage:migrate_blobs_to_linode'."
    end

    puts ""
    puts "Diagnosis completed!"
  end

  desc 'Test Linode delete operations using the test blob created by test_linode_upload'
  task test_linode_delete: :environment do
    puts "Testing Linode delete operations..."
    puts ""

    linode_service = ActiveStorage::Blob.services.fetch(:linode)

    test_blob = ActiveStorage::Blob.where("key LIKE ?", "test-upload-linode-verification%")
                                   .order(created_at: :desc)
                                   .first

    if test_blob.nil?
      puts "✗ No test blob found. Run 'rails storage:test_linode_upload' first."
      next
    end

    puts "Test blob found: ID #{test_blob.id}, key #{test_blob.key}"
    puts ""

    if linode_service.exist?(test_blob.key)
      puts "✓ File is accessible in Linode"
    else
      puts "✗ File not found in Linode bucket (may not have been uploaded)"
    end

    puts ""
    puts "Deleting test file via purge..."
    begin
      test_blob.purge
      puts "✓ Purge completed"
    rescue => e
      puts "✗ Purge failed: #{e.message}"
    end

    unless linode_service.exist?(test_blob.key)
      puts "✓ File confirmed deleted from Linode bucket"
    else
      puts "✗ File still present in Linode bucket after purge"
    end

    puts ""
    puts "Delete test completed!"
  end

  desc 'Clean up test blobs created by test_linode_upload'
  task cleanup_test_blobs: :environment do
    test_blobs = ActiveStorage::Blob.where("key LIKE ?", "test-upload-linode-verification%")

    if test_blobs.none?
      puts "No test blobs found."
      next
    end

    puts "Found #{test_blobs.count} test blob(s):"
    test_blobs.each { |b| puts "  #{b.key} (#{b.filename})" }
    print "Delete these? (y/N): "

    if $stdin.gets.chomp.downcase == 'y'
      test_blobs.destroy_all
      puts "✓ Test blobs cleaned up."
    else
      puts "Cleanup cancelled."
    end
  end

  desc 'Show storage configuration, blob distribution, and pending migration count'
  task status: :environment do
    puts "Storage configuration:"
    puts "  Active service : #{Rails.application.config.active_storage.service}"
    puts "  Environment    : #{Rails.env}"
    puts ""

    puts "Blob distribution (by service_name):"
    counts = ActiveStorage::Blob.group(:service_name).count
    if counts.empty?
      puts "  (no blobs)"
    else
      counts.each { |svc, n| puts "  #{svc}: #{n}" }
    end
    puts ""

    total_blobs       = ActiveStorage::Blob.count
    pending_migration = ActiveStorage::Blob.joins(:attachments).where.not(service_name: 'linode').distinct.count
    fully_migrated    = ActiveStorage::Blob.joins(:attachments).where(service_name: 'linode').distinct.count

    puts "Migration progress:"
    puts "  Migrated to Linode   : #{fully_migrated}"
    puts "  Still pending        : #{pending_migration}"
    puts "  Total attached blobs : #{fully_migrated + pending_migration}"
    puts ""

    puts "Attachment statistics:"
    total_transactions              = Transaction.count
    transactions_with_attachments   = Transaction.joins(:attachments_attachments).count
    pct = total_transactions > 0 ? (transactions_with_attachments.to_f / total_transactions * 100).round(2) : 0

    puts "  Total transactions              : #{total_transactions}"
    puts "  Transactions with attachments   : #{transactions_with_attachments} (#{pct}%)"
    puts "  Total blobs (incl. orphans)     : #{total_blobs}"
  end
end
