require "rails_helper"

# TransferDecorator currently has no model behind it (no `Transfer` class —
# transfers are pairs of Transactions linked via counterpart_transaction_id).
# This spec just pins the class definition so dead-code removal is visible.
RSpec.describe TransferDecorator do
  it "is a Draper decorator subclass" do
    expect(described_class.ancestors).to include(Draper::Decorator)
  end
end
