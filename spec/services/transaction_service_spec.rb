# spec/services/transaction_service_spec.rb
require 'rails_helper'

RSpec.describe TransactionService do
  let(:service) { TransactionService.new }

  describe '#create_transaction' do
    context "Scenario: Simple Loan Disbursement [cite: 65, 66, 70]" do
      # Fresh accounts for this test only
      let!(:mpesa_cash) { create(:account, name: "M-Pesa Disburse", account_type: "ASSET", current_balance: 100000.0) }
      let!(:loans_receivable) { create(:account, name: "Loans Receivable Disburse", account_type: "ASSET", current_balance: 0.0) }
      
      let(:disbursement_params) do
        {
          idempotency_key: "disburse-#{SecureRandom.uuid}",
          description: "Loan Disbursement",
          entries: [
            { account_id: loans_receivable.id, debit: 10000.0 },
            { account_id: mpesa_cash.id, credit: 10000.0 }
          ]
        }
      end

      it 'correctly swaps asset values' do
        service.create_transaction(**disbursement_params)
        expect(mpesa_cash.reload.current_balance).to be_within(0.01).of(90000.0)
        expect(loans_receivable.reload.current_balance).to be_within(0.01).of(10000.0)
      end
    end

    context "Scenario: Complex Loan Repayment [cite: 45, 76, 81]" do
      # Fresh accounts for this test only
      let!(:mpesa_cash) { create(:account, name: "M-Pesa Repay", account_type: "ASSET", current_balance: 100000.0) }
      let!(:loans_receivable) { create(:account, name: "Loans Receivable Repay", account_type: "ASSET", current_balance: 0.0) }
      let!(:interest_income) { create(:account, name: "Interest Income Repay", account_type: "INCOME", current_balance: 0.0) }
      
      # Repaying 1,200 (1,000 principal + 200 interest) [cite: 76]
      let(:repayment_params) do
        {
          idempotency_key: "repay-#{SecureRandom.uuid}",
          description: "Repayment with Interest",
          entries: [
            { account_id: mpesa_cash.id, debit: 1200.0 }, # Cash increases [cite: 77]
            { account_id: loans_receivable.id, credit: 1000.0 }, # Receivable decreases [cite: 79]
            { account_id: interest_income.id, credit: 200.0 } # Income increases [cite: 81]
          ]
        }
      end

      it 'accurately splits balances across Assets and Income' do
        service.create_transaction(**repayment_params)
        expect(mpesa_cash.reload.current_balance).to be_within(0.01).of(101200.0)
        expect(interest_income.reload.current_balance).to be_within(0.01).of(200.0) # Normal Credit Balance [cite: 33]
      end
    end

    describe 'Financial Integrity [cite: 7, 34, 62]' do
      # Fresh accounts for atomicity test
      let!(:mpesa_cash) { create(:account, name: "M-Pesa Atomic", account_type: "ASSET", current_balance: 100000.0) }
      let!(:loans_receivable) { create(:account, name: "Loans Receivable Atomic", account_type: "ASSET", current_balance: 0.0) }
      
      it 'ensures Atomicity (Rollback on failure)' do
        # Store initial balance
        initial_balance = mpesa_cash.reload.current_balance.to_f
        
        # Trigger an error during transaction creation
        allow_any_instance_of(Account).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)

        params = {
          idempotency_key: "fail-#{SecureRandom.uuid}",
          description: 'Atomic Test',
          entries: [
            { account_id: mpesa_cash.id, debit: 500.0 },
            { account_id: loans_receivable.id, credit: 500.0 }
          ]
        }

        begin
          service.create_transaction(**params)
        rescue
          # Expected to fail
        end

        # Balance should remain unchanged due to rollback
        expect(mpesa_cash.reload.current_balance.to_f).to eq(initial_balance)
      end

      it 'guards against duplicate disbursements [cite: 55, 57]' do
        params = {
          idempotency_key: "same-key",
          description: "Idempotent Test",
          entries: [
            { account_id: mpesa_cash.id, debit: 100.0 },
            { account_id: loans_receivable.id, credit: 100.0 }
          ]
        }
        
        service.create_transaction(**params)
        expect {
          service.create_transaction(**params)
        }.not_to change(Transaction, :count)
      end
    end
  end
end