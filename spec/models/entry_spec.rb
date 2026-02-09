require 'rails_helper'

RSpec.describe Entry, type: :model do
  describe 'associations' do
    it { should belong_to(:txn).class_name('Transaction') }
    it { should belong_to(:account) }
  end

  describe 'validations' do
    let(:account) { create(:account) }
    let(:txn) { create(:transaction) }

    it 'requires either debit or credit' do
      entry = build(:entry, txn: txn, account: account, debit: nil, credit: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:base]).to include('Entry must have either debit or credit')
    end

    it 'does not allow both debit and credit' do
      entry = build(:entry, txn: txn, account: account, debit: 100, credit: 100)
      expect(entry).not_to be_valid
      expect(entry.errors[:base]).to include('Entry cannot have both debit and credit')
    end

    it 'validates debit is positive if present' do
      entry = build(:entry, txn: txn, account: account, debit: -100, credit: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:debit]).to be_present
    end

    it 'validates credit is positive if present' do
      entry = build(:entry, txn: txn, account: account, debit: nil, credit: -100)
      expect(entry).not_to be_valid
      expect(entry.errors[:credit]).to be_present
    end
  end

  describe '#debit?' do
    it 'returns true for debit entries' do
      entry = build(:entry, debit: 100, credit: nil)
      expect(entry.debit?).to be true
    end

    it 'returns false for credit entries' do
      entry = build(:entry, debit: nil, credit: 100)
      expect(entry.debit?).to be false
    end
  end

  describe '#credit?' do
    it 'returns true for credit entries' do
      entry = build(:entry, debit: nil, credit: 100)
      expect(entry.credit?).to be true
    end

    it 'returns false for debit entries' do
      entry = build(:entry, debit: 100, credit: nil)
      expect(entry.credit?).to be false
    end
  end

  describe '#amount' do
    it 'returns debit amount if debit entry' do
      entry = build(:entry, debit: 500.0000, credit: nil)
      expect(entry.amount).to eq(500.0000)
    end

    it 'returns credit amount if credit entry' do
      entry = build(:entry, debit: nil, credit: 750.0000)
      expect(entry.amount).to eq(750.0000)
    end
  end

  describe '#entry_type' do
    it 'returns "debit" for debit entries' do
      entry = build(:entry, debit: 100, credit: nil)
      expect(entry.entry_type).to eq('debit')
    end

    it 'returns "credit" for credit entries' do
      entry = build(:entry, debit: nil, credit: 100)
      expect(entry.entry_type).to eq('credit')
    end
  end
end
