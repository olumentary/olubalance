# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SecurityEvents", type: :request do
  let(:user) { create(:user) }

  before do
    # Suppress the email alert side-effect so tests focus on the controller.
    allow_any_instance_of(LoginEvent).to receive(:notify)
  end

  describe "GET /security_events" do
    it "redirects to sign in when unauthenticated" do
      get security_events_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when authenticated" do
      before { sign_in user }

      let!(:success)   { create(:login_event, :success, user: user, ip: "10.0.0.1") }
      let!(:failure)   { create(:login_event, event_type: "failure", ip: "203.0.113.1", email_attempted: "bad@example.com") }
      let!(:throttle)  { create(:login_event, :throttle, ip: "198.51.100.1") }

      it "renders the page with summary tiles" do
        get security_events_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Security events")
        expect(response.body).to include("Failures (24h)")
        expect(response.body).to include("Throttles (24h)")
      end

      it "lists all events by default" do
        get security_events_path
        expect(response.body).to include("Success").and include("Failure").and include("Throttle")
      end

      it "filters by event_type=failures" do
        get security_events_path, params: { event_type: "failures" }
        expect(response.body).to include("bad@example.com")
        expect(response.body).not_to include("10.0.0.1") # success row hidden
      end

      it "filters by ip" do
        get security_events_path, params: { ip: "203.0.113.1" }
        expect(response.body).to include("bad@example.com")
        expect(response.body).not_to include("198.51.100.1")
      end

      it "filters by email substring" do
        get security_events_path, params: { q: "bad@" }
        expect(response.body).to include("bad@example.com")
      end

      it "respects the days window" do
        # Stash one old event far outside any window
        old = create(:login_event, event_type: "failure", ip: "172.16.0.1", created_at: 200.days.ago)
        get security_events_path, params: { days: 1 }
        expect(response.body).not_to include("172.16.0.1")
      end
    end
  end
end
