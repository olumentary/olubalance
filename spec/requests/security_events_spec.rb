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

    context "Active locks panel" do
      let(:admin)        { create(:user, :admin) }
      let(:other_user)   { create(:user) }
      let(:throttled_ip) { "198.51.100.42" }

      before do
        other_user.lock_access!
        create(:login_event, :throttle, ip: throttled_ip)
      end

      it "is hidden for non-admin users" do
        sign_in user
        get security_events_path
        expect(response.body).not_to include("Active locks")
        expect(response.body).not_to include("unlock_account")
        expect(response.body).not_to include("unlock_ip")
      end

      it "shows locked accounts and blocked IPs for admins" do
        sign_in admin
        get security_events_path
        expect(response.body).to include("Active locks")
        expect(response.body).to include("Locked accounts")
        expect(response.body).to include(other_user.email)
        expect(response.body).to include("Throttled / blocked IPs")
        expect(response.body).to include(throttled_ip)
      end
    end
  end

  describe "POST /security_events/unlock_account" do
    let(:admin)         { create(:user, :admin, password: "topsecret", password_confirmation: "topsecret") }
    let(:locked_user)   { create(:user).tap(&:lock_access!) }

    it "404s for non-admin users" do
      sign_in user
      post unlock_account_security_events_path, params: { user_id: locked_user.id, current_password: "topsecret" }
      expect(response).to have_http_status(:not_found)
      expect(locked_user.reload.access_locked?).to be true
    end

    it "rejects admin with wrong password and changes nothing" do
      sign_in admin
      expect {
        post unlock_account_security_events_path, params: { user_id: locked_user.id, current_password: "wrong-password" }
      }.not_to change { LoginEvent.where(event_type: "unlock").count }
      expect(locked_user.reload.access_locked?).to be true
      expect(flash[:alert]).to match(/Password was incorrect/)
    end

    it "unlocks the account and records an audit event when admin password is correct" do
      sign_in admin
      expect {
        post unlock_account_security_events_path, params: { user_id: locked_user.id, current_password: "topsecret" }
      }.to change { LoginEvent.where(event_type: "unlock").count }.by(1)

      expect(locked_user.reload.access_locked?).to be false
      expect(response).to redirect_to(security_events_path)

      event = LoginEvent.where(event_type: "unlock").last
      expect(event.user).to eq(locked_user)
      expect(event.reason).to eq("admin_account_unlock")
      expect(event.metadata["actor_id"]).to eq(admin.id)
    end
  end

  describe "POST /security_events/unlock_ip" do
    let(:admin) { create(:user, :admin, password: "topsecret", password_confirmation: "topsecret") }
    let(:ip)    { "192.0.2.55" }

    it "404s for non-admin users" do
      sign_in user
      expect(AuthLockManager).not_to receive(:clear_ip!)
      post unlock_ip_security_events_path, params: { ip: ip, current_password: "topsecret" }
      expect(response).to have_http_status(:not_found)
    end

    it "rejects admin with wrong password and does not clear" do
      sign_in admin
      expect(AuthLockManager).not_to receive(:clear_ip!)
      expect {
        post unlock_ip_security_events_path, params: { ip: ip, current_password: "nope" }
      }.not_to change { LoginEvent.where(event_type: "unlock").count }
      expect(flash[:alert]).to match(/Password was incorrect/)
    end

    it "rejects a blank IP" do
      sign_in admin
      expect(AuthLockManager).not_to receive(:clear_ip!)
      post unlock_ip_security_events_path, params: { ip: "", current_password: "topsecret" }
      expect(flash[:alert]).to match(/No IP/)
    end

    it "clears the IP and records an audit event on success" do
      sign_in admin
      expect(AuthLockManager).to receive(:clear_ip!).with(ip).and_return(true)
      expect {
        post unlock_ip_security_events_path, params: { ip: ip, current_password: "topsecret" }
      }.to change { LoginEvent.where(event_type: "unlock").count }.by(1)

      event = LoginEvent.where(event_type: "unlock").last
      expect(event.ip).to eq(ip)
      expect(event.reason).to eq("admin_ip_unlock")
      expect(event.metadata["actor_id"]).to eq(admin.id)
    end
  end
end
