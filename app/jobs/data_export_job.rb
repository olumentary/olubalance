# frozen_string_literal: true

class DataExportJob < ApplicationJob
  queue_as :default

  def perform(data_export_id)
    de = DataExport.find(data_export_id)
    de.update!(status: :processing, progress: 0)

    tempfile = DataExport::Builder.new(user: de.user, data_export: de).call

    filename = "olubalance-export-#{de.user_id}-#{Time.current.strftime('%Y%m%d%H%M%S')}.zip"
    tempfile.rewind
    de.archive.attach(io: tempfile, filename: filename, content_type: "application/zip")
    de.update!(status: :complete, progress: 100, step: "Done", expires_at: 24.hours.from_now)
  rescue => e
    de&.update_columns(status: "failed", error_message: e.message.to_s.first(1000))
    raise
  ensure
    tempfile&.close
    tempfile&.unlink rescue nil
  end
end
