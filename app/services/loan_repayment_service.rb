# app/services/loan_repayment_service.rb
#
# Service for processing loan repayments
# Handles principal, interest, and fee payments

class LoanRepaymentService
  class RepaymentError < StandardError; end
  
  attr_reader :transaction, :errors
  
  def initialize
    @errors = []
    @transaction_service = TransactionService.new
  end
  
  # Process a loan repayment
  #
  # @param loan_account_id [Integer] ID of loan account
  # @param principal_amount [Decimal] Principal portion
  # @param interest_amount [Decimal] Interest portion
  # @param fee_amount [Decimal] Fee portion (optional)
  # @param payment_reference [String] Unique payment reference
  # @param metadata [Hash] Additional payment metadata
  #
  # Example:
  #   service = LoanRepaymentService.new
  #   result = service.process_repayment(
  #     loan_account_id: 123,
  #     principal_amount: 1000.00,
  #     interest_amount: 200.00,
  #     payment_reference: 'MPESA-ABC123'
  #   )
  def process_repayment(loan_account_id:, principal_amount: 0, interest_amount: 0, fee_amount: 0, payment_reference:, metadata: {})
    loan_account = Account.find(loan_account_id)
    
    validate_repayment!(loan_account, principal_amount, interest_amount, fee_amount)
    
    total_amount = principal_amount + interest_amount + fee_amount
    currency = loan_account.currency
    
    # Build entries for the repayment
    entries = build_repayment_entries(
      loan_account: loan_account,
      principal_amount: principal_amount,
      interest_amount: interest_amount,
      fee_amount: fee_amount,
      currency: currency
    )
    
    # Create the transaction
    @transaction = @transaction_service.create_transaction(
      idempotency_key: "repayment-#{payment_reference}",
      description: "Loan repayment for #{loan_account.name}",
      entries: entries,
      metadata: metadata.merge({
        loan_account_id: loan_account_id,
        payment_reference: payment_reference,
        principal_amount: principal_amount,
        interest_amount: interest_amount,
        fee_amount: fee_amount,
        total_amount: total_amount
      })
    )
    
    {
      success: true,
      transaction: @transaction,
      total_amount: total_amount,
      remaining_balance: loan_account.reload.current_balance
    }
  rescue => e
    @errors << e.message
    Rails.logger.error("LoanRepaymentService error: #{e.message}\n#{e.backtrace.join("\n")}")
    
    {
      success: false,
      errors: @errors
    }
  end
  
  private
  
  def validate_repayment!(loan_account, principal_amount, interest_amount, fee_amount)
    unless loan_account.account_type == 'ASSET' && loan_account.code.start_with?('LOAN-')
      raise RepaymentError, 'Invalid loan account'
    end
    
    if principal_amount < 0 || interest_amount < 0 || fee_amount < 0
      raise RepaymentError, 'Payment amounts cannot be negative'
    end
    
    total_payment = principal_amount + interest_amount + fee_amount
    if total_payment <= 0
      raise RepaymentError, 'Total payment must be greater than zero'
    end
    
    # Check if principal payment exceeds outstanding balance
    if principal_amount > loan_account.current_balance
      raise RepaymentError, "Principal payment (#{principal_amount}) exceeds outstanding balance (#{loan_account.current_balance})"
    end
  end
  
  def build_repayment_entries(loan_account:, principal_amount:, interest_amount:, fee_amount:, currency:)
    entries = []
    
    # Get cash account
    cash_account = find_cash_account(currency)
    
    # Debit: Cash Account (money received)
    total_received = principal_amount + interest_amount + fee_amount
    entries << {
      account_id: cash_account.id,
      debit: total_received,
      description: "Payment received via M-Pesa"
    }
    
    # Credit: Loan Receivable (principal portion)
    if principal_amount > 0
      entries << {
        account_id: loan_account.id,
        credit: principal_amount,
        description: "Principal repayment"
      }
    end
    
    # Credit: Interest Income (interest portion)
    if interest_amount > 0
      interest_income_account = find_interest_income_account(currency)
      entries << {
        account_id: interest_income_account.id,
        credit: interest_amount,
        description: "Interest income"
      }
    end
    
    # Credit: Fee Receivable (fee portion)
    if fee_amount > 0
      fee_receivable_account = find_fee_receivable_account(currency)
      entries << {
        account_id: fee_receivable_account.id,
        credit: fee_amount,
        description: "Fee payment"
      }
    end
    
    entries
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
  
  def find_interest_income_account(currency)
    Account.find_or_create_by!(
      code: "INTEREST-INCOME-#{currency}",
      account_type: 'INCOME',
      currency: currency
    ) do |account|
      account.name = "Interest Income (#{currency})"
      account.description = "Income from loan interest"
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
end
