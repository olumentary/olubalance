# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccountDecorator do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, name: "Main Checking", last_four: 9876, starting_balance: BigDecimal("250")) }
  let(:decorated) { account.decorate }

  describe "#account_name" do
    it "appends last_four when present" do
      expect(decorated.account_name).to eq("Main Checking ( ... 9876)")
    end

    it "is just the name when last_four is blank" do
      account.update_columns(last_four: nil)
      expect(account.reload.decorate.account_name).to eq("Main Checking")
    end
  end

  describe "#account_card_title" do
    it "returns the name when shorter than DISPLAY_NAME_LIMIT" do
      expect(decorated.account_card_title).to eq("Main Checking")
    end

    it "truncates with an ellipsis when too long" do
      long = "a" * (Account::DISPLAY_NAME_LIMIT + 5)
      account.update!(name: long)
      title = account.reload.decorate.account_card_title
      expect(title.length).to be <= Account::DISPLAY_NAME_LIMIT + 4 # +"..."
      expect(title).to end_with("...")
    end
  end

  describe "#last_four_display" do
    it "prefixes with xx when last_four is set" do
      expect(decorated.last_four_display).to eq("xx9876")
    end

    it "returns nil when last_four is blank" do
      account.update_columns(last_four: nil)
      expect(account.reload.decorate.last_four_display).to be_nil
    end
  end

  describe "currency formatters" do
    it "formats current_balance" do
      expect(decorated.current_balance_display).to eq(ActionController::Base.helpers.number_to_currency(account.current_balance))
    end
  end

  describe "#account_name_balance" do
    it "concatenates name and formatted current balance" do
      formatted = ActionController::Base.helpers.number_to_currency(account.current_balance)
      expect(decorated.account_name_balance).to eq("Main Checking (#{formatted})")
    end
  end

  describe "#balance_negative? / #balance_color" do
    it "is negative when current_balance is below zero" do
      account.update_columns(current_balance: BigDecimal("-5"))
      expect(account.reload.decorate.balance_negative?).to be true
    end

    it "returns has-text-danger on negative checking accounts" do
      account.update_columns(current_balance: BigDecimal("-5"))
      expect(account.reload.decorate.balance_color).to eq("has-text-danger")
    end

    it "returns has-text-grey-dark for credit accounts regardless of balance sign" do
      credit = create(:account, :credit, user: user, current_balance: BigDecimal("-100"))
      expect(credit.decorate.balance_color).to eq("has-text-grey-dark")
    end
  end

  describe "#account_icon" do
    it "returns fa-credit-card for credit accounts" do
      credit = create(:account, :credit, user: user)
      expect(credit.decorate.account_icon).to eq("fa-credit-card")
    end

    it "returns fa-money-check for checking" do
      expect(decorated.account_icon).to eq("fa-money-check")
    end

    it "returns fa-piggy-bank for savings (default branch)" do
      savings = create(:account, :savings, user: user)
      expect(savings.decorate.account_icon).to eq("fa-piggy-bank")
    end
  end
end
