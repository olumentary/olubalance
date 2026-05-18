# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoginEvent, type: :model do
  let(:request_double) do
    instance_double(
      ActionDispatch::Request,
      remote_ip:  "203.0.113.5",
      ip:         "203.0.113.5",
      user_agent: "curl/8.0",
      path:       "/users/sign_in",
      params:     { "user" => { "email" => "  ATTACK@Example.COM " } },
      env:        { "rack.attack.matched" => "logins/ip" }
    )
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:event_type).in_array(described_class::EVENT_TYPES) }
    it { is_expected.to belong_to(:user).optional }
  end

  describe "scopes" do
    let!(:fail_now)   { create(:login_event, event_type: "failure", created_at: 1.minute.ago) }
    let!(:fail_old)   { create(:login_event, event_type: "failure", created_at: 8.days.ago) }
    let!(:success)    { create(:login_event, :success, created_at: 5.minutes.ago) }
    let!(:lockout)    { create(:login_event, :lockout, created_at: 2.minutes.ago) }
    let!(:otp_fail)   { create(:login_event, :otp_failure, created_at: 3.minutes.ago) }
    let!(:otp_ok)     { create(:login_event, :otp_success, created_at: 4.minutes.ago) }

    it "recent orders by created_at desc" do
      expect(described_class.recent.first).to eq(fail_now)
    end

    it "failures includes failure, lockout, otp_failure" do
      expect(described_class.failures).to contain_exactly(fail_now, fail_old, lockout, otp_fail)
    end

    it "successes includes success and otp_success" do
      expect(described_class.successes).to contain_exactly(success, otp_ok)
    end

    it "within filters by created_at window" do
      expect(described_class.within(1.day)).not_to include(fail_old)
      expect(described_class.within(1.day)).to include(fail_now)
    end
  end

  describe ".record_password_attempt" do
    it "creates a failure row with the normalized email and request metadata" do
      expect {
        described_class.record_password_attempt(
          request: request_double, email: "ATTACK@Example.COM",
          user: nil, success: false, reason: "no_such_user"
        )
      }.to change(described_class, :count).by(1)

      event = described_class.last
      expect(event).to have_attributes(
        event_type:      "failure",
        email_attempted: "attack@example.com",
        ip:              IPAddr.new("203.0.113.5"),
        user_agent:      "curl/8.0",
        reason:          "no_such_user",
        user_id:         nil
      )
    end

    it "creates a success row tied to a user" do
      user = create(:user)
      described_class.record_password_attempt(
        request: request_double, email: user.email,
        user: user, success: true
      )
      expect(described_class.last).to have_attributes(event_type: "success", user_id: user.id)
    end
  end

  describe ".record_otp" do
    let(:user) { create(:user) }

    it "creates an otp_success row" do
      described_class.record_otp(request: request_double, user: user, success: true)
      expect(described_class.last).to have_attributes(event_type: "otp_success", user_id: user.id)
    end

    it "creates an otp_failure row with a reason" do
      described_class.record_otp(request: request_double, user: user, success: false, reason: "invalid_code")
      expect(described_class.last).to have_attributes(event_type: "otp_failure", reason: "invalid_code")
    end
  end

  describe ".record_rack_attack" do
    it "stores the matched rule + path in metadata" do
      described_class.record_rack_attack(request: request_double, event_type: :throttle)
      event = described_class.last
      expect(event.event_type).to eq("throttle")
      expect(event.reason).to eq("logins/ip")
      expect(event.metadata).to eq("path" => "/users/sign_in")
      expect(event.email_attempted).to eq("attack@example.com")
    end

    it "ignores unknown event_types" do
      expect {
        described_class.record_rack_attack(request: request_double, event_type: :bogus)
      }.not_to change(described_class, :count)
    end
  end

  describe ".record_lockout" do
    it "writes a lockout row tied to the user" do
      user = create(:user)
      described_class.record_lockout(user: user, ip: "10.0.0.1", user_agent: "Mozilla")
      expect(described_class.last).to have_attributes(
        event_type:      "lockout",
        reason:          "max_failed_attempts",
        ip:              IPAddr.new("10.0.0.1"),
        email_attempted: user.email
      )
    end
  end
end
