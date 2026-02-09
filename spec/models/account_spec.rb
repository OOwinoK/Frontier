require 'rails_helper'

RSpec.describe Account, type: :model do
  describe 'validations' do
    subject { build(:account) }
    
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:account_type) }
    it { should validate_uniqueness_of(:code) }
  end

  describe 'associations' do
    it { should belong_to(:parent_account).class_name('Account').optional }
    it { should have_many(:child_accounts).class_name('Account') }
    it { should have_many(:entries) }
    it { should have_many(:balance_snapshots).class_name('AccountBalanceSnapshot') }
  end

  describe 'scopes' do
    let!(:active_account) { create(:account, active: true) }
    let!(:inactive_account) { create(:account, active: false) }

    it 'returns only active accounts' do
      expect(Account.active).to include(active_account)
      expect(Account.active).not_to include(inactive_account)
    end
  end

  describe '#balance' do
    let(:account) { create(:account, current_balance: 1000.0000) }
    
    it 'returns current balance for current date' do
      expect(account.balance).to eq(1000.0000)
    end
  end

  describe '#debit_normal?' do
    it 'returns true for ASSET accounts' do
      account = build(:account, account_type: 'ASSET')
      expect(account.debit_normal?).to be true
    end

    it 'returns true for EXPENSE accounts' do
      account = build(:account, account_type: 'EXPENSE')
      expect(account.debit_normal?).to be true
    end

    it 'returns false for LIABILITY accounts' do
      account = build(:account, account_type: 'LIABILITY')
      expect(account.debit_normal?).to be false
    end
  end

  describe '#credit_normal?' do
    it 'returns true for LIABILITY accounts' do
      account = build(:account, account_type: 'LIABILITY')
      expect(account.credit_normal?).to be true
    end

    it 'returns true for INCOME accounts' do
      account = build(:account, account_type: 'INCOME')
      expect(account.credit_normal?).to be true
    end
  end

  describe '#deactivate!' do
    let(:account) { create(:account, active: true) }

    it 'sets active to false' do
      account.deactivate!
      expect(account.active).to be false
    end
  end
end
