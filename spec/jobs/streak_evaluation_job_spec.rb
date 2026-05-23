# frozen_string_literal: true

require "rails_helper"

RSpec.describe StreakEvaluationJob do
  it "calls StreakEvaluator for every user" do
    user_a = create(:user)
    user_b = create(:user)
    create(:account, user: user_a, last_transaction_on: Date.current)
    create(:account, user: user_b, last_transaction_on: Date.current)

    expect(Users::StreakEvaluator).to receive(:call).with(user_a)
    expect(Users::StreakEvaluator).to receive(:call).with(user_b)

    described_class.new.perform
  end
end
