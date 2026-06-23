# frozen_string_literal: true

class DataTransfersController < ApplicationController
  before_action :authenticate_user!

  def show
    @latest_export = current_user.data_exports.recent.first
    @latest_import = current_user.data_imports.recent.first
  end

  def export
    de = current_user.data_exports.create!(status: :pending)
    DataExportJob.perform_later(de.id)

    @latest_export = de

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to data_transfer_path, notice: "Export started." }
    end
  end

  def status
    @latest_export = current_user.data_exports.recent.first
    @latest_import = current_user.data_imports.recent.first
    # Renders status.html.erb, which contains both the export and import
    # turbo-frames so either frame can extract its match when it reloads.
  end

  def download
    de = current_user.data_exports.complete.order(created_at: :desc).first

    unless de&.archive&.attached?
      redirect_to data_transfer_path, alert: "No completed export found."
      return
    end

    redirect_to rails_blob_path(de.archive, disposition: "attachment")
  end

  def import
    unless params[:confirm_email].to_s.strip.downcase == current_user.email.downcase
      redirect_to data_transfer_path, alert: "Email confirmation did not match. Import cancelled."
      return
    end

    if current_user.data_imports.in_flight.exists?
      redirect_to data_transfer_path, alert: "An import is already in progress. Please wait for it to finish."
      return
    end

    unless params[:archive].present?
      redirect_to data_transfer_path, alert: "Please select an export file to import."
      return
    end

    di = current_user.data_imports.create!(status: :pending)
    di.archive.attach(params[:archive])
    DataImportJob.perform_later(di.id)

    redirect_to data_transfer_path, notice: "Import started. This page will show progress below."
  end
end
