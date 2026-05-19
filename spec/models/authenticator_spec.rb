# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authenticator, type: :model do
  let(:user) { create(:user) }
  let(:secret) { Authenticator.generate_secret }

  describe "validations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:nickname) }
    it { is_expected.to validate_length_of(:nickname).is_at_most(50) }
    it { is_expected.to validate_presence_of(:confirmed_at) }

    it "requires nickname uniqueness within a user (case-insensitive)" do
      create(:authenticator, user: user, nickname: "Phone")
      dup = build(:authenticator, user: user, nickname: "phone")
      expect(dup).not_to be_valid
      expect(dup.errors[:nickname]).to include(/taken/i)
    end

    it "allows the same nickname on different users" do
      other = create(:user)
      create(:authenticator, user: user, nickname: "Phone")
      expect(build(:authenticator, user: other, nickname: "Phone")).to be_valid
    end
  end

  describe ".generate_secret" do
    it "returns a 32-character base32 string" do
      s = described_class.generate_secret
      expect(s).to match(/\A[A-Z2-7]{32}\z/)
    end
  end

  describe ".provisioning_uri" do
    it "produces an otpauth URI with the issuer + account" do
      uri = described_class.provisioning_uri(secret: secret, account: "you@example.com", issuer: "olubalance")
      expect(uri).to start_with("otpauth://totp/olubalance:you%40example.com")
      expect(uri).to include("secret=#{secret}")
      expect(uri).to include("issuer=olubalance")
    end
  end

  describe "#validate_and_consume!" do
    let(:auth) { create(:authenticator, :unused, user: user, otp_secret: secret) }
    let(:totp) { ROTP::TOTP.new(secret) }

    it "accepts a fresh code and updates consumed_timestep + last_used_at" do
      code = totp.now
      expect(auth.validate_and_consume!(code)).to be true
      auth.reload
      expect(auth.consumed_timestep).to eq(Time.current.to_i / Authenticator::TOTP_INTERVAL)
      expect(auth.last_used_at).to be_within(2.seconds).of(Time.current)
    end

    it "rejects an invalid code" do
      expect(auth.validate_and_consume!("000000")).to be false
      expect(auth.reload.last_used_at).to be_nil
    end

    it "rejects a blank code" do
      expect(auth.validate_and_consume!("")).to be false
      expect(auth.validate_and_consume!(nil)).to be false
    end

    it "refuses to accept the same code twice (replay protection)" do
      code = totp.now
      expect(auth.validate_and_consume!(code)).to be true
      expect(auth.validate_and_consume!(code)).to be false
    end

    it "accepts a code from a nearby drift window" do
      drifted_code = totp.at(Time.current - 25)
      expect(auth.validate_and_consume!(drifted_code)).to be true
    end
  end

  describe "scopes" do
    let!(:auth_a) { create(:authenticator, user: user, nickname: "Phone A") }
    let!(:auth_b) { create(:authenticator, user: user, nickname: "Phone B", created_at: 1.hour.ago) }

    it "confirmed includes all authenticators (confirmed_at is required)" do
      expect(described_class.confirmed).to contain_exactly(auth_a, auth_b)
    end

    it "recent_first orders by created_at desc" do
      expect(described_class.recent_first.first).to eq(auth_a)
    end
  end
end
