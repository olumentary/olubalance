# Linode Storage Migration Guide

This guide explains how to migrate your transaction attachments from AWS S3 to Linode S3-compatible storage.

## Prerequisites

Before starting the migration, ensure you have:

1. **Linode Object Storage Account**: Set up a Linode account with Object Storage enabled
2. **S3-Compatible Credentials**: Generate access keys for your Linode Object Storage
3. **Buckets Created**: Create buckets for both development and production environments
4. **Environment Variables**: Configure the following environment variables:

### Required Environment Variables

```bash
# Linode S3-compatible storage credentials
LINODE_ACCESS_KEY_ID=your_access_key_id
LINODE_SECRET_ACCESS_KEY=your_secret_access_key
LINODE_ENDPOINT=https://your-region.linodeobjects.com
LINODE_REGION=your-region

# Bucket names
LINODE_BUCKET_NAME=your-production-bucket-name
LINODE_BUCKET_NAME_DEV=your-development-bucket-name
```

## Migration Process

### Step 1: Deploy the New Configuration

1. Deploy the updated code with the new storage configuration
2. Ensure the Linode environment variables are set in your deployment environment
3. Verify the storage configuration is working:

```bash
bundle exec rails storage:status
```

### Step 2: Run the Migration

Use the provided migration script:

```bash
./bin/migrate_to_linode
```

Or run the rake tasks manually:

```bash
# Check current status
bundle exec rails storage:status

# Run the migration (recommended method)
bundle exec rails storage:migrate_blobs_to_linode

# Verify the migration
bundle exec rails storage:verify_linode_migration
```

### Step 3: Update Environment Configuration

After successful migration, update your environment configurations:

#### For Production (`config/environments/production.rb`):

```ruby
# Change from:
config.active_storage.service = :amazon

# To:
config.active_storage.service = :linode
```

#### For Development (`config/environments/development.rb`):

```ruby
# Change from:
config.active_storage.service = :amazondev

# To:
config.active_storage.service = :linode_dev
```

### Step 4: Cleanup (Optional)

After verifying everything works correctly, you can clean up the old AWS S3 attachments:

```bash
bundle exec rails storage:cleanup_aws_attachments
```

**⚠️ Warning**: This will permanently delete all attachments from AWS S3. Only run this after you're confident the migration was successful.

## Available Rake Tasks

### `storage:status`

Shows current storage configuration and attachment statistics.

### `storage:migrate_to_linode`

Migrates transaction attachments using the transaction-level approach.

### `storage:migrate_blobs_to_linode`

Migrates ActiveStorage blobs using the blob-level approach (recommended).

### `storage:verify_linode_migration`

Verifies that all attachments are accessible on Linode storage.

### `storage:cleanup_aws_attachments`

Removes old attachments from AWS S3 (requires confirmation).

## Troubleshooting

### Common Issues

1. **Environment Variables Not Set**

   - Ensure all Linode environment variables are properly configured
   - Check that bucket names match your Linode Object Storage buckets

2. **Migration Fails**

   - Check Linode Object Storage credentials
   - Verify bucket permissions
   - Ensure sufficient storage space on Linode

3. **Attachments Not Accessible**
   - Verify the migration completed successfully
   - Check that the storage service is correctly configured
   - Ensure Linode Object Storage is accessible from your application

### Rollback Plan

If you need to rollback to AWS S3:

1. Update environment configuration back to AWS S3
2. Redeploy the application
3. If needed, restore attachments from AWS S3 backups

## Storage Configuration

The updated `config/storage.yml` includes configurations for both AWS S3 and Linode:

```yaml
# AWS S3 (existing)
amazondev:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['S3_REGION'] %>
  bucket: <%= ENV['S3_BUCKET_NAME_DEV'] %>

amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['S3_REGION'] %>
  bucket: <%= ENV['S3_BUCKET_NAME'] %>

# Linode S3-compatible storage (new)
linode_dev:
  service: S3
  access_key_id: <%= ENV['LINODE_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['LINODE_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['LINODE_REGION'] %>
  bucket: <%= ENV['LINODE_BUCKET_NAME_DEV'] %>
  endpoint: <%= ENV['LINODE_ENDPOINT'] %>

linode:
  service: S3
  access_key_id: <%= ENV['LINODE_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['LINODE_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['LINODE_REGION'] %>
  bucket: <%= ENV['LINODE_BUCKET_NAME'] %>
  endpoint: <%= ENV['LINODE_ENDPOINT'] %>
```

## Benefits of Linode Object Storage

- **Cost-effective**: Often more affordable than AWS S3
- **S3-compatible**: Uses the same API as AWS S3
- **Global CDN**: Built-in content delivery network
- **Simple pricing**: No complex tiered pricing structure
- **Integrated**: Works seamlessly with other Linode services

## Support

If you encounter issues during the migration:

1. Check the Rails logs for detailed error messages
2. Verify your Linode Object Storage configuration
3. Test the migration on a development environment first
4. Contact Linode support if you have issues with Object Storage
