# frozen_string_literal: true

require "rails_helper"

RSpec.describe StashEntryDecorator do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:stash) {
    Stash.create!(account: account, name: "Buffer", description: "x",
                  goal: BigDecimal("1000"), balance: BigDecimal("0"))
  }
  let(:add_entry) {
    StashEntry.create!(stash: stash, stash_action: "add",
                       amount: BigDecimal("100"), stash_entry_date: Date.current)
  }

  describe "#stash_action_capitalize" do
    it "capitalizes the underlying stash_action attr" do
      decorated = add_entry.decorate
      decorated.stash_action = "add"
      expect(decorated.stash_action_capitalize).to eq("Add")
    end
  end

  describe "#amount_decorated" do
    it "formats positive amounts as currency" do
      expect(add_entry.decorate.amount_decorated).to eq(ActionController::Base.helpers.number_to_currency(100))
    end

    it "shows the absolute value for negative (remove) amounts" do
      # Reference the lazy add_entry so the stash has balance before the remove.
      add_entry
      remove_entry = StashEntry.create!(stash: stash, stash_action: "remove",
                                        amount: BigDecimal("40"), stash_entry_date: Date.current)
      expect(remove_entry.amount).to be < 0
      expect(remove_entry.decorate.amount_decorated).to eq(ActionController::Base.helpers.number_to_currency(40))
    end
  end

  describe "#amount_color" do
    it "is green/success for positive amounts" do
      expect(add_entry.decorate.amount_color).to eq("has-text-success")
    end

    it "is red/danger for negative amounts" do
      add_entry # seed the stash with balance
      remove_entry = StashEntry.create!(stash: stash, stash_action: "remove",
                                        amount: BigDecimal("40"), stash_entry_date: Date.current)
      expect(remove_entry.decorate.amount_color).to eq("has-text-danger")
    end
  end

  describe "#form_title" do
    it "reads 'Add to <stash> Stash' for add actions" do
      decorated = add_entry.decorate
      decorated.stash_action = "add"
      expect(decorated.form_title).to eq("Add to Buffer Stash")
    end

    it "reads 'Remove from <stash> Stash' for other actions" do
      decorated = add_entry.decorate
      decorated.stash_action = "remove"
      expect(decorated.form_title).to eq("Remove from Buffer Stash")
    end
  end
end
