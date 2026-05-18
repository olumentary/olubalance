# frozen_string_literal: true

require "rails_helper"

RSpec.describe SecurityMailer, type: :mailer do
  let(:user) { create(:user, first_name: "Pat") }

  describe "#suspicious_failed_attempts" do
    let(:mail) { described_class.suspicious_failed_attempts(user, ip: "203.0.113.99", count: 12, window: 1.hour) }

    it "renders the subject" do
      expect(mail.subject).to eq("[olubalance] Suspicious sign-in attempts on your account")
    end

    it "delivers to the user" do
      expect(mail.to).to eq([ user.email ])
    end

    it "mentions the IP and count in the body" do
      expect(mail.body.encoded).to include("203.0.113.99").and include("12 failed sign-in attempts")
    end

    it "addresses the user by first name" do
      expect(mail.body.encoded).to include("Pat")
    end
  end

  describe "#unfamiliar_successful_login" do
    let(:event) { create(:login_event, :success, user: user, ip: "198.51.100.7", user_agent: "Firefox") }
    let(:mail)  { described_class.unfamiliar_successful_login(user, event) }

    it "renders the subject" do
      expect(mail.subject).to eq("[olubalance] New device or location signed in")
    end

    it "delivers to the user" do
      expect(mail.to).to eq([ user.email ])
    end

    it "includes the event IP and user agent" do
      expect(mail.body.encoded).to include("198.51.100.7").and include("Firefox")
    end
  end
end
