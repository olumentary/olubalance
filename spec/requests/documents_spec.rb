# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documents', type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:account) { create(:account, user: user) }
  let!(:user_document) { create(:user_document, attachable: user) }
  let!(:account_document) { create(:account_document, attachable: account) }

  before do
    sign_in user
  end

  describe 'GET /documents' do
    it 'returns a successful response' do
      get documents_path
      expect(response).to be_successful
    end

    it 'assigns @documents with user and account documents' do
      get documents_path
      expect(assigns(:documents)).to include(user_document, account_document)
    end

    it 'assigns @categories' do
      get documents_path
      expect(assigns(:categories)).to eq(Document::CATEGORIES)
    end

    context 'with filters' do
      let!(:tax_document) { create(:tax_document, attachable: user, tax_year: 2023) }

      it 'filters by category' do
        get documents_path, params: { category: 'Taxes' }
        expect(assigns(:documents)).to include(tax_document)
        expect(assigns(:documents)).not_to include(user_document)
      end

      it 'filters by level' do
        get documents_path, params: { level: 'User' }
        expect(assigns(:documents)).to include(user_document)
        expect(assigns(:documents)).not_to include(account_document)
      end

      it 'filters by account' do
        get documents_path, params: { account_id: account.id }
        expect(assigns(:documents)).to include(account_document)
        expect(assigns(:documents)).not_to include(user_document)
      end

      it 'filters by date range' do
        get documents_path, params: { start_date: Date.current - 1.day, end_date: Date.current + 1.day }
        expect(assigns(:documents)).to include(user_document, account_document, tax_document)
      end
    end

    context 'with sorting' do
      it 'sorts by document_date by default' do
        get documents_path
        expect(assigns(:documents).to_sql).to include('ORDER BY "documents"."document_date" DESC')
      end

      it 'sorts by category when specified' do
        get documents_path, params: { sort: 'category', direction: 'asc' }
        expect(assigns(:documents).to_sql).to include('ORDER BY "documents"."category" ASC')
      end

      it 'sorts by description when specified' do
        get documents_path, params: { sort: 'description', direction: 'asc' }
        expect(assigns(:documents).to_sql).to include('ORDER BY "documents"."description" ASC')
      end

      it 'sorts by filename when specified' do
        get documents_path, params: { sort: 'filename', direction: 'asc' }
        expect(assigns(:documents).to_sql).to include('ORDER BY active_storage_attachments.name asc')
      end
    end
  end
end 