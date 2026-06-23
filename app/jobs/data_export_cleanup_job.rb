# frozen_string_literal: true

class DataExportCleanupJob < ApplicationJob
  queue_as :default

  def perform
    DataExport.expired.find_each(&:destroy)
  end
end
