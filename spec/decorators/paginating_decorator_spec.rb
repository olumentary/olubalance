require "rails_helper"

# PaginatingDecorator is a thin Draper::CollectionDecorator wrapper. The spec
# confirms its identity so accidental subclassing changes get caught.
RSpec.describe PaginatingDecorator do
  it "is a Draper collection decorator" do
    expect(described_class.ancestors).to include(Draper::CollectionDecorator)
  end

  it "wraps an Active Record relation" do
    user = create(:user)
    create(:account, user: user)
    create(:account, user: user)

    decorated = described_class.new(user.accounts)
    expect(decorated.size).to eq(2)
    expect(decorated.first).to be_a(AccountDecorator)
  end
end
