# app/services/loan_writeoff_service.rb
#
# Service for writing off defaulted loans
# Records bad debt expense when loans are deemed uncollectible

class LoanWriteoffService
  class WriteoffError < StandardError; end
  
  attr_reader :transaction, :errors
  
  def initialize
    @errors = []
    @transaction_service = TransactionService.new
  end
  
  # Write off a defaulted loan
  #
  # @param loan_account_id [Integer] ID of loan account to write off
  # @param writeoff_amount [Decimal] Amount to write off (optional, defaults to full balance)
  # @param reason [String] Reason for write-off
  # @param reference [String] Unique write-off reference
  # @param metadata [Hash] Additional metadata
  #
  # Example:
  #   service = LoanWriteoffService.new
  #   result = service.writeoff(
  #     loan_account_id: 123,
  #     reason: 'Borrower deceased, no estate',
  #     reference: 'WRITEOFF-2026-001'
  #   )
  def writeoff(loan_account_id:, writeoff_amount: nil, reason:, reference:, metadata: {})
    loan_account = Account.find(loan_account_id)
    
    validate_writeoff!(loan_account)
    
    # Default to full outstanding balance if amount not specified
    writeoff_amount ||= loan_account.current_balance
    
    if writeoff_amount <= 0
      raise WriteoffError, 'Write-off amount must be positive'
    end
    
    if writeoff_amount > loan_account.current_balance
      raise WriteoffError, "Write-off amount (#{writeoff_amount}) exceeds outstanding balance (#{loan_account.current_balance})"
    end
    
    currency = loan_account.currency
    
    # Create write-off transaction
    # DR: Bad Debt Expense (Expense) - increases expense
    # CR: Loans Receivable (Asset) - decreases asset
    @transaction = @transaction_service.create_transaction(
      idempotency_key: "writeoff-#{reference}",
      description: "Loan write-off: #{reason}",
      entries: [
        {
          account_id: find_bad_debt_expense_account(currency).id,
          debit: writeoff_amount,
          description: "Bad debt expense - #{reason}"
        },
        {
          account_id: loan_account.id,
          credit: writeoff_amount,
          description: "Loan written off"
        }
      ],
      metadata: metadata.merge({
        loan_account_id: loan_account_id,
        writeoff_reference: reference,
        writeoff_reason: reason,
        writeoff_amount: writeoff_amount,
        original_balance: loan_account.current_balance
      })
    )
    
    # Mark loan account as inactive if fully written off
    if loan_account.reload.current_balance.abs < 0.01
      loan_account.deactivate!
    end
    
    {
      success: true,
      transaction: @transaction,
      writeoff_amount: writeoff_amount,
      remaining_balance: loan_account.current_balance
    }
  rescue => e
    @errors << e.message
    Rails.logger.error("LoanWriteoffService error: #{e.message}\n#{e.backtrace.join("\n")}")
    
    {
      success: false,
      errors: @errors
    }
  end
  
  # Recover a previously written-off loan
  def recover(loan_account_id:, recovery_amount:, reference:, metadata: {})
    loan_account = Account.find(loan_account_id)
    currency = loan_account.currency
    
    validate_recovery!(loan_account, recovery_amount)
    
    # Create recovery transaction
    # DR: Loans Receivable (Asset) - increases asset
    # CR: Bad Debt Recovery Income (Income) - increases income
    @transaction = @transaction_service.create_transaction(
      idempotency_key: "recovery-#{reference}",
      description: "Recovery of previously written-off loan",
      entries: [
        {
          account_id: loan_account.id,
          debit: recovery_amount,
          description: "Loan recovery"
        },
        {
          account_id: find_bad_debt_recovery_account(currency).id,
          credit: recovery_amount,
          description: "Bad debt recovery income"
        }
      ],
      metadata: metadata.merge({
        loan_account_id: loan_account_id,
        recovery_reference: reference,
        recovery_amount: recovery_amount
      })
    )
    
    # Reactivate account if it was inactive
    loan_account.activate! unless loan_account.active?
    
    {
      success: true,
      transaction: @transaction,
      recovery_amount: recovery_amount,
      new_balance: loan_account.reload.current_balance
    }
  rescue => e
    @errors << e.message
    Rails.logger.error("LoanWriteoffService recovery error: #{e.message}\n#{e.backtrace.join("\n")}")
    
    {
      success: false,
      errors: @errors
    }
  end
  
  private
  
  def validate_writeoff!(loan_account)
    unless loan_account.account_type == 'ASSET' && loan_account.code.start_with?('LOAN-')
      raise WriteoffError, 'Invalid loan account'
    end
    
    unless loan_account.active?
      raise WriteoffError, 'Cannot write off inactive loan account'
    end
    
    if loan_account.current_balance <= 0
      raise WriteoffError, 'Loan has no outstanding balance'
    end
  end
  
  def validate_recovery!(loan_account, recovery_amount)
    unless loan_account.account_type == 'ASSET' && loan_account.code.start_with?('LOAN-')
      raise WriteoffError, 'Invalid loan account'
    end
    
    if recovery_amount <= 0
      raise WriteoffError, 'Recovery amount must be positive'
    end
  end
  
  def find_bad_debt_expense_account(currency)
    Account.find_or_create_by!(
      code: "BAD-DEBT-EXPENSE-#{currency}",
      account_type: 'EXPENSE',
      currency: currency
    ) do |account|
      account.name = "Bad Debt Expense (#{currency})"
      account.description = "Expense from uncollectible loans"
    end
  end
  
  def find_bad_debt_recovery_account(currency)
    Account.find_or_create_by!(
      code: "BAD-DEBT-RECOVERY-#{currency}",
      account_type: 'INCOME',
      currency: currency
    ) do |account|
      account.name = "Bad Debt Recovery Income (#{currency})"
      account.description = "Income from recovery of written-off loans"
    end
  end
end
