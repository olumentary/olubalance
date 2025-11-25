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

  describe 'GET /documents/new' do
    it 'returns a successful response' do
      get new_document_path
      expect(response).to be_successful
    end

    it 'assigns @document' do
      get new_document_path
      expect(assigns(:document)).to be_a_new(Document)
    end

    it 'assigns @categories' do
      get new_document_path
      expect(assigns(:categories)).to eq(Document::CATEGORIES)
    end

    it 'assigns @accounts' do
      get new_document_path
      expect(assigns(:accounts)).to include(account)
    end
  end

  describe 'POST /documents' do
    let(:valid_attributes) do
      {
        category: 'Statements',
        document_date: Date.current,
        description: 'Test document',
        level: 'User',
        attachment: Rack::Test::UploadedFile.new(
          Rails.root.join('app', 'assets', 'images', 'logo.png'),
          'image/png'
        )
      }
    end

    context 'with valid parameters' do
      it 'creates a new user-level document' do
        expect {
          post documents_path, params: { document: valid_attributes }
        }.to change(Document, :count).by(1)

        document = Document.last
        expect(document.attachable).to eq(user)
        expect(document.category).to eq('Statements')
        expect(response).to redirect_to(document_path(document))
      end

      it 'creates a new account-level document' do
        account_attributes = valid_attributes.merge(
          level: 'Account',
          account_id: account.id
        )

        expect {
          post documents_path, params: { document: account_attributes }
        }.to change(Document, :count).by(1)

        document = Document.last
        expect(document.attachable).to eq(account)
        expect(response).to redirect_to(document_path(document))
      end

      it 'creates a tax document with tax year' do
        tax_attributes = valid_attributes.merge(
          category: 'Taxes',
          tax_year: 2023
        )

        expect {
          post documents_path, params: { document: tax_attributes }
        }.to change(Document, :count).by(1)

        document = Document.last
        expect(document.tax_year).to eq(2023)
        expect(response).to redirect_to(document_path(document))
      end
    end

    context 'with invalid parameters' do
      it 'does not create a document without required fields' do
        expect {
          post documents_path, params: { document: { category: '' } }
        }.not_to change(Document, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not create account-level document without account selection' do
        invalid_attributes = valid_attributes.merge(level: 'Account', account_id: '')

        expect {
          post documents_path, params: { document: invalid_attributes }
        }.not_to change(Document, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(assigns(:document).errors[:base]).to include('Account must be selected for Account-level documents')
      end

      it 'does not create tax document without tax year' do
        tax_attributes = valid_attributes.merge(category: 'Taxes', tax_year: '')

        expect {
          post documents_path, params: { document: tax_attributes }
        }.not_to change(Document, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end 