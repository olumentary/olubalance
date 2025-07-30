# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Document, type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  describe 'associations' do
    it { should belong_to(:attachable) }
    it { should have_one_attached(:attachment) }
  end

  describe 'validations' do
    it { should validate_presence_of(:category) }
    it { should validate_presence_of(:document_date) }
    it { should validate_presence_of(:attachment).on(:update) }
    
    it { should validate_inclusion_of(:category).in_array(Document::CATEGORIES) }
    
    it { should validate_length_of(:description).is_at_most(500) }
    
    context 'when category is Taxes' do
      let(:document) { build(:document, category: 'Taxes', tax_year: nil) }
      
      it 'requires tax_year' do
        expect(document).not_to be_valid
        expect(document.errors[:tax_year]).to include("can't be blank")
      end
      
      it 'validates tax_year is between 1900 and 2100' do
        document.tax_year = 1899
        expect(document).not_to be_valid
        
        document.tax_year = 2101
        expect(document).not_to be_valid
        
        document.tax_year = 2023
        expect(document).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:statement_doc) { create(:document, category: 'Statements', attachable: user) }
    let!(:tax_doc) { create(:document, category: 'Taxes', tax_year: 2023, attachable: account) }
    
    describe '.by_category' do
      it 'filters by category' do
        expect(Document.by_category('Statements')).to include(statement_doc)
        expect(Document.by_category('Statements')).not_to include(tax_doc)
      end
    end
    
    describe '.by_level' do
      it 'filters by level' do
        expect(Document.by_level('User')).to include(statement_doc)
        expect(Document.by_level('User')).not_to include(tax_doc)
      end
    end
    
    describe '.by_account' do
      it 'filters by account' do
        expect(Document.by_account(account.id)).to include(tax_doc)
        expect(Document.by_account(account.id)).not_to include(statement_doc)
      end
    end
  end

  describe '#tax_document?' do
    it 'returns true for Taxes category' do
      document = build(:document, category: 'Taxes')
      expect(document.tax_document?).to be true
    end
    
    it 'returns false for other categories' do
      document = build(:document, category: 'Statements')
      expect(document.tax_document?).to be false
    end
  end

  describe '#level' do
    it 'returns User for user attachable' do
      document = build(:document, attachable: user)
      expect(document.level).to eq('User')
    end
    
    it 'returns Account for account attachable' do
      document = build(:document, attachable: account)
      expect(document.level).to eq('Account')
    end
  end

  describe '#account_name' do
    it 'returns account name for account attachable' do
      document = build(:document, attachable: account)
      expect(document.account_name).to eq(account.name)
    end
    
    it 'returns N/A for user attachable' do
      document = build(:document, attachable: user)
      expect(document.account_name).to eq('N/A')
    end
  end
end 