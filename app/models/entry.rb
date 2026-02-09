# == Schema Information
#
# Table name: entries (partitioned by created_at)
#
#  id             :bigint           not null, primary key
#  transaction_id :bigint           not null
#  account_id     :bigint           not null
#  debit          :decimal(20, 4)
#  credit         :decimal(20, 4)
#  description    :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class Entry < ApplicationRecord
  # Associations - Use 'txn' to avoid conflict with ActiveRecord's transaction method
  belongs_to :txn, 
             class_name: 'Transaction', 
             foreign_key: 'transaction_id', 
             inverse_of: :entries

  belongs_to :account
  
  # Validations
  validates :debit, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :credit, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :description, length: { maximum: 10_000 }
  
  # Custom validations
  validate :must_have_debit_or_credit
  validate :cannot_have_both_debit_and_credit
  validate :amount_must_be_positive
  
  # Scopes
  scope :debits, -> { where.not(debit: nil) }
  scope :credits, -> { where.not(credit: nil) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :recent, -> { order(created_at: :desc) }
  
  # NOTE: Balance updates are handled by TransactionService to ensure proper
  # accounting rules (debit normal vs credit normal accounts) and atomicity.
  # We only keep the recalculate callback for manual entry deletions outside
  # of normal transaction workflows.
  after_destroy :recalculate_account_balance, if: -> { account.present? }
  
  # Instance Methods
  
  # Get the amount (debit or credit)
  def amount
    debit || credit || 0
  end
  
  # Check if this is a debit entry
  def debit?
    debit.present? && debit > 0
  end
  
  # Check if this is a credit entry
  def credit?
    credit.present? && credit > 0
  end
  
  # Get the entry type
  def entry_type
    debit? ? 'debit' : 'credit'
  end
  
  # Get the impact on account balance based on accounting normal balances
  # ASSET & EXPENSE (Debit Normal): Debit increases, Credit decreases
  # LIABILITY, EQUITY, INCOME (Credit Normal): Credit increases, Debit decreases
  def balance_impact
    if debit?
      account.debit_normal? ? amount : -amount
    else
      account.credit_normal? ? amount : -amount
    end
  end
  
  # Get formatted debit/credit for display
  def debit_display
    debit? ? amount.to_f : nil
  end
  
  def credit_display
    credit? ? amount.to_f : nil
  end
  
  private
  
  def must_have_debit_or_credit
    if debit.nil? && credit.nil?
      errors.add(:base, 'Entry must have either debit or credit')
    end
  end
  
  def cannot_have_both_debit_and_credit
    if debit.present? && credit.present?
      errors.add(:base, 'Entry cannot have both debit and credit')
    end
  end
  
  def amount_must_be_positive
    if debit.present? && debit <= 0
      errors.add(:debit, 'must be positive')
    end
    
    if credit.present? && credit <= 0
      errors.add(:credit, 'must be positive')
    end
  end
  
  def recalculate_account_balance
    # Only recalculate when entry is destroyed outside of transaction service
    # TransactionService handles balance updates during transaction creation
    account.recalculate_balance! if account.persisted?
    BalanceCache.invalidate(account_id)
  rescue => e
    Rails.logger.error("Failed to recalculate balance for account #{account_id}: #{e.message}")
    # Don't raise - allow deletion to proceed
  end
end