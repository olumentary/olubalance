# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bills', type: :request do
  let(:user) { create(:user, :confirmed) }
  let!(:account) { create(:account, user: user) }

  before do
    sign_in user
  end

  describe 'GET /bills' do
    let!(:bill) { create(:bill, user: user, account: account, description: 'Internet') }
    let!(:income_bill) { create(:bill, :income, user: user, account: account, description: 'Paycheck') }

    it 'renders successfully' do
      get bills_path
      expect(response).to be_successful
      expect(assigns(:bills).map(&:id)).to include(bill.id)
    end

    it 'renders calendar view when requested' do
      get bills_path, params: { view: 'calendar' }
      expect(response).to be_successful
      expect(assigns(:view_mode)).to eq('calendar')
    end

    it 'embeds summary tile bill data for hover popup' do
      get bills_path
      expect(response.body).to include('data-summary-tiles-bills-value')
      expect(response.body).to include('Paycheck')
    end
  end

  describe 'GET /bills/new' do
    it 'renders successfully when accounts exist' do
      get new_bill_path
      expect(response).to be_successful
    end

    it 'redirects to accounts when no accounts exist' do
      user.accounts.destroy_all
      get new_bill_path
      expect(response).to redirect_to(accounts_path)
    end
  end

  describe 'POST /bills' do
    let(:valid_params) do
      {
        bill: {
          bill_type: 'expense',
          category: 'housing',
          description: 'Rent',
          frequency: 'monthly',
          day_of_month: 1,
          amount: 1200.25,
          notes: 'Due on the first',
          account_id: account.id
        }
      }
    end

    it 'creates a bill with valid data' do
      expect {
        post bills_path, params: valid_params
      }.to change(Bill, :count).by(1)
      expect(response).to redirect_to(bills_path(view: nil))
    end

    it 'does not create with invalid data' do
      expect {
        post bills_path, params: { bill: valid_params[:bill].merge(description: '') }
      }.not_to change(Bill, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'creates a bi-weekly bill with two days per month' do
      params = {
        bill: valid_params[:bill].merge(
          frequency: 'bi_weekly',
          bill_type: 'income',
          category: 'income',
          day_of_month: 5,
          biweekly_mode: 'two_days',
          second_day_of_month: 20
        )
      }

      expect {
        post bills_path, params: params
      }.to change(Bill, :count).by(1)
      expect(Bill.last.biweekly_mode).to eq('two_days')
    end

    it 'creates a bi-weekly bill with every other week cadence' do
      anchor_date = Date.current
      params = {
        bill: valid_params[:bill].merge(
          frequency: 'bi_weekly',
          bill_type: 'expense',
          category: 'housing',
          day_of_month: 1,
          biweekly_mode: 'every_other_week',
          biweekly_anchor_date: anchor_date,
          biweekly_anchor_weekday: anchor_date.wday
        )
      }

      expect {
        post bills_path, params: params
      }.to change(Bill, :count).by(1)
      expect(Bill.last.biweekly_anchor_date).to eq(anchor_date)
    end

    it 'requires next occurrence month for quarterly bills' do
      params = {
        bill: valid_params[:bill].merge(
          frequency: 'quarterly',
          next_occurrence_month: nil
        )
      }

      expect {
        post bills_path, params: params
      }.not_to change(Bill, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /bills/:id/edit' do
    let!(:bill) { create(:bill, user: user, account: account) }

    it 'renders edit form' do
      get edit_bill_path(bill)
      expect(response).to be_successful
    end
  end

  describe 'PATCH /bills/:id' do
    let!(:bill) { create(:bill, user: user, account: account, description: 'Old') }

    it 'updates the bill' do
      patch bill_path(bill), params: { bill: { description: 'New Name' } }
      expect(response).to redirect_to(bills_path(view: nil))
      expect(bill.reload.description).to eq('New Name')
    end

    it 'returns errors for invalid data' do
      patch bill_path(bill), params: { bill: { description: '' } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE /bills/:id' do
    let!(:bill) { create(:bill, user: user, account: account) }

    it 'removes the bill' do
      expect {
        delete bill_path(bill)
      }.to change(Bill, :count).by(-1)
      expect(response).to redirect_to(bills_path(view: nil))
    end
  end

  describe 'authorization' do
    let(:other_user) { create(:user, :confirmed) }
    let(:other_account) { create(:account, user: other_user) }
    let!(:other_bill) { create(:bill, user: other_user, account: other_account) }

    it 'responds with 404 when editing another users bill' do
      get edit_bill_path(other_bill)
      expect(response).to have_http_status(:not_found)
    end
  end
end

