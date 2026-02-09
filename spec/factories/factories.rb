# spec/factories/accounts.rb
FactoryBot.define do
  factory :account do
    sequence(:code) { |n| "ACC-#{n.to_s.rjust(4, '0')}" }
    sequence(:name) { |n| "Test Account #{n}" }
    description { "Test account for #{account_type}" }
    account_type { 'ASSET' }
    currency { 'KES' }
    active { true }
    trait :asset do
      account_type { 'ASSET' }
    end
    trait :liability do
      account_type { 'LIABILITY' }
    end
    trait :equity do
      account_type { 'EQUITY' }
    end
    trait :income do
      account_type { 'INCOME' }
    end
    trait :expense do
      account_type { 'EXPENSE' }
    end
    trait :with_balance do
      current_balance { 10000.0000 }
    end
    trait :inactive do
      active { false }
    end
    factory :cash_account do
      code { 'CASH-MPESA-KES' }
      name { 'M-Pesa Cash Account' }
      account_type { 'ASSET' }
    end
    factory :loan_account do
      sequence(:code) { |n| "LOAN-#{n.to_s.rjust(6, '0')}" }
      sequence(:name) { |n| "Loan Receivable - Borrower #{n}" }
      account_type { 'ASSET' }
    end
    factory :interest_income_account do
      code { 'INTEREST-INCOME-KES' }
      name { 'Interest Income' }
      account_type { 'INCOME' }
    end
  end
end

# spec/factories/transactions.rb
FactoryBot.define do
  factory :transaction do
    sequence(:idempotency_key) { |n| "txn-#{n}-#{SecureRandom.hex(8)}" }
    description { 'Test transaction' }
    posted_at { Time.current }
    status { 'posted' }
    metadata { {} }
    
    # Skip validation for basic factory
    to_create { |instance| instance.save(validate: false) }
    
    trait :pending do
      status { 'pending' }
    end
    
    trait :voided do
      status { 'voided' }
    end
    
    trait :reversed do
      status { 'reversed' }
    end
    
    trait :with_entries do
      after(:create) do |transaction|
        account1 = create(:account)
        account2 = create(:account)
        create(:entry, txn: transaction, account: account1, debit: 1000.0000, credit: nil)
        create(:entry, txn: transaction, account: account2, debit: nil, credit: 1000.0000)
      end
    end
  end
end

# spec/factories/entries.rb
FactoryBot.define do
  factory :entry do
    association :txn, factory: :transaction
    association :account
    description { 'Test entry' }
    
    trait :debit do
      debit { 1000.0000 }
      credit { nil }
    end
    
    trait :credit do
      debit { nil }
      credit { 1000.0000 }
    end
    
    factory :debit_entry, traits: [:debit]
    factory :credit_entry, traits: [:credit]
  end
end

# spec/factories/account_balance_snapshots.rb
FactoryBot.define do
  factory :account_balance_snapshot do
    association :account
    snapshot_date { Date.yesterday }
    balance { 5000.0000 }
    entries_count { 10 }
    metadata { {} }
  end
end
