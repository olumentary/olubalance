# frozen_string_literal: true

class DataImportJob < ApplicationJob
  queue_as :default

  def perform(data_import_id)
    di = DataImport.find(data_import_id)
    di.update!(status: :processing, progress: 0, step: "Preparing")

    tempfile = Tempfile.new([ "olubalance-import", ".zip" ])
    tempfile.binmode
    di.archive.download { |chunk| tempfile.write(chunk) }
    tempfile.flush

    DataImport::Restorer.new(user: di.user, zip_path: tempfile.path, data_import: di).call

    di.update!(status: :complete, progress: 100, step: "Done")
  rescue DataImport::Restorer::InvalidManifestError => e
    di&.update_columns(status: "failed", error_message: e.message.to_s.first(1000))
    raise
  rescue => e
    di&.update_columns(status: "failed", error_message: e.message.to_s.first(1000))
    raise
  ensure
    tempfile&.close
    tempfile&.unlink rescue nil
  end
end
