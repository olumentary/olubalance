# frozen_string_literal: true

require "rails_helper"

RSpec.describe StreakEvaluationJob do
  it "calls StreakEvaluator for every user" do
    user_a = create(:user)
    user_b = create(:user)
    create(:account, user: user_a, last_transaction_on: Date.current)
    create(:account, user: user_b, last_transaction_on: Date.current)

    # Allow seeded users (present in CI after db:reset) to be processed
    # without strict expectations — we only care that OUR two users get
    # called.
    allow(Users::StreakEvaluator).to receive(:call)

    described_class.new.perform

    expect(Users::StreakEvaluator).to have_received(:call).with(user_a)
    expect(Users::StreakEvaluator).to have_received(:call).with(user_b)
  end
end
