# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrustedDevice, type: :model do
  let(:user) { create(:user) }

  describe ".remember_days" do
    it "defaults to 14 days when env var is unset" do
      ClimateControl.modify("TWO_FACTOR_REMEMBER_DAYS" => nil) do
        expect(described_class.remember_days).to eq(14)
      end
    rescue NameError
      # ClimateControl isn't bundled — fall back to direct ENV manipulation.
      previous = ENV.delete("TWO_FACTOR_REMEMBER_DAYS")
      expect(described_class.remember_days).to eq(14)
    ensure
      ENV["TWO_FACTOR_REMEMBER_DAYS"] = previous if previous
    end

    it "clamps to [1, 90]" do
      with_env("TWO_FACTOR_REMEMBER_DAYS", "0") { expect(described_class.remember_days).to eq(1) }
      with_env("TWO_FACTOR_REMEMBER_DAYS", "999") { expect(described_class.remember_days).to eq(90) }
      with_env("TWO_FACTOR_REMEMBER_DAYS", "7") { expect(described_class.remember_days).to eq(7) }
    end
  end

  describe ".digest" do
    it "is deterministic SHA256" do
      expect(described_class.digest("abc")).to eq(Digest::SHA256.hexdigest("abc"))
    end
  end

  describe ".issue!" do
    it "creates a row and returns a plaintext token whose digest matches" do
      token = described_class.issue!(user: user, user_agent: "Mozilla", ip: "10.0.0.1")
      expect(token).to be_a(String).and have_attributes(length: 64)
      device = described_class.last
      expect(device.token_digest).to eq(described_class.digest(token))
      expect(device).to have_attributes(user_agent: "Mozilla", ip: IPAddr.new("10.0.0.1"))
      expect(device.expires_at).to be_within(2.seconds).of(described_class.remember_days.days.from_now)
    end
  end

  describe ".lookup" do
    let!(:token)  { described_class.issue!(user: user, user_agent: "x", ip: "1.2.3.4") }
    let(:device)  { described_class.last }

    it "returns the matching active device" do
      expect(described_class.lookup(user: user, token: token)).to eq(device)
    end

    it "returns nil if user mismatches" do
      other = create(:user)
      expect(described_class.lookup(user: other, token: token)).to be_nil
    end

    it "returns nil if token is wrong" do
      expect(described_class.lookup(user: user, token: "nope")).to be_nil
    end

    it "returns nil if revoked" do
      device.revoke!
      expect(described_class.lookup(user: user, token: token)).to be_nil
    end

    it "returns nil if expired" do
      device.update_column(:expires_at, 1.day.ago)
      expect(described_class.lookup(user: user, token: token)).to be_nil
    end

    it "returns nil for blank inputs" do
      expect(described_class.lookup(user: nil, token: token)).to be_nil
      expect(described_class.lookup(user: user, token: nil)).to be_nil
    end
  end

  describe "#touch_last_seen!" do
    it "updates last_seen_at and ip without bumping updated_at validation" do
      device = create(:trusted_device, user: user, last_seen_at: 1.hour.ago, ip: "1.1.1.1")
      device.touch_last_seen!(ip: "2.2.2.2")
      expect(device.reload.ip).to eq(IPAddr.new("2.2.2.2"))
      expect(device.last_seen_at).to be_within(2.seconds).of(Time.current)
    end
  end

  describe "#revoke!" do
    it "stamps revoked_at" do
      device = create(:trusted_device, user: user)
      expect { device.revoke! }.to change { device.reload.revoked_at }.from(nil)
    end
  end

  describe "#active?" do
    it "is true for fresh, unrevoked devices" do
      expect(create(:trusted_device, user: user)).to be_active
    end

    it "is false once revoked" do
      expect(create(:trusted_device, :revoked, user: user)).not_to be_active
    end

    it "is false once expired" do
      expect(create(:trusted_device, :expired, user: user)).not_to be_active
    end
  end

  describe "active scope" do
    let!(:current)  { create(:trusted_device, user: user) }
    let!(:revoked)  { create(:trusted_device, :revoked, user: user) }
    let!(:expired)  { create(:trusted_device, :expired, user: user) }

    it "returns only non-revoked, non-expired rows" do
      expect(described_class.active).to contain_exactly(current)
    end
  end

  def with_env(key, value)
    previous = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = previous
  end
end
