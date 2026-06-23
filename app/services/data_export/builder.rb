# frozen_string_literal: true

# Reopens the DataExport model class as a namespace for the export builder.
# Must be `class` (not `module`) — DataExport is an ActiveRecord class.
class DataExport
  class Builder
    MANIFEST_VERSION = 1
    MANIFEST_SCHEMA = "olubalance.data_transfer"

    def initialize(user:, data_export:)
      @user = user
      @data_export = data_export
      @blobs_to_export = []
      @category_cache = {}
    end

    def call
      report("Loading data", 5)
      preload_data!

      report("Building manifest", 15)
      manifest = build_manifest

      tempfile = Tempfile.new([ "olubalance-export", ".zip" ])
      tempfile.binmode

      Zip::OutputStream.open(tempfile.path) do |zip|
        report("Writing manifest", 20)
        zip.put_next_entry("manifest.json")
        zip.write(JSON.generate(manifest))

        write_attachments(zip)
      end

      tempfile
    end

    private

    def preload_data!
      @accounts = @user.accounts.to_a
      @account_ids = @accounts.map(&:id)

      @transactions = Transaction
        .where(account_id: @account_ids)
        .includes(attachments_attachments: :blob)
        .to_a

      @stashes = Stash.where(account_id: @account_ids).to_a
      @stash_entries = StashEntry.where(stash_id: @stashes.map(&:id)).to_a

      @bills = @user.bills.to_a
      @bill_batches = @user.bill_transaction_batches.to_a

      @custom_categories = @user.categories.to_a
      @hidden_categories = @user.hidden_categories.to_a
      @category_lookups = @user.category_lookups.to_a

      user_docs = @user.documents.includes(attachment_attachment: :blob).to_a
      account_docs = Document
        .where(attachable_type: "Account", attachable_id: @account_ids)
        .includes(attachment_attachment: :blob)
        .to_a
      @documents = user_docs + account_docs

      @trusted_devices = @user.trusted_devices.to_a
      @login_events = LoginEvent.where(user_id: @user.id).to_a

      build_category_cache!
    end

    def build_category_cache!
      all_cat_ids = (
        @transactions.map(&:category_id) +
        @bills.map(&:category_id) +
        @hidden_categories.map(&:category_id) +
        @category_lookups.map(&:category_id)
      ).compact.uniq

      Category.where(id: all_cat_ids).each do |cat|
        @category_cache[cat.id] = if cat.user_id.nil?
          { "kind" => "global", "name" => cat.name }
        else
          { "kind" => "custom", "id" => cat.id }
        end
      end
    end

    def build_manifest
      {
        "schema" => MANIFEST_SCHEMA,
        "version" => MANIFEST_VERSION,
        "exported_at" => Time.current.iso8601,
        "source_user_id" => @user.id,
        "records" => {
          "accounts" => @accounts.map { |r| serialize(r) },
          "categories" => @custom_categories.map { |r| serialize(r) },
          "transactions" => @transactions.map { |r| serialize_transaction(r) },
          "stashes" => @stashes.map { |r| serialize(r) },
          "stash_entries" => @stash_entries.map { |r| serialize(r) },
          "bills" => @bills.map { |r| serialize_with_category_ref(r) },
          "bill_transaction_batches" => @bill_batches.map { |r| serialize(r) },
          "hidden_categories" => @hidden_categories.map { |r| serialize_with_category_ref(r) },
          "category_lookups" => @category_lookups.map { |r| serialize_with_category_ref(r) },
          "documents" => @documents.map { |r| serialize_document(r) },
          "trusted_devices" => @trusted_devices.map { |r| serialize(r) },
          "login_events" => @login_events.map { |r| serialize(r) }
        },
        "user_patch" => { "default_account_id" => @user.default_account_id }
      }
    end

    def serialize(record)
      record.attributes.as_json
    end

    def serialize_with_category_ref(record)
      serialize(record).merge("category_ref" => @category_cache[record.category_id])
    end

    def serialize_transaction(record)
      base = serialize(record)
      base["category_ref"] = @category_cache[record.category_id]

      attachments = record.attachments.map { |att| attachment_descriptor(att) }.compact
      base["attachments"] = attachments

      base
    end

    def serialize_document(record)
      base = serialize(record)
      if record.attachment.attached?
        base["attachment"] = attachment_descriptor(record.attachment)
      end
      base
    end

    def attachment_descriptor(attachment)
      blob = attachment.blob
      zip_path = "attachments/#{blob.key}/#{blob.filename}"
      @blobs_to_export << { zip_path: zip_path, blob: blob }
      {
        "blob_key" => blob.key,
        "filename" => blob.filename.to_s,
        "content_type" => blob.content_type,
        "byte_size" => blob.byte_size,
        "checksum" => blob.checksum,
        "created_at" => blob.created_at.iso8601,
        "path" => zip_path
      }
    rescue => e
      Rails.logger.error("DataExport::Builder attachment_descriptor failed for attachment #{attachment.id}: #{e.message}")
      nil
    end

    def write_attachments(zip)
      total = @blobs_to_export.size
      return if total.zero?

      @blobs_to_export.each_with_index do |entry, i|
        pct = 20 + ((i + 1) * 80 / total)
        report("Attaching files (#{i + 1}/#{total})", pct)

        begin
          zip.put_next_entry(entry[:zip_path])
          entry[:blob].download { |chunk| zip.write(chunk) }
        rescue => e
          Rails.logger.error("DataExport::Builder failed to export blob #{entry[:blob].key}: #{e.message}")
          # The descriptor is already in the manifest; the missing file on import is handled gracefully
        end
      end
    end

    def report(step, pct)
      @data_export.update_columns(step: step, progress: pct)
    rescue => e
      Rails.logger.warn("DataExport::Builder could not update progress: #{e.message}")
    end
  end
end
