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
        Rails.application.config.active_storage.service = Rails.env.production? ? :linode : :linode_dev
        
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
    
    # Find all blobs that are currently stored on AWS
    aws_blobs = ActiveStorage::Blob.joins(:attachments)
                                   .where(service_name: Rails.env.production? ? 'amazon' : 'amazondev')
                                   .distinct
    
    total_blobs = aws_blobs.count
    puts "Found #{total_blobs} blobs to migrate"
    
    if total_blobs == 0
      puts "No blobs found to migrate. Exiting."
      return
    end
    
    migrated_count = 0
    failed_count = 0
    failed_blobs = []
    
    aws_blobs.find_each do |blob|
      begin
        puts "Migrating blob #{blob.id} (#{blob.filename})"
        
        # Download the file from AWS S3
        puts "  Downloading from AWS S3..."
        downloaded_file = blob.download
        
        # Create a new blob record for Linode
        puts "  Creating new blob record for Linode..."
        new_blob = ActiveStorage::Blob.create!(
          key: blob.key,
          filename: blob.filename,
          content_type: blob.content_type,
          metadata: blob.metadata,
          byte_size: blob.byte_size,
          checksum: blob.checksum,
          service_name: Rails.env.production? ? 'linode' : 'linode_dev'
        )
        
        # Temporarily switch to Linode storage
        Rails.application.config.active_storage.service = Rails.env.production? ? :linode : :linode_dev
        
        # Upload the file to Linode
        puts "  Uploading to Linode..."
        new_blob.upload(StringIO.new(downloaded_file))
        
        # Switch back to original storage
        Rails.application.config.active_storage.service = original_service
        
        # Update all attachments to use the new blob
        blob.attachments.update_all(blob_id: new_blob.id)
        
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
  
  desc 'Verify migration by checking attachment accessibility on Linode'
  task verify_linode_migration: :environment do
    puts "Verifying Linode migration..."
    
    # Switch to Linode storage
    original_service = Rails.application.config.active_storage.service
    Rails.application.config.active_storage.service = Rails.env.production? ? :linode : :linode_dev
    
    total_attachments = Transaction.joins(:attachment_attachment).count
    verified_count = 0
    failed_count = 0
    
    Transaction.joins(:attachment_attachment).find_each do |transaction|
      begin
        attachment = transaction.attachment
        
        if attachment.attached?
          # Try to access the attachment URL
          url = Rails.application.routes.url_helpers.rails_blob_url(attachment)
          puts "  ✓ Transaction #{transaction.id}: #{attachment.filename} - #{url}"
          verified_count += 1
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
    Rails.application.config.active_storage.service = Rails.env.production? ? :amazon : :amazondev
    
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