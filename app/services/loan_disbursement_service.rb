# app/services/loan_disbursement_service.rb
#
# Service for disbursing loans with proper accounting entries
# Handles loan creation, fee deduction, and M-Pesa transfers

class LoanDisbursementService
  class DisbursementError < StandardError; end
  
  attr_reader :loan_account, :transaction, :errors
  
  def initialize
    @errors = []
    @transaction_service = TransactionService.new
  end
  
  # Disburse a loan
  #
  # @param borrower_name [String] Name of borrower
  # @param principal_amount [Decimal] Loan amount
  # @param origination_fee [Decimal] Fee charged (optional)
  # @param currency [String] Currency code (KES, UGX, USD)
  # @param loan_reference [String] External loan reference
  # @param metadata [Hash] Additional loan metadata
  #
  # Example:
  #   service = LoanDisbursementService.new
  #   result = service.disburse(
  #     borrower_name: 'John Doe',
  #     principal_amount: 10000.00,
  #     origination_fee: 500.00,
  #     currency: 'KES',
  #     loan_reference: 'LOAN-2026-001'
  #   )
  def disburse(borrower_name:, principal_amount:, origination_fee: 0, currency: 'KES', loan_reference:, metadata: {})
    validate_disbursement!(principal_amount, origination_fee, currency)
    
    ActiveRecord::Base.transaction do
      # 1. Create loan receivable account for this borrower
      @loan_account = create_loan_account(
        borrower_name: borrower_name,
        currency: currency,
        loan_reference: loan_reference,
        metadata: metadata
      )
      
      # 2. Record loan disbursement (principal)
      disbursement_txn = record_loan_disbursement(
        loan_account: @loan_account,
        principal_amount: principal_amount,
        currency: currency,
        loan_reference: loan_reference
      )
      
      # 3. Record origination fee (if any)
      if origination_fee > 0
        fee_txn = record_origination_fee(
          loan_account: @loan_account,
          fee_amount: origination_fee,
          currency: currency,
          loan_reference: loan_reference
        )
      end
      
      @transaction = disbursement_txn
    end
    
    {
      success: true,
      loan_account: @loan_account,
      transaction: @transaction,
      net_disbursement: principal_amount - origination_fee
    }
  rescue => e
    @errors << e.message
    Rails.logger.error("LoanDisbursementService error: #{e.message}\n#{e.backtrace.join("\n")}")
    
    {
      success: false,
      errors: @errors
    }
  end
  
  private
  
  def validate_disbursement!(principal_amount, origination_fee, currency)
    if principal_amount <= 0
      raise DisbursementError, 'Principal amount must be positive'
    end
    
    if origination_fee < 0
      raise DisbursementError, 'Origination fee cannot be negative'
    end
    
    if origination_fee >= principal_amount
      raise DisbursementError, 'Origination fee cannot exceed principal amount'
    end
    
    unless Account::CURRENCIES.include?(currency)
      raise DisbursementError, "Unsupported currency: #{currency}"
    end
  end
  
  def create_loan_account(borrower_name:, currency:, loan_reference:, metadata:)
    Account.create!(
      code: "LOAN-#{loan_reference}",
      name: "Loan Receivable - #{borrower_name}",
      description: "Loan account for #{borrower_name}",
      account_type: 'ASSET',
      currency: currency,
      parent_account: find_or_create_loans_parent_account(currency),
      metadata: metadata
    )
  end
  
  def find_or_create_loans_parent_account(currency)
    Account.find_or_create_by!(
      code: "LOANS-RECEIVABLE-#{currency}",
      account_type: 'ASSET',
      currency: currency
    ) do |account|
      account.name = "Loans Receivable (#{currency})"
      account.description = "Parent account for all loans in #{currency}"
    end
  end
  
  def record_loan_disbursement(loan_account:, principal_amount:, currency:, loan_reference:)
    # Get cash account (M-Pesa or bank)
    cash_account = find_cash_account(currency)
    
    # Create transaction
    # DR: Loans Receivable (Asset) - increases asset
    # CR: Cash/M-Pesa Account (Asset) - decreases asset
    @transaction_service.create_transaction(
      idempotency_key: "disbursement-#{loan_reference}",
      description: "Loan disbursement to #{loan_account.name}",
      entries: [
        {
          account_id: loan_account.id,
          debit: principal_amount,
          description: "Loan principal disbursed"
        },
        {
          account_id: cash_account.id,
          credit: principal_amount,
          description: "Cash disbursed via M-Pesa"
        }
      ],
      metadata: {
        loan_reference: loan_reference,
        disbursement_type: 'principal',
        currency: currency
      }
    )
  end
  
  def record_origination_fee(loan_account:, fee_amount:, currency:, loan_reference:)
    # Get fee receivable and fee income accounts
    fee_receivable_account = find_fee_receivable_account(currency)
    fee_income_account = find_fee_income_account(currency)
    
    # Create transaction
    # DR: Fee Receivable (Asset) - increases asset
    # CR: Fee Income (Income) - increases income
    @transaction_service.create_transaction(
      idempotency_key: "origination-fee-#{loan_reference}",
      description: "Origination fee for #{loan_account.name}",
      entries: [
        {
          account_id: fee_receivable_account.id,
          debit: fee_amount,
          description: "Origination fee charged"
        },
        {
          account_id: fee_income_account.id,
          credit: fee_amount,
          description: "Fee income recognized"
        }
      ],
      metadata: {
        loan_reference: loan_reference,
        loan_account_id: loan_account.id,
        fee_type: 'origination',
        currency: currency
      }
    )
  end
  
  def find_cash_account(currency)
    Account.find_or_create_by!(
      code: "CASH-MPESA-#{currency}",
      account_type: 'ASSET',
      currency: currency
    ) do |account|
      account.name = "M-Pesa Cash Account (#{currency})"
      account.description = "Mobile money cash account"
    end
  end
  
  def find_fee_receivable_account(currency)
    Account.find_or_create_by!(
      code: "FEE-RECEIVABLE-#{currency}",
      account_type: 'ASSET',
      currency: currency
    ) do |account|
      account.name = "Fee Receivable (#{currency})"
      account.description = "Fees receivable from borrowers"
    end
  end
  
  def find_fee_income_account(currency)
    Account.find_or_create_by!(
      code: "FEE-INCOME-#{currency}",
      account_type: 'INCOME',
      currency: currency
    ) do |account|
      account.name = "Fee Income (#{currency})"
      account.description = "Income from loan fees"
    end
  end
end
