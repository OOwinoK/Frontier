# app/models/transaction.rb

class Transaction < ApplicationRecord
  # Transaction statuses
  STATUSES = %w[pending posted voided reversed].freeze
  
  # Associations
  has_many :entries, foreign_key: 'transaction_id', dependent: :destroy, inverse_of: :txn
  has_many :accounts, through: :entries
  
  accepts_nested_attributes_for :entries
  
  # Validations
  validates :idempotency_key, presence: true, uniqueness: true
  validates :posted_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :description, length: { maximum: 10_000 }
  validates :external_reference, length: { maximum: 255 }
  
  # Custom validations
  validate :must_have_entries, on: :create
  validate :entries_must_balance
  validate :cannot_modify_posted_transaction, on: :update
  
  # Scopes
  scope :posted, -> { where(status: 'posted') }
  scope :pending, -> { where(status: 'pending') }
  scope :voided, -> { where(status: 'voided') }
  scope :reversed, -> { where(status: 'reversed') }
  scope :recent, -> { order(posted_at: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(posted_at: start_date..end_date) }
  
  # Callbacks
  before_validation :set_posted_at, on: :create
  
  # Instance Methods
  
  def balanced?
    return false if entries.empty?
    
    total_debits = entries.map { |e| e.debit.to_f }.sum
    total_credits = entries.map { |e| e.credit.to_f }.sum
    
    (total_debits - total_credits).abs < 0.0001
  end
  
  def total_debits
    entries.map { |e| e.debit.to_f }.sum
  end
  
  def total_credits
    entries.map { |e| e.credit.to_f }.sum
  end
  
  def void!(reason: 'Manual void')
    raise 'Cannot void non-posted transaction' unless posted?
    raise 'Transaction already voided' if voided?
    
    ActiveRecord::Base.transaction do
      reversal = Transaction.new(
        idempotency_key: "#{idempotency_key}-void",
        description: "VOID: #{description}",
        posted_at: Time.current,
        status: 'posted',
        metadata: (metadata || {}).merge(
          voided_transaction_id: id,
          void_reason: reason
        )
      )
      
      entries.each do |entry|
        reversal.entries.build(
          account: entry.account,
          debit: entry.credit,
          credit: entry.debit,
          description: "Reversal of entry ##{entry.id}"
        )
      end
      
      reversal.save!
      
      update!(
        status: 'voided',
        metadata: (metadata || {}).merge(
          voided_at: Time.current,
          voided_by_transaction_id: reversal.id
        )
      )
      
      reversal
    end
  end
  
  def reverse!(reason: 'Manual reversal')
    raise 'Cannot reverse non-posted transaction' unless posted?
    raise 'Transaction already reversed' if reversed?
    
    ActiveRecord::Base.transaction do
      reversal = Transaction.new(
        idempotency_key: "#{idempotency_key}-reverse",
        description: "REVERSAL: #{description}",
        posted_at: Time.current,
        status: 'posted',
        metadata: (metadata || {}).merge(
          reversed_transaction_id: id,
          reversal_reason: reason
        )
      )
      
      entries.each do |entry|
        reversal.entries.build(
          account: entry.account,
          debit: entry.credit,
          credit: entry.debit,
          description: "Reversal of entry ##{entry.id}"
        )
      end
      
      reversal.save!
      
      update!(
        status: 'reversed',
        metadata: (metadata || {}).merge(
          reversed_at: Time.current,
          reversed_by_transaction_id: reversal.id
        )
      )
      
      reversal
    end
  end
  
  def posted?
    status == 'posted'
  end
  
  def pending?
    status == 'pending'
  end
  
  def voided?
    status == 'voided'
  end
  
  def reversed?
    status == 'reversed'
  end
  
  def affected_account_ids
    entries.map(&:account_id).uniq
  end
  
  private
  
  def set_posted_at
    self.posted_at ||= Time.current
  end
  
  def must_have_entries
    if entries.empty? || entries.all?(&:marked_for_destruction?)
      errors.add(:base, 'Transaction must have at least one entry')
    end
  end
  
  def entries_must_balance
    return if entries.empty?
    
    unless balanced?
      errors.add(:base, "Transaction must balance (debits: #{total_debits}, credits: #{total_credits})")
    end
  end
  
  def cannot_modify_posted_transaction
    # The fix: Ensure we have 'end' for the if block and exclude status/metadata from the lock
    if persisted? && (posted? || voided? || reversed?) && changed?
      allowed_keys = ['status', 'metadata', 'updated_at']
      non_allowed_changes = changes.keys - allowed_keys
      
      if non_allowed_changes.any?
        errors.add(:base, 'Cannot modify posted/voided/reversed transaction details')
      end
    end
  end
end