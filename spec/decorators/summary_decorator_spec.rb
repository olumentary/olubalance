require "rails_helper"

# SummaryDecorator is currently a delegate-only shell (see
# app/decorators/summary_decorator.rb). This spec pins that and will start
# failing if any presentation logic is added without test coverage.
RSpec.describe SummaryDecorator do
  let(:user) { create(:user) }
  let(:accounts) { user.accounts }
  let(:summary) { Summary.new(accounts) }
  let(:decorated) { SummaryDecorator.new(summary) }

  it "delegates account-totaling methods to the wrapped Summary" do
    create(:account, :checking, user: user, starting_balance: BigDecimal("100"))
    create(:account, :savings,  user: user, starting_balance: BigDecimal("50"))

    expect(decorated.checking_total).to eq(BigDecimal("100"))
    expect(decorated.savings_total).to eq(BigDecimal("50"))
  end
end
