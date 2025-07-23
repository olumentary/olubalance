# frozen_string_literal: true

namespace :storage do
  desc 'Migrate transaction attachments from AWS S3 to Linode S3-compatible storage'
  task migrate_to_linode: :environment do
    puts "Starting migration of transaction attachments from AWS S3 to Linode..."
    
    # Store original storage service
    original_service = Rails.application.config.active_storage.service
    
    # Count total attachments to migrate
    total_attachments = Transaction.joins(:attachment_attachment).count
    puts "Found #{total_attachments} attachments to migrate"
    
    if total_attachments == 0
      puts "No attachments found to migrate. Exiting."
      return
    end
    
    migrated_count = 0
    failed_count = 0
    failed_transactions = []
    
    # Process each transaction with an attachment
    Transaction.joins(:attachment_attachment).find_each do |transaction|
      begin
        puts "Migrating attachment for transaction #{transaction.id} (#{transaction.description})"
        
        # Get the current attachment
        attachment = transaction.attachment
        
        if attachment.blank?
          puts "  Skipping - no attachment found"
          next
        end
        
        # Store original attachment details
        original_filename = attachment.filename
        original_content_type = attachment.content_type
        original_byte_size = attachment.byte_size
        
        # Download the file from AWS S3
        puts "  Downloading from AWS S3..."
        downloaded_file = attachment.download
        
        # Temporarily switch to Linode storage
        Rails.application.config.active_storage.service = :linode
        
        # Upload to Linode
        puts "  Uploading to Linode..."
        transaction.attachment.attach(
          io: StringIO.new(downloaded_file),
          filename: original_filename,
          content_type: original_content_type
        )
        
        # Switch back to original storage
        Rails.application.config.active_storage.service = original_service
        
        # Verify the new attachment
        if transaction.attachment.attached?
          puts "  ✓ Successfully migrated"
          migrated_count += 1
        else
          puts "  ✗ Failed to verify attachment"
          failed_count += 1
          failed_transactions << { id: transaction.id, error: "Failed to verify attachment" }
        end
        
      rescue => e
        puts "  ✗ Error migrating transaction #{transaction.id}: #{e.message}"
        failed_count += 1
        failed_transactions << { id: transaction.id, error: e.message }
        
        # Ensure we're back to original storage service
        Rails.application.config.active_storage.service = original_service
      end
    end
    
    # Print summary
    puts "\n" + "="*50
    puts "MIGRATION SUMMARY"
    puts "="*50
    puts "Total attachments: #{total_attachments}"
    puts "Successfully migrated: #{migrated_count}"
    puts "Failed: #{failed_count}"
    
    if failed_transactions.any?
      puts "\nFailed transactions:"
      failed_transactions.each do |failure|
        puts "  Transaction #{failure[:id]}: #{failure[:error]}"
      end
    end
    
    puts "\nMigration completed!"
  end
  
  desc 'Migrate using ActiveStorage blob records (more robust method)'
  task migrate_blobs_to_linode: :environment do
    puts "Starting migration of ActiveStorage blobs from AWS S3 to Linode..."
    
    # Store original storage service
    original_service = Rails.application.config.active_storage.service
    
    # First, let's see what service names are actually in the database
    puts "Current blob service distribution:"
    ActiveStorage::Blob.group(:service_name).count.each do |service, count|
      puts "  #{service}: #{count} blobs"
    end
    puts ""
    
    # Find all blobs that are currently stored on AWS
    current_service = Rails.application.config.active_storage.service.to_s
    aws_service_name = current_service
    puts "Looking for blobs with service_name: #{aws_service_name}"
    
    aws_blobs = ActiveStorage::Blob.joins(:attachments)
                                   .where(service_name: aws_service_name)
                                   .distinct
    
    total_blobs = aws_blobs.count
    puts "Found #{total_blobs} blobs to migrate"
    
    if total_blobs == 0
      puts "No blobs found to migrate. Exiting."
      puts "\nBlob migration completed!"
    else
      migrated_count = 0
      failed_count = 0
      failed_blobs = []
      
      aws_blobs.find_each do |blob|
      begin
        puts "Migrating blob #{blob.id} (#{blob.filename})"
        
        # Download the file from AWS S3
        puts "  Downloading from AWS S3..."
        downloaded_file = blob.download
        
        # Create a new blob record for Linode with a unique key
        puts "  Creating new blob record for Linode..."
        new_key = "linode-migrated-#{SecureRandom.hex(16)}"
        new_blob = ActiveStorage::Blob.create!(
          key: new_key,
          filename: blob.filename,
          content_type: blob.content_type,
          metadata: blob.metadata,
          byte_size: blob.byte_size,
          checksum: blob.checksum,
          service_name: 'linode'
        )
        
        puts "    New blob created:"
        puts "      ID: #{new_blob.id}"
        puts "      Key: #{new_blob.key}"
        puts "      Filename: #{new_blob.filename}"
        puts "      Service: #{new_blob.service_name}"
        
        # Upload the file to Linode using the new blob
        puts "  Uploading to Linode..."
        puts "    Blob key: #{new_blob.key}"
        puts "    Blob filename: #{new_blob.filename}"
        puts "    Blob size: #{downloaded_file.bytesize} bytes"
        puts "    Target service: 'linode'"
        
        begin
          new_blob.upload(StringIO.new(downloaded_file))
          puts "    ✓ Upload call completed without error"
        rescue => e
          puts "    ✗ Upload failed: #{e.message}"
          puts "    Error class: #{e.class}"
          puts "    Backtrace: #{e.backtrace.first(5).join("\n      ")}"
          # Clean up the new blob if upload fails
          new_blob.destroy
          raise e
        end
        
        # Verify the file was actually uploaded to Linode
        puts "  Verifying upload to Linode..."
        begin
          # Try to download a small portion to verify it's accessible
          puts "    Attempting to open file for verification..."
          new_blob.open do |file|
            data = file.read(1)
            puts "    ✓ File opened successfully, read #{data.bytesize} bytes"
          end
          puts "  ✓ File verified on Linode"
        rescue => e
          puts "  ✗ File verification failed: #{e.message}"
          puts "    Error class: #{e.class}"
          puts "    Backtrace: #{e.backtrace.first(5).join("\n      ")}"
          # Clean up the new blob if verification fails
          new_blob.destroy
          raise e
        end
        
        # Update all attachments to use the new blob
        puts "  Updating attachments to use new blob..."
        blob.attachments.update_all(blob_id: new_blob.id)
        puts "    ✓ Attachments updated"
        
        # Delete the old blob record
        puts "  Cleaning up old blob record..."
        blob.destroy
        puts "    ✓ Old blob record deleted"
        
        puts "  ✓ Successfully migrated"
        migrated_count += 1
        
      rescue => e
        puts "  ✗ Error migrating blob #{blob.id}: #{e.message}"
        failed_count += 1
        failed_blobs << { id: blob.id, filename: blob.filename, error: e.message }
        
        # Ensure we're back to original storage service
        Rails.application.config.active_storage.service = original_service
      end
    end
    
    # Print summary
    puts "\n" + "="*50
    puts "BLOB MIGRATION SUMMARY"
    puts "="*50
    puts "Total blobs: #{total_blobs}"
    puts "Successfully migrated: #{migrated_count}"
    puts "Failed: #{failed_count}"
    
    if failed_blobs.any?
      puts "\nFailed blobs:"
      failed_blobs.each do |failure|
        puts "  Blob #{failure[:id]} (#{failure[:filename]}): #{failure[:error]}"
      end
    end
    
    puts "\nBlob migration completed!"
    end
  end
  
  desc 'Verify migration by checking attachment accessibility on Linode'
  task verify_linode_migration: :environment do
    puts "Verifying Linode migration..."
    
    # Switch to Linode storage
    original_service = Rails.application.config.active_storage.service
    Rails.application.config.active_storage.service = :linode
    
    total_attachments = Transaction.joins(:attachment_attachment).count
    verified_count = 0
    failed_count = 0
    
    Transaction.joins(:attachment_attachment).find_each do |transaction|
      begin
        attachment = transaction.attachment
        
        if attachment.attached?
          # Try to access the attachment by downloading a small portion
          # This verifies the file is accessible without needing URL generation
          begin
            # Try to read the first few bytes to verify accessibility
            attachment.open do |file|
              file.read(1) # Just read 1 byte to verify the file is accessible
            end
            puts "  ✓ Transaction #{transaction.id}: #{attachment.filename} - Accessible"
            verified_count += 1
          rescue => e
            puts "  ✗ Transaction #{transaction.id}: #{attachment.filename} - Not accessible: #{e.message}"
            failed_count += 1
          end
        else
          puts "  ✗ Transaction #{transaction.id}: No attachment found"
          failed_count += 1
        end
      rescue => e
        puts "  ✗ Transaction #{transaction.id}: Error - #{e.message}"
        failed_count += 1
      end
    end
    
    # Switch back to original storage
    Rails.application.config.active_storage.service = original_service
    
    puts "\n" + "="*50
    puts "VERIFICATION SUMMARY"
    puts "="*50
    puts "Total attachments: #{total_attachments}"
    puts "Verified: #{verified_count}"
    puts "Failed: #{failed_count}"
  end
  
  desc 'Clean up old AWS S3 attachments after successful migration'
  task cleanup_aws_attachments: :environment do
    puts "WARNING: This will permanently delete all attachments from AWS S3!"
    puts "Make sure you have verified the migration was successful before proceeding."
    print "Type 'YES' to continue: "
    
    confirmation = STDIN.gets.chomp
    
    if confirmation != 'YES'
      puts "Cleanup cancelled."
      return
    end
    
    puts "Starting cleanup of AWS S3 attachments..."
    
    # Switch to AWS storage
    original_service = Rails.application.config.active_storage.service
    Rails.application.config.active_storage.service = :amazon
    
    cleaned_count = 0
    
    Transaction.joins(:attachment_attachment).find_each do |transaction|
      begin
        attachment = transaction.attachment
        
        if attachment.attached?
          puts "  Cleaning up attachment for transaction #{transaction.id}"
          attachment.purge
          cleaned_count += 1
        end
      rescue => e
        puts "  ✗ Error cleaning up transaction #{transaction.id}: #{e.message}"
      end
    end
    
    # Switch back to original storage
    Rails.application.config.active_storage.service = original_service
    
    puts "\n" + "="*50
    puts "CLEANUP SUMMARY"
    puts "="*50
    puts "Cleaned up: #{cleaned_count} attachments"
    puts "Cleanup completed!"
  end
  
  desc 'Validate files exist in Linode bucket by checking bucket contents directly'
  task validate_linode_bucket: :environment do
    puts "Validating files in Linode bucket..."
    
    # Get Linode configuration
    service_name = 'linode'
    bucket_name = ENV['LINODE_BUCKET_NAME']
    
    puts "  Service: #{service_name}"
    puts "  Bucket: #{bucket_name}"
    puts ""
    
    # Create a temporary service instance to access Linode directly
    require 'aws-sdk-s3'
    
    s3_client = Aws::S3::Client.new(
      access_key_id: ENV['LINODE_ACCESS_KEY_ID'],
      secret_access_key: ENV['LINODE_SECRET_ACCESS_KEY'],
      region: ENV['LINODE_REGION'],
      endpoint: ENV['LINODE_ENDPOINT'],
      force_path_style: true
    )
    
    # Get all blobs that should be on Linode
    linode_blobs = ActiveStorage::Blob.where(service_name: service_name)
    
    puts "Database shows #{linode_blobs.count} blobs should be on Linode"
    puts ""
    
    found_count = 0
    missing_count = 0
    missing_files = []
    
    linode_blobs.find_each do |blob|
      begin
        # Check if the file exists in the bucket
        s3_client.head_object(bucket: bucket_name, key: blob.key)
        puts "  ✓ #{blob.filename} (key: #{blob.key})"
        found_count += 1
      rescue Aws::S3::Errors::NoSuchKey
        puts "  ✗ #{blob.filename} (key: #{blob.key}) - NOT FOUND IN BUCKET"
        missing_count += 1
        missing_files << { id: blob.id, filename: blob.filename, key: blob.key }
      rescue => e
        puts "  ✗ #{blob.filename} (key: #{blob.key}) - ERROR: #{e.message}"
        missing_count += 1
        missing_files << { id: blob.id, filename: blob.filename, key: blob.key, error: e.message }
      end
    end
    
    puts "\n" + "="*50
    puts "BUCKET VALIDATION SUMMARY"
    puts "="*50
    puts "Total blobs in database: #{linode_blobs.count}"
    puts "Found in bucket: #{found_count}"
    puts "Missing from bucket: #{missing_count}"
    
    if missing_files.any?
      puts "\nMissing files:"
      missing_files.each do |missing|
        puts "  Blob #{missing[:id]}: #{missing[:filename]} (key: #{missing[:key]})"
        puts "    Error: #{missing[:error]}" if missing[:error]
      end
    end
    
    puts "\nBucket validation completed!"
  end
  
  desc 'Recover missing files by checking AWS S3 and restoring them'
  task recover_missing_files: :environment do
    puts "Recovering missing files..."
    puts "This will check AWS S3 for missing files and restore them"
    print "Type 'RECOVER' to continue: "
    
    confirmation = STDIN.gets.chomp
    
    if confirmation != 'RECOVER'
      puts "Recovery cancelled."
      return
    end
    
    puts "Starting file recovery..."
    
    # Store original storage service
    original_service = Rails.application.config.active_storage.service
    
    # Find all blobs that have missing files
    all_blobs = ActiveStorage::Blob.joins(:attachments).distinct
    missing_files = []
    
    puts "Checking #{all_blobs.count} blobs for missing files..."
    
    all_blobs.find_each do |blob|
      begin
        # Try to access the file
        blob.open do |file|
          file.read(1)
        end
        puts "  ✓ #{blob.filename} - Accessible"
      rescue => e
        puts "  ✗ #{blob.filename} - Missing: #{e.message}"
        missing_files << blob
      end
    end
    
    if missing_files.empty?
      puts "\nNo missing files found!"
      return
    end
    
    puts "\nFound #{missing_files.count} missing files. Attempting recovery..."
    
    recovered_count = 0
    failed_count = 0
    
    missing_files.each do |blob|
      begin
        puts "Recovering #{blob.filename}..."
        
        # Try to recover from AWS S3 first
        Rails.application.config.active_storage.service = :amazon
        
        begin
          # Check if file exists on AWS
          aws_blob = ActiveStorage::Blob.find(blob.id)
          aws_blob.open do |file|
            file.read(1)
          end
          puts "  ✓ File found on AWS, restoring..."
          
          # Download from AWS
          downloaded_file = aws_blob.download
          
          # Switch to Linode and upload
          Rails.application.config.active_storage.service = :linode
          blob.upload(StringIO.new(downloaded_file))
          blob.update!(service_name: 'linode')
          
          puts "  ✓ Successfully recovered and migrated to Linode"
          recovered_count += 1
          
        rescue => e
          puts "  ✗ File not found on AWS: #{e.message}"
          failed_count += 1
        end
        
      rescue => e
        puts "  ✗ Error recovering #{blob.filename}: #{e.message}"
        failed_count += 1
      end
    end
    
    # Switch back to original storage
    Rails.application.config.active_storage.service = original_service
    
    puts "\n" + "="*50
    puts "RECOVERY SUMMARY"
    puts "="*50
    puts "Missing files found: #{missing_files.count}"
    puts "Successfully recovered: #{recovered_count}"
    puts "Failed to recover: #{failed_count}"
    
    if failed_count > 0
      puts "\nSome files could not be recovered from AWS S3."
      puts "You may need to manually restore these files from backups."
    end
    
    puts "\nRecovery completed!"
  end
  
  desc 'Rollback migration by restoring blobs to AWS S3 service'
  task rollback_migration: :environment do
    puts "WARNING: This will rollback the Linode migration and restore blobs to AWS S3"
    puts "This should only be used if the migration failed and you need to restore the previous state"
    print "Type 'ROLLBACK' to continue: "
    
    confirmation = STDIN.gets.chomp
    
    if confirmation != 'ROLLBACK'
      puts "Rollback cancelled."
      return
    end
    
    puts "Starting rollback of Linode migration..."
    
    # Store original storage service
    original_service = Rails.application.config.active_storage.service
    
    # Find all blobs that were migrated to Linode
    linode_service_name = 'linode'
    aws_service_name = 'amazon'
    
    linode_blobs = ActiveStorage::Blob.where(service_name: linode_service_name)
    
    puts "Found #{linode_blobs.count} blobs to rollback"
    
    if linode_blobs.count == 0
      puts "No Linode blobs found to rollback. Exiting."
      return
    end
    
    rolled_back_count = 0
    failed_count = 0
    failed_blobs = []
    
    linode_blobs.find_each do |blob|
      begin
        puts "Rolling back blob #{blob.id} (#{blob.filename})"
        
        # Switch to AWS storage
        Rails.application.config.active_storage.service = :amazon
        
        # Check if the file still exists on AWS
        begin
          # Try to access the file on AWS
          blob.open do |file|
            file.read(1)
          end
          puts "  ✓ File found on AWS"
        rescue => e
          puts "  ⚠️  File not found on AWS: #{e.message}"
          puts "  This blob may have been deleted from AWS during migration"
        end
        
        # Restore the service name to AWS
        blob.update!(service_name: aws_service_name)
        
        puts "  ✓ Successfully rolled back"
        rolled_back_count += 1
        
      rescue => e
        puts "  ✗ Error rolling back blob #{blob.id}: #{e.message}"
        failed_count += 1
        failed_blobs << { id: blob.id, filename: blob.filename, error: e.message }
      end
    end
    
    # Switch back to original storage
    Rails.application.config.active_storage.service = original_service
    
    # Print summary
    puts "\n" + "="*50
    puts "ROLLBACK SUMMARY"
    puts "="*50
    puts "Total blobs: #{linode_blobs.count}"
    puts "Successfully rolled back: #{rolled_back_count}"
    puts "Failed: #{failed_count}"
    
    if failed_blobs.any?
      puts "\nFailed rollbacks:"
      failed_blobs.each do |failure|
        puts "  Blob #{failure[:id]} (#{failure[:filename]}): #{failure[:error]}"
      end
    end
    
    puts "\nRollback completed!"
    puts "Your blobs should now be pointing back to AWS S3"
  end
  
  desc 'Test Linode configuration and upload a test file'
  task test_linode_upload: :environment do
    puts "Testing Linode configuration and upload..."
    
    # Check environment variables
    puts "Environment variables:"
    puts "  LINODE_ACCESS_KEY_ID: #{ENV['LINODE_ACCESS_KEY_ID'] ? 'SET' : 'NOT SET'}"
    puts "  LINODE_SECRET_ACCESS_KEY: #{ENV['LINODE_SECRET_ACCESS_KEY'] ? 'SET' : 'NOT SET'}"
    puts "  LINODE_ENDPOINT: #{ENV['LINODE_ENDPOINT']}"
    puts "  LINODE_REGION: #{ENV['LINODE_REGION']}"
    puts "  LINODE_BUCKET_NAME: #{ENV['LINODE_BUCKET_NAME']}"
    puts ""
    
    # Store original storage service
    original_service = Rails.application.config.active_storage.service
    puts "Original storage service: #{original_service}"
    
    # Switch to Linode storage
    target_service = :linode
    puts "Switching to: #{target_service}"
    Rails.application.config.active_storage.service = target_service
    
    # Create a test blob
    puts "Creating test blob..."
    test_content = "This is a test file for Linode upload verification. Created at #{Time.current}"
    test_blob = ActiveStorage::Blob.create!(
      key: "test-upload-linode-verification",
      filename: "test-upload-linode-verification.txt",
      content_type: "text/plain",
      metadata: {},
      byte_size: test_content.bytesize,
      checksum: Digest::MD5.hexdigest(test_content),
      service_name: 'linode'
    )
    
    puts "Test blob created:"
    puts "  ID: #{test_blob.id}"
    puts "  Key: #{test_blob.key}"
    puts "  Filename: #{test_blob.filename}"
    puts "  Service: #{test_blob.service_name}"
    puts ""
    
    # Upload the test file
    puts "Uploading test file..."
    begin
      test_blob.upload(StringIO.new(test_content))
      puts "✓ Upload call completed"
    rescue => e
      puts "✗ Upload failed: #{e.message}"
      puts "Error class: #{e.class}"
      puts "Backtrace: #{e.backtrace.first(10).join("\n  ")}"
      
      # Clean up the test blob
      test_blob.destroy
      
      # Switch back to original storage
      Rails.application.config.active_storage.service = original_service
      return
    end
    
    # Verify the upload
    puts "Verifying upload..."
    begin
      test_blob.open do |file|
        downloaded_content = file.read
        puts "✓ File downloaded successfully"
        puts "  Expected size: #{test_content.bytesize} bytes"
        puts "  Actual size: #{downloaded_content.bytesize} bytes"
        puts "  Content matches: #{test_content == downloaded_content}"
      end
    rescue => e
      puts "✗ Verification failed: #{e.message}"
      puts "Error class: #{e.class}"
      puts "Backtrace: #{e.backtrace.first(5).join("\n  ")}"
    end
    
    # Test direct S3 access
    puts "Testing direct S3 access..."
    begin
      require 'aws-sdk-s3'
      
      s3_client = Aws::S3::Client.new(
        access_key_id: ENV['LINODE_ACCESS_KEY_ID'],
        secret_access_key: ENV['LINODE_SECRET_ACCESS_KEY'],
        region: ENV['LINODE_REGION'],
        endpoint: ENV['LINODE_ENDPOINT'],
        force_path_style: true
      )
      
      bucket_name = ENV['LINODE_BUCKET_NAME']
      
      # Check if bucket exists
      begin
        s3_client.head_bucket(bucket: bucket_name)
        puts "✓ Bucket '#{bucket_name}' exists"
      rescue => e
        puts "✗ Bucket '#{bucket_name}' not accessible: #{e.message}"
      end
      
      # Check if file exists in bucket
      begin
        s3_client.head_object(bucket: bucket_name, key: test_blob.key)
        puts "✓ File found in bucket with key: #{test_blob.key}"
      rescue => e
        puts "✗ File not found in bucket: #{e.message}"
      end
      
    rescue => e
      puts "✗ S3 client test failed: #{e.message}"
    end
    
    # Note: Test file left in Linode for manual inspection
    puts "Test file uploaded successfully and left in Linode for inspection"
    puts "You can manually delete it later using: bundle exec rails storage:test_linode_delete"
    
    # Switch back to original storage
    Rails.application.config.active_storage.service = original_service
    puts "Switched back to: #{original_service}"
    
    puts "\nTest completed!"
  end
  
  desc 'Diagnose blob service names and migration readiness'
  task diagnose_migration: :environment do
    puts "Diagnosing migration readiness..."
    puts "Environment: #{Rails.env}"
    puts "Current storage service: #{Rails.application.config.active_storage.service}"
    puts ""
    
    # Check all blobs and their service names
    puts "All blobs in database:"
    ActiveStorage::Blob.group(:service_name).count.each do |service, count|
      puts "  #{service}: #{count} blobs"
    end
    puts ""
    
    # Check blobs with attachments
    puts "Blobs with attachments:"
    ActiveStorage::Blob.joins(:attachments).group(:service_name).count.each do |service, count|
      puts "  #{service}: #{count} blobs"
    end
    puts ""
    
    # Check what the migration script is looking for
    aws_service_name = 'amazon'
    puts "Migration script is looking for service_name: '#{aws_service_name}'"
    
    # Check if any blobs match this service name
    matching_blobs = ActiveStorage::Blob.joins(:attachments).where(service_name: aws_service_name).distinct
    puts "Found #{matching_blobs.count} blobs with service_name '#{aws_service_name}'"
    
    if matching_blobs.count == 0
      puts ""
      puts "⚠️  No blobs found with service_name '#{aws_service_name}'"
      puts "This means either:"
      puts "  1. Your blobs use a different service name"
      puts "  2. You have no attachments to migrate"
      puts "  3. The migration has already been completed"
      puts ""
      
      # Show some example blobs
      sample_blobs = ActiveStorage::Blob.joins(:attachments).limit(5)
      if sample_blobs.any?
        puts "Sample blobs with attachments:"
        sample_blobs.each do |blob|
          puts "  Blob #{blob.id}: #{blob.filename} (service: #{blob.service_name})"
        end
      end
    else
      puts ""
      puts "✅ Found blobs to migrate!"
      puts "Sample blobs that will be migrated:"
      matching_blobs.limit(5).each do |blob|
        puts "  Blob #{blob.id}: #{blob.filename}"
      end
    end
    
    puts ""
    puts "Diagnosis completed!"
  end
  
  desc 'Test Linode delete operations specifically'
  task test_linode_delete: :environment do
    puts "Testing Linode delete operations..."
    
    # Check environment variables
    puts "Environment variables:"
    puts "  LINODE_ACCESS_KEY_ID: #{ENV['LINODE_ACCESS_KEY_ID'] ? 'SET' : 'NOT SET'}"
    puts "  LINODE_SECRET_ACCESS_KEY: #{ENV['LINODE_SECRET_ACCESS_KEY'] ? 'SET' : 'NOT SET'}"
    puts "  LINODE_ENDPOINT: #{ENV['LINODE_ENDPOINT']}"
    puts "  LINODE_REGION: #{ENV['LINODE_REGION']}"
    puts "  LINODE_BUCKET_NAME: #{ENV['LINODE_BUCKET_NAME']}"
    puts ""
    
    # Store original storage service
    original_service = Rails.application.config.active_storage.service
    puts "Original storage service: #{original_service}"
    
    # Switch to Linode storage
    target_service = :linode
    puts "Switching to: #{target_service}"
    Rails.application.config.active_storage.service = target_service
    
    # Look for the test blob created by the upload task
    test_key = "test-upload-linode-verification"
    test_filename = "test-upload-linode-verification.txt"
    
    puts "Looking for test blob created by upload task..."
    puts "  Key: #{test_key}"
    puts "  Filename: #{test_filename}"
    puts ""
    
    # Try to find the blob in the database
    test_blob = ActiveStorage::Blob.find_by(key: test_key)
    
    if test_blob.nil?
      puts "✗ Test blob not found in database"
      puts "Please run 'bundle exec rails storage:test_linode_upload' first to create the test file"
      Rails.application.config.active_storage.service = original_service
      return
    end
    
    puts "✓ Test blob found in database:"
    puts "  ID: #{test_blob.id}"
    puts "  Key: #{test_blob.key}"
    puts "  Filename: #{test_blob.filename}"
    puts "  Service: #{test_blob.service_name}"
    puts ""
    
    # Verify the file exists via ActiveStorage
    puts "Verifying file exists via ActiveStorage..."
    begin
      test_blob.open do |file|
        downloaded_content = file.read
        puts "✓ File accessible via ActiveStorage (size: #{downloaded_content.bytesize} bytes)"
      end
    rescue => e
      puts "✗ File not accessible via ActiveStorage: #{e.message}"
    end
    
    # Test direct S3 access to confirm file exists
    puts "Confirming file exists via direct S3 access..."
    begin
      require 'aws-sdk-s3'
      
      s3_client = Aws::S3::Client.new(
        access_key_id: ENV['LINODE_ACCESS_KEY_ID'],
        secret_access_key: ENV['LINODE_SECRET_ACCESS_KEY'],
        region: ENV['LINODE_REGION'],
        endpoint: ENV['LINODE_ENDPOINT'],
        force_path_style: true
      )
      
      bucket_name = ENV['LINODE_BUCKET_NAME']
      
      # Check if file exists in bucket
      begin
        s3_client.head_object(bucket: bucket_name, key: test_blob.key)
        puts "✓ File confirmed in bucket"
      rescue => e
        puts "✗ File not found in bucket: #{e.message}"
      end
      
    rescue => e
      puts "✗ S3 client test failed: #{e.message}"
    end
    
    # Now test the delete operation
    puts "\n" + "="*50
    puts "TESTING DELETE OPERATION"
    puts "="*50
    
    # Make sure we're on the correct storage service
    puts "Current storage service: #{Rails.application.config.active_storage.service}"
    puts "Target service: #{target_service}"
    
    if Rails.application.config.active_storage.service != target_service
      puts "Switching to target service for deletion..."
      Rails.application.config.active_storage.service = target_service
    end
    
    # Test 1: Try purge (deletes file from storage)
    puts "\nTest 1: Testing purge operation..."
    begin
      test_blob.purge
      puts "✓ Purge operation completed"
    rescue => e
      puts "✗ Purge failed: #{e.message}"
      puts "Error class: #{e.class}"
      puts "Backtrace: #{e.backtrace.first(5).join("\n  ")}"
    end
    
    # Test 2: Try destroy (deletes database record)
    puts "\nTest 2: Testing destroy operation..."
    begin
      test_blob.destroy
      puts "✓ Destroy operation completed"
    rescue => e
      puts "✗ Destroy failed: #{e.message}"
      puts "Error class: #{e.class}"
      puts "Backtrace: #{e.backtrace.first(5).join("\n  ")}"
    end
    
    # Verify deletion via direct S3 access
    puts "\nVerifying deletion via direct S3 access..."
    begin
      s3_client.head_object(bucket: bucket_name, key: test_blob.key)
      puts "⚠️  File still exists in bucket after deletion"
    rescue Aws::S3::Errors::NoSuchKey
      puts "✓ File successfully deleted from bucket"
    rescue => e
      puts "✗ Error checking file existence: #{e.message}"
    end
    
    # Switch back to original storage
    Rails.application.config.active_storage.service = original_service
    puts "\nSwitched back to: #{original_service}"
    
    puts "\nDelete test completed!"
  end
  
  desc 'Show current storage configuration and attachment counts'
  task status: :environment do
    puts "Current storage configuration:"
    puts "  Service: #{Rails.application.config.active_storage.service}"
    puts "  Environment: #{Rails.env}"
    
    puts "\nAttachment statistics:"
    total_transactions = Transaction.count
    transactions_with_attachments = Transaction.joins(:attachment_attachment).count
    
    puts "  Total transactions: #{total_transactions}"
    puts "  Transactions with attachments: #{transactions_with_attachments}"
    puts "  Attachment percentage: #{total_transactions > 0 ? (transactions_with_attachments.to_f / total_transactions * 100).round(2) : 0}%"
    
    puts "\nBlob storage distribution:"
    ActiveStorage::Blob.group(:service_name).count.each do |service, count|
      puts "  #{service}: #{count} blobs"
    end
  end
end 