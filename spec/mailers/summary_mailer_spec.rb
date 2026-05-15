# frozen_string_literal: true

require "rails_helper"

RSpec.describe SummaryMailer, type: :mailer do
  describe "#new_summary_email" do
    let(:user) { create(:user) }
    let!(:checking) { create(:account, :checking, user: user, starting_balance: BigDecimal("750")) }
    # Match what SummaryController does: chain .where().order() on the
    # relation before decorating, so `Summary#accounts_checking`'s `.where`
    # falls through the CollectionDecorator to the underlying relation.
    let(:accounts) { user.accounts.where(active: true).order("created_at ASC").decorate }
    let(:summary) { Summary.new(accounts) }
    let(:mail) {
      described_class.with(summary: summary, current_user: user, to: "to@example.com").new_summary_email
    }

    it "sends to the requested recipient with a dated subject" do
      expect(mail.to).to eq([ "to@example.com" ])
      expect(mail.from).to eq([ "accounts@olubalance.com" ])
      expect(mail.subject).to start_with("olubalance ")
    end

    it "renders a body that includes the user's account name" do
      expect(mail.body.encoded).to include(checking.name)
    end
  end
end
