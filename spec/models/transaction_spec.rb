require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe 'validations' do
    it 'requires idempotency_key' do
      transaction = build(:transaction, idempotency_key: nil)
      expect(transaction).not_to be_valid
      expect(transaction.errors[:idempotency_key]).to include("can't be blank")
    end
    
    it 'requires unique idempotency_key' do
      create(:transaction, idempotency_key: 'unique-key')
      transaction = build(:transaction, idempotency_key: 'unique-key')
      
      # We check .valid? instead of .save(validate: false) to avoid hitting 
      # the PG::UniqueViolation exception which crashes the test suite.
      expect(transaction).not_to be_valid
      expect(transaction.errors[:idempotency_key]).to include("has already been taken")
    end
  end
  
  describe 'associations' do
    it { should have_many(:entries).dependent(:destroy) }
    it { should have_many(:accounts).through(:entries) }
  end
  
  describe '#balanced?' do
    let(:account1) { create(:account) }
    let(:account2) { create(:account) }
    
    context 'when debits equal credits' do
      it 'returns true' do
        transaction = create(:transaction, :with_entries)
        expect(transaction.balanced?).to be true
      end
    end
    
    context 'when debits do not equal credits' do
      it 'returns false' do
        transaction = create(:transaction)
        create(:entry, txn: transaction, account: account1, debit: 1000.0000, credit: nil)
        create(:entry, txn: transaction, account: account2, debit: nil, credit: 500.0000)
        expect(transaction.balanced?).to be false
      end
    end
  end
  
  describe '#total_debits' do
    it 'calculates total debits' do
      transaction = create(:transaction, :with_entries)
      expect(transaction.total_debits).to eq(1000.0)
    end
  end
  
  describe '#total_credits' do
    it 'calculates total credits' do
      transaction = create(:transaction, :with_entries)
      expect(transaction.total_credits).to eq(1000.0)
    end
  end
  
  describe 'status helpers' do
    it '#posted? returns true for posted status' do
      transaction = build(:transaction, status: 'posted')
      expect(transaction.posted?).to be true
    end
    
    # Using 'pending' as the default status is usually best for OCR-ing 
    # artifacts to allow for manual review if the transcription confidence is low.
    it '#pending? returns true for pending status' do
      transaction = build(:transaction, status: 'pending')
      expect(transaction.pending?).to be true
    end
    
    it '#voided? returns true for voided status' do
      transaction = build(:transaction, status: 'voided')
      expect(transaction.voided?).to be true
    end
  end
end