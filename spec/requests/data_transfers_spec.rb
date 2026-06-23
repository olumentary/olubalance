# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DataTransfers", type: :request do
  let(:user) { create(:user, :confirmed) }

  describe "authentication" do
    it "redirects to login when not signed in" do
      get data_transfer_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "when signed in" do
    before { sign_in user }

    describe "GET /data_transfer" do
      it "renders the export and import frames" do
        get data_transfer_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="data_export_status"')
        expect(response.body).to include('id="data_import_status"')
      end
    end

    describe "GET /data_transfer/status" do
      it "returns both turbo-frames so each can extract its own match" do
        get status_data_transfer_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="data_export_status"')
        expect(response.body).to include('id="data_import_status"')
      end

      it "reflects an in-flight export with a progress bar that keeps polling" do
        create(:data_export, user: user, status: :processing, progress: 42, step: "Attaching files")

        get status_data_transfer_path

        expect(response.body).to include('data-status-poll-status-value="processing"')
        expect(response.body).to include('value="42"')
        expect(response.body).to include("Attaching files")
      end

      it "surfaces a failed export error message" do
        create(:data_export, user: user, status: :failed, error_message: "Disk full")

        get status_data_transfer_path

        expect(response.body).to include('data-status-poll-status-value="failed"')
        expect(response.body).to include("Disk full")
      end

      it "only shows the current user's exports" do
        other = create(:user, :confirmed)
        create(:data_export, user: other, status: :processing, step: "Should not leak")

        get status_data_transfer_path

        expect(response.body).not_to include("Should not leak")
      end
    end

    describe "POST /data_transfer/export" do
      it "enqueues an export job and replaces the export frame" do
        expect {
          post export_data_transfer_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change { user.data_exports.count }.by(1)
         .and have_enqueued_job(DataExportJob)

        expect(response.body).to include('id="data_export_status"')
      end
    end

    describe "POST /data_transfer/import" do
      let(:archive) { Rack::Test::UploadedFile.new(StringIO.new("zipbytes"), "application/zip", original_filename: "export.zip") }

      it "rejects when the email confirmation does not match" do
        expect {
          post import_data_transfer_path, params: { confirm_email: "wrong@example.com", archive: archive }
        }.not_to change { user.data_imports.count }

        expect(response).to redirect_to(data_transfer_path)
        follow_redirect!
        expect(flash_or_body(response)).to match(/did not match/i)
      end

      it "rejects when no file is provided" do
        expect {
          post import_data_transfer_path, params: { confirm_email: user.email }
        }.not_to change { user.data_imports.count }

        expect(response).to redirect_to(data_transfer_path)
      end

      it "starts an import when the email matches and a file is attached" do
        expect {
          post import_data_transfer_path, params: { confirm_email: user.email, archive: archive }
        }.to change { user.data_imports.count }.by(1)
         .and have_enqueued_job(DataImportJob)

        expect(response).to redirect_to(data_transfer_path)
      end

      it "refuses to start a second import while one is in flight" do
        create(:data_import, user: user, status: :processing)

        expect {
          post import_data_transfer_path, params: { confirm_email: user.email, archive: archive }
        }.not_to change { user.data_imports.count }

        expect(response).to redirect_to(data_transfer_path)
      end
    end
  end

  # Flash isn't rendered in a bare redirect body; read it from the session/flash.
  def flash_or_body(_response)
    flash[:alert].to_s + flash[:notice].to_s + response.body.to_s
  end
end
