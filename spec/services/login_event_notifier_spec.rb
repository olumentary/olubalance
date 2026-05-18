# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoginEventNotifier do
  # The notifier short-circuits in Rails.env.test? to avoid noise during normal
  # request specs. Stub that guard here so we can exercise the actual logic.
  before do
    # Bypass the early-exit guard inside LoginEventNotifier without disturbing
    # the rest of Rails.env (some downstream code calls Rails.env.to_sym etc).
    allow(Rails.env).to receive(:test?).and_return(false)
    @memory_store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(@memory_store)
    ActionMailer::Base.deliveries.clear
    # Disable LoginEvent's auto after_create_commit callback so seeding events
    # in tests doesn't fire the notifier — each test invokes it explicitly.
    allow_any_instance_of(LoginEvent).to receive(:notify)
  end

  let!(:user) { create(:user) }

  describe "#deliver" do
    context "suspicious failures" do
      it "fires the alert once the threshold is crossed" do
        9.times { create(:login_event, event_type: "failure", ip: "203.0.113.5") }
        trigger = create(:login_event, event_type: "failure", ip: "203.0.113.5")

        described_class.call(trigger)

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries.last.subject).to include("Suspicious sign-in attempts")
      end

      it "does not fire under threshold" do
        5.times { create(:login_event, event_type: "failure", ip: "203.0.113.6") }
        trigger = create(:login_event, event_type: "failure", ip: "203.0.113.6")

        described_class.call(trigger)

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "dedupes a second alert from the same IP within the window" do
        10.times { create(:login_event, event_type: "failure", ip: "203.0.113.7") }
        first  = create(:login_event, event_type: "failure", ip: "203.0.113.7")
        second = create(:login_event, event_type: "failure", ip: "203.0.113.7")

        described_class.call(first)
        described_class.call(second)

        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end

      it "treats throttles and blocks as failure-like" do
        9.times { create(:login_event, event_type: "failure", ip: "203.0.113.8") }
        trigger = create(:login_event, :throttle, ip: "203.0.113.8")

        described_class.call(trigger)

        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    context "unfamiliar successful login" do
      it "fires when no prior success from this IP exists" do
        event = create(:login_event, :success, user: user, ip: "198.51.100.1")
        described_class.call(event)

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries.last.subject).to include("New device or location")
      end

      it "stays silent when the IP was seen recently" do
        create(:login_event, :success, user: user, ip: "198.51.100.2", created_at: 1.day.ago)
        event = create(:login_event, :success, user: user, ip: "198.51.100.2")

        described_class.call(event)

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "fires again if the IP was last seen outside the lookback window" do
        create(:login_event, :success, user: user, ip: "198.51.100.3", created_at: 100.days.ago)
        event = create(:login_event, :success, user: user, ip: "198.51.100.3")

        described_class.call(event)

        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end
    end

    it "rescues unexpected errors and logs them" do
      allow(SecurityMailer).to receive(:suspicious_failed_attempts).and_raise(StandardError, "boom")
      10.times { create(:login_event, event_type: "failure", ip: "203.0.113.10") }
      trigger = create(:login_event, event_type: "failure", ip: "203.0.113.10")

      expect(Rails.logger).to receive(:warn).with(/LoginEventNotifier.*boom/)
      described_class.call(trigger)
    end
  end
end
