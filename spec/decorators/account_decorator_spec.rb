# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccountDecorator do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, name: "Main Checking", last_four: 9876, starting_balance: BigDecimal("250")) }
  let(:decorated) { account.decorate }

  # A Wednesday — middle of the week, no urgency.
  let(:midweek) { Date.new(2026, 5, 20) }
  # A Friday — first urgent day.
  let(:friday) { Date.new(2026, 5, 22) }
  # A Saturday — last day of the week, peak urgency.
  let(:saturday) { Date.new(2026, 5, 23) }
  # A Sunday — start of a new week.
  let(:sunday) { Date.new(2026, 5, 24) }

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

  describe "#days_since_last_transaction" do
    it "is nil when last_transaction_on is blank" do
      account.update_columns(last_transaction_on: nil)
      expect(account.reload.decorate.days_since_last_transaction).to be_nil
    end

    it "computes whole days from today" do
      account.update_columns(last_transaction_on: 3.days.ago.to_date)
      expect(account.reload.decorate.days_since_last_transaction).to eq(3)
    end
  end

  describe "#weekly_review_status" do
    it "is :reviewed when last_transaction_on is within the current Sun–Sat week" do
      account.update_columns(last_transaction_on: midweek.beginning_of_week(:sunday))
      expect(account.reload.decorate.weekly_review_status(midweek)).to eq(:reviewed)
    end

    it "is :pending_normal Sun–Thu when not reviewed" do
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      expect(account.reload.decorate.weekly_review_status(midweek)).to eq(:pending_normal)
      expect(account.reload.decorate.weekly_review_status(sunday)).to eq(:pending_normal)
    end

    it "is :pending_urgent on Friday when not reviewed" do
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      expect(account.reload.decorate.weekly_review_status(friday)).to eq(:pending_urgent)
    end

    it "is :pending_urgent on Saturday when not reviewed" do
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      expect(account.reload.decorate.weekly_review_status(saturday)).to eq(:pending_urgent)
    end

    it "is :reviewed when last_transaction_on falls on the Sunday week boundary" do
      account.update_columns(last_transaction_on: saturday.beginning_of_week(:sunday)) # the Sunday
      expect(account.reload.decorate.weekly_review_status(saturday)).to eq(:reviewed)
    end
  end

  describe "#weekly_review_tag_class / #weekly_review_label" do
    it "uses solid Bulma classes" do
      account.update_columns(last_transaction_on: midweek)
      expect(account.reload.decorate.weekly_review_tag_class(midweek)).to eq("is-success")
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      expect(account.reload.decorate.weekly_review_tag_class(midweek)).to eq("is-warning")
      expect(account.reload.decorate.weekly_review_tag_class(saturday)).to eq("is-danger")
    end

    it "labels each status" do
      account.update_columns(last_transaction_on: midweek)
      expect(account.reload.decorate.weekly_review_label(midweek)).to eq("Reviewed this week")
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      expect(account.reload.decorate.weekly_review_label(midweek)).to eq("Not reviewed yet")
      expect(account.reload.decorate.weekly_review_label(saturday)).to eq("Urgent — review by Saturday")
    end
  end

  describe "#weekly_review_sort_key" do
    it "ranks urgent < normal < reviewed" do
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      urgent = account.reload.decorate.weekly_review_sort_key(saturday)
      normal = account.reload.decorate.weekly_review_sort_key(midweek)
      account.update_columns(last_transaction_on: midweek)
      reviewed = account.reload.decorate.weekly_review_sort_key(midweek)
      expect([ urgent, normal, reviewed ]).to eq([ 0, 1, 2 ])
    end
  end

  describe "#weekly_review_border_class" do
    it "maps each status to a BEM modifier" do
      account.update_columns(last_transaction_on: midweek)
      expect(account.reload.decorate.weekly_review_border_class(midweek)).to eq("account-card--reviewed")
      account.update_columns(last_transaction_on: 30.days.ago.to_date)
      expect(account.reload.decorate.weekly_review_border_class(midweek)).to eq("account-card--pending")
      expect(account.reload.decorate.weekly_review_border_class(saturday)).to eq("account-card--urgent")
    end
  end
end
