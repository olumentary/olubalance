# frozen_string_literal: true

# Reopens the DataImport model class as a namespace for the import restorer.
# Must be `class` (not `module`) — DataImport is an ActiveRecord class.
class DataImport
  class Restorer
    SUPPORTED_VERSION = 1

    class InvalidManifestError < StandardError; end

    def initialize(user:, zip_path:, data_import: nil)
      @user = user
      @zip_path = zip_path
      @data_import = data_import
      @id_map = Hash.new { |h, k| h[k] = {} }
      @created_blobs = []
      @old_blob_ids = []
    end

    def call
      manifest = read_manifest!

      # Collect old blob IDs *before* the transaction so we can safely purge
      # storage files after commit without risking data loss on rollback.
      @old_blob_ids = collect_old_blob_ids

      ActiveRecord::Base.transaction do
        report("Deleting existing data", 5)
        delete_existing_records!

        report("Importing categories", 10)
        import_categories(manifest["records"]["categories"] || [])

        report("Importing accounts", 15)
        import_accounts(manifest["records"]["accounts"] || [])

        report("Importing stashes", 20)
        import_stashes(manifest["records"]["stashes"] || [])

        report("Importing bills", 25)
        import_bill_batches(manifest["records"]["bill_transaction_batches"] || [])
        import_bills(manifest["records"]["bills"] || [])

        report("Importing transactions", 35)
        import_transactions(manifest["records"]["transactions"] || [])

        report("Importing stash entries", 50)
        import_stash_entries(manifest["records"]["stash_entries"] || [])

        report("Importing supporting data", 60)
        import_hidden_categories(manifest["records"]["hidden_categories"] || [])
        import_category_lookups(manifest["records"]["category_lookups"] || [])
        import_trusted_devices(manifest["records"]["trusted_devices"] || [])
        import_login_events(manifest["records"]["login_events"] || [])

        report("Restoring documents", 70)
        import_documents(manifest["records"]["documents"] || [])

        report("Attaching files", 75)
        recreate_blobs!(manifest)

        report("Finalizing links", 95)
        patch_second_pass(manifest)
      end

      # Transaction committed — safe to delete old storage files now.
      report("Cleaning up old files", 97)
      purge_old_blobs!

      report("Done", 100)
    rescue => e
      purge_orphaned_blobs!
      raise
    end

    private

    def read_manifest!
      Zip::File.open(@zip_path) do |zip|
        entry = zip.find_entry("manifest.json")
        raise InvalidManifestError, "No manifest.json found in archive" unless entry

        manifest = JSON.parse(entry.get_input_stream.read)

        unless manifest["schema"] == "olubalance.data_transfer"
          raise InvalidManifestError, "Unrecognized archive schema: #{manifest['schema']}"
        end
        unless manifest["version"].to_i == SUPPORTED_VERSION
          raise InvalidManifestError, "Unsupported archive version #{manifest['version']} (expected #{SUPPORTED_VERSION})"
        end

        manifest
      end
    end

    # ---------- wipe existing data (FK-safe order) ----------

    # Collects blob IDs for all user-owned attachments before the wipe transaction
    # starts, so storage files can be safely purged *after* the transaction commits.
    def collect_old_blob_ids
      acct_ids = Account.where(user_id: @user.id).pluck(:id)
      trx_ids  = Transaction.where(account_id: acct_ids).pluck(:id)
      doc_ids  = Document.where(
        "(attachable_type = 'User' AND attachable_id = ?) OR (attachable_type = 'Account' AND attachable_id IN (?))",
        @user.id, acct_ids.presence || [ 0 ]
      ).pluck(:id)

      ActiveStorage::Attachment
        .where(record_type: "Transaction", record_id: trx_ids)
        .or(ActiveStorage::Attachment.where(record_type: "Document", record_id: doc_ids))
        .pluck(:blob_id)
    end

    # Deletes all user records in FK-safe order. Attachment *records* are removed
    # here (via delete_all, inside the transaction so they roll back on failure);
    # the actual storage files are deleted by purge_old_blobs! after commit.
    def delete_existing_records!
      acct_ids = Account.where(user_id: @user.id).pluck(:id)
      trx_ids  = Transaction.where(account_id: acct_ids).pluck(:id)

      Transaction.where(id: trx_ids).update_all(counterpart_transaction_id: nil)
      ActiveStorage::Attachment.where(record_type: "Transaction", record_id: trx_ids).delete_all

      stash_ids = Stash.where(account_id: acct_ids).pluck(:id)
      StashEntry.where(stash_id: stash_ids).delete_all
      Transaction.where(id: trx_ids).delete_all
      Stash.where(id: stash_ids).delete_all

      doc_ids = Document.where(
        "(attachable_type = 'User' AND attachable_id = ?) OR (attachable_type = 'Account' AND attachable_id IN (?))",
        @user.id, acct_ids.presence || [ 0 ]
      ).pluck(:id)

      if doc_ids.any?
        ActiveStorage::Attachment.where(record_type: "Document", record_id: doc_ids).delete_all
        Document.where(id: doc_ids).delete_all
      end

      Bill.where(user_id: @user.id).delete_all
      BillTransactionBatch.where(user_id: @user.id).delete_all

      CategoryLookup.where(user_id: @user.id).delete_all
      HiddenCategory.where(user_id: @user.id).delete_all
      TrustedDevice.where(user_id: @user.id).delete_all
      LoginEvent.where(user_id: @user.id).delete_all

      @user.update_columns(default_account_id: nil)
      Account.where(id: acct_ids).delete_all

      Category.where(user_id: @user.id).delete_all
    end

    # ---------- pass-one inserters ----------

    def import_categories(records)
      insert_and_map(Category, :categories, records) do |r|
        r.except("id").merge("user_id" => @user.id)
      end
    end

    def import_accounts(records)
      insert_and_map(Account, :accounts, records) do |r|
        r.except("id").merge("user_id" => @user.id)
      end
    end

    def import_stashes(records)
      insert_and_map(Stash, :stashes, records) do |r|
        r.except("id").merge("account_id" => remap(:accounts, r["account_id"]))
      end
    end

    def import_bill_batches(records)
      insert_and_map(BillTransactionBatch, :bill_transaction_batches, records) do |r|
        r.except("id").merge("user_id" => @user.id)
      end
    end

    def import_bills(records)
      insert_and_map(Bill, :bills, records) do |r|
        r.except("id", "category_ref").merge(
          "user_id" => @user.id,
          "account_id" => remap(:accounts, r["account_id"]),
          "category_id" => resolve_category(r["category_ref"])
        )
      end
    end

    def import_transactions(records)
      insert_and_map(Transaction, :transactions, records) do |r|
        r.except("id", "counterpart_transaction_id", "attachments", "category_ref").merge(
          "account_id" => remap(:accounts, r["account_id"]),
          "category_id" => resolve_category(r["category_ref"]),
          "bill_transaction_batch_id" => remap(:bill_transaction_batches, r["bill_transaction_batch_id"]),
          "counterpart_transaction_id" => nil  # patched in pass two
        )
      end
    end

    def import_stash_entries(records)
      insert_and_map(StashEntry, :stash_entries, records) do |r|
        r.except("id").merge(
          "stash_id" => remap(:stashes, r["stash_id"]),
          "transaction_id" => nil  # patched in pass two
        )
      end
    end

    def import_hidden_categories(records)
      rows = records.map do |r|
        cat_id = resolve_category(r["category_ref"])
        next unless cat_id

        r.except("id", "category_ref").merge(
          "user_id" => @user.id,
          "category_id" => cat_id
        )
      end.compact

      HiddenCategory.insert_all(rows) if rows.any?
    end

    def import_category_lookups(records)
      rows = records.map do |r|
        cat_id = resolve_category(r["category_ref"])
        next unless cat_id

        r.except("id", "category_ref").merge(
          "user_id" => @user.id,
          "category_id" => cat_id
        )
      end.compact

      CategoryLookup.insert_all(rows) if rows.any?
    end

    def import_trusted_devices(records)
      rows = records.map { |r| r.except("id").merge("user_id" => @user.id) }
      TrustedDevice.insert_all(rows) if rows.any?
    end

    def import_login_events(records)
      rows = records.map { |r| r.except("id").merge("user_id" => @user.id) }
      LoginEvent.insert_all(rows) if rows.any?
    end

    def import_documents(records)
      @pending_document_blobs = {}

      insert_and_map(Document, :documents, records) do |r|
        new_attachable_id = if r["attachable_type"] == "Account"
          remap(:accounts, r["attachable_id"])
        else
          @user.id
        end

        # Store attachment descriptor for later blob recreation
        @pending_document_blobs[r["id"]] = r["attachment"] if r["attachment"].present?

        r.except("id", "attachment").merge("attachable_id" => new_attachable_id)
      end
    end

    # ---------- blob recreation ----------

    def recreate_blobs!(manifest)
      Zip::File.open(@zip_path) do |zip|
        recreate_transaction_blobs!(manifest["records"]["transactions"] || [], zip)
        recreate_document_blobs!(zip)
      end
    end

    def recreate_transaction_blobs!(records, zip)
      records.each do |r|
        next if r["attachments"].blank?

        new_trx_id = @id_map[:transactions][r["id"]]
        next unless new_trx_id

        r["attachments"].each do |descriptor|
          blob = upload_blob_from_zip(zip, descriptor)
          next unless blob

          @created_blobs << blob
          ActiveStorage::Attachment.insert({
            name: "attachments",
            record_type: "Transaction",
            record_id: new_trx_id,
            blob_id: blob.id,
            created_at: Time.current
          })
        end
      end
    end

    def recreate_document_blobs!(zip)
      return unless @pending_document_blobs

      @pending_document_blobs.each do |old_doc_id, descriptor|
        new_doc_id = @id_map[:documents][old_doc_id]
        next unless new_doc_id

        blob = upload_blob_from_zip(zip, descriptor)
        next unless blob

        @created_blobs << blob
        ActiveStorage::Attachment.insert({
          name: "attachment",
          record_type: "Document",
          record_id: new_doc_id,
          blob_id: blob.id,
          created_at: Time.current
        })
      end
    end

    def upload_blob_from_zip(zip, descriptor)
      path = descriptor["path"]
      entry = zip.find_entry(path)
      unless entry
        Rails.logger.warn("DataImport::Restorer: attachment not found in zip: #{path}")
        return nil
      end

      bytes = entry.get_input_stream.read
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(bytes),
        filename: descriptor["filename"],
        content_type: descriptor["content_type"]
      )
    rescue => e
      Rails.logger.error("DataImport::Restorer: failed to recreate blob #{path}: #{e.message}")
      nil
    end

    # ---------- pass two: patch self-referential FKs ----------

    def patch_second_pass(manifest)
      patch_counterpart_transactions(manifest["records"]["transactions"] || [])
      patch_stash_entry_transactions(manifest["records"]["stash_entries"] || [])
      patch_user_default_account(manifest["user_patch"])
    end

    def patch_counterpart_transactions(records)
      records.each do |r|
        next if r["counterpart_transaction_id"].blank?

        new_id = @id_map[:transactions][r["id"]]
        new_counterpart_id = @id_map[:transactions][r["counterpart_transaction_id"]]

        if new_id && new_counterpart_id
          Transaction.where(id: new_id).update_all(counterpart_transaction_id: new_counterpart_id)
        else
          Rails.logger.warn("DataImport::Restorer: could not remap counterpart for transaction old_id=#{r['id']}")
        end
      end
    end

    def patch_stash_entry_transactions(records)
      records.each do |r|
        next if r["transaction_id"].blank?

        new_entry_id = @id_map[:stash_entries][r["id"]]
        new_trx_id = @id_map[:transactions][r["transaction_id"]]

        if new_entry_id && new_trx_id
          StashEntry.where(id: new_entry_id).update_all(transaction_id: new_trx_id)
        else
          Rails.logger.warn("DataImport::Restorer: could not remap stash_entry transaction old_id=#{r['id']}")
        end
      end
    end

    def patch_user_default_account(user_patch)
      return if user_patch.blank? || user_patch["default_account_id"].blank?

      new_acct_id = @id_map[:accounts][user_patch["default_account_id"]]
      @user.update_columns(default_account_id: new_acct_id) if new_acct_id
    end

    # ---------- helpers ----------

    def insert_and_map(model_class, map_key, records, &transform)
      return if records.empty?

      pairs = records.filter_map do |r|
        row = transform.call(r)
        [ r["id"], row ] if row
      end

      return if pairs.empty?

      old_ids = pairs.map(&:first)
      rows    = pairs.map(&:last)

      new_ids = model_class.insert_all!(rows, returning: %w[id]).rows.flatten
      old_ids.zip(new_ids).each { |old_id, new_id| @id_map[map_key][old_id] = new_id }
    end

    def remap(table_key, old_id)
      return nil if old_id.blank?

      @id_map[table_key][old_id].tap do |new_id|
        Rails.logger.warn("DataImport::Restorer: no mapping for #{table_key}[#{old_id}]") unless new_id
      end
    end

    def resolve_category(ref)
      return nil if ref.blank?

      case ref["kind"]
      when "custom"
        @id_map[:categories][ref["id"]]
      when "global"
        Category.find_or_create_by!(user_id: nil, name: ref["name"]) { |c| c.kind = :global }.id
      end
    rescue => e
      Rails.logger.error("DataImport::Restorer: failed to resolve category #{ref.inspect}: #{e.message}")
      nil
    end

    def purge_old_blobs!
      return if @old_blob_ids.empty?

      ActiveStorage::Blob.where(id: @old_blob_ids).find_each do |blob|
        blob.purge
      rescue => e
        Rails.logger.error("DataImport::Restorer: failed to purge old blob #{blob.key}: #{e.message}")
      end
    end

    def purge_orphaned_blobs!
      @created_blobs.each do |blob|
        blob.purge
      rescue => e
        Rails.logger.error("DataImport::Restorer: failed to purge orphan blob #{blob.key}: #{e.message}")
      end
    end

    def report(step, pct)
      @data_import&.update_columns(step: step, progress: pct)
    rescue => e
      Rails.logger.warn("DataImport::Restorer could not update progress: #{e.message}")
    end
  end
end
