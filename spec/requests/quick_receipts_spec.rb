require 'rails_helper'

RSpec.describe 'Quick Receipts', type: :request do
  let(:user) { FactoryBot.create(:user) }
  let(:account) { FactoryBot.create(:account, user: user) }

  describe 'GET /quick_receipts' do
    context 'when not authenticated' do
      it 'redirects to the login page' do
        get quick_receipts_path
        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'is successful' do
        get quick_receipts_path
        expect(response).to be_successful
      end

      context 'with no quick receipt transactions' do
        it 'shows a no-receipts message' do
          get quick_receipts_path
          expect(response.body).to include('No quick receipt transactions to review')
        end
      end

      context 'with quick receipt transactions' do
        let!(:quick_receipt) do
          FactoryBot.build(:transaction, account: account, quick_receipt: true, pending: true,
                                        description: nil, amount: nil).tap { |t| t.save!(validate: false) }
        end

        it 'displays the account name as a group header' do
          get quick_receipts_path
          expect(response.body).to include(account.name)
        end

        it 'shows the total count of quick receipts' do
          get quick_receipts_path
          expect(response.body).to include('1 receipt')
        end

        it 'does not show another user\'s quick receipt transactions' do
          other_user = FactoryBot.create(:user, email: 'other@example.com')
          other_account = FactoryBot.create(:account, user: other_user)
          FactoryBot.build(:transaction, account: other_account, quick_receipt: true, pending: true).tap { |t| t.save!(validate: false) }

          get quick_receipts_path
          expect(response.body).not_to include(other_account.name)
        end

        context 'with quick receipts across multiple accounts' do
          let(:second_account) { FactoryBot.create(:account, user: user, name: 'Second Account') }
          let!(:second_quick_receipt) do
            FactoryBot.build(:transaction, account: second_account, quick_receipt: true, pending: true,
                                          description: nil, amount: nil).tap { |t| t.save!(validate: false) }
          end

          it 'groups receipts by account' do
            get quick_receipts_path
            expect(response.body).to include(account.name)
            expect(response.body).to include(second_account.name)
          end
        end
      end
    end
  end
end
