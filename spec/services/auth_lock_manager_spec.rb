# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthLockManager do
  describe ".unlock_user!" do
    it "clears Devise lock state" do
      user = create(:user)
      user.lock_access!
      expect(user.reload.access_locked?).to be true

      described_class.unlock_user!(user)

      expect(user.reload.access_locked?).to be false
      expect(user.failed_attempts).to eq(0)
      expect(user.locked_at).to be_nil
    end
  end

  describe ".clear_ip!" do
    let(:ip) { "203.0.113.99" }

    it "returns false for a blank IP and does no work" do
      expect(Rack::Attack.cache.store).not_to receive(:delete)
      expect(Rack::Attack::Allow2Ban).not_to receive(:reset)
      expect(described_class.clear_ip!("")).to be false
      expect(described_class.clear_ip!(nil)).to be false
    end

    it "deletes the current and previous throttle bucket for every IP-keyed throttle" do
      store = Rack::Attack.cache.store
      expected_keys = []

      now = Time.now.to_i
      AuthLockManager::IP_THROTTLES.each do |name, period|
        period_s = period.to_i
        bucket = now / period_s
        expected_keys << "rack::attack:#{bucket}:#{name}:#{ip}"
        expected_keys << "rack::attack:#{bucket - 1}:#{name}:#{ip}"
      end

      expected_keys.each do |key|
        expect(store).to receive(:delete).with(key).once
      end
      allow(Rack::Attack::Allow2Ban).to receive(:reset)

      described_class.clear_ip!(ip)
    end

    it "resets the fail2ban entry for the IP" do
      allow(Rack::Attack.cache.store).to receive(:delete)
      expect(Rack::Attack::Allow2Ban).to receive(:reset).with(
        "auth-abuse:#{ip}",
        hash_including(bantime: 24.hours)
      )

      described_class.clear_ip!(ip)
    end

    it "returns true on success" do
      allow(Rack::Attack.cache.store).to receive(:delete)
      allow(Rack::Attack::Allow2Ban).to receive(:reset)
      expect(described_class.clear_ip!(ip)).to be true
    end
  end
end
