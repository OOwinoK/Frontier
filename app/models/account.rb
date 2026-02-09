# == Schema Information
#
# Table name: accounts
#
#  id                  :bigint           not null, primary key
#  code                :string(50)       not null
#  name                :string(255)      not null
#  description         :text
#  account_type        :string(20)       not null
#  currency            :string(3)        default("KES"), not null
#  parent_account_id   :bigint
#  current_balance     :decimal(20, 4)   default(0.0), not null
#  total_entries_count :bigint           default(0), not null
#  balance_updated_at  :datetime
#  lock_version        :integer          default(0), not null
#  active              :boolean          default(TRUE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class Account < ApplicationRecord
  # Account types following accounting equation: Assets = Liabilities + Equity
  TYPES = %w[ASSET LIABILITY EQUITY INCOME EXPENSE].freeze
  
  # Supported currencies
  CURRENCIES = %w[KES UGX USD].freeze
  
  # Associations
  belongs_to :parent_account, class_name: 'Account', optional: true
  has_many :child_accounts, class_name: 'Account', foreign_key: :parent_account_id, dependent: :restrict_with_error
  has_many :entries, dependent: :restrict_with_error
  has_many :transactions, through: :entries
  has_many :balance_snapshots, class_name: 'AccountBalanceSnapshot', dependent: :destroy
  
  # Validations
  validates :code, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :account_type, presence: true, inclusion: { in: TYPES }
  validates :currency, presence: true, inclusion: { in: CURRENCIES }, length: { is: 3 }
  validates :current_balance, numericality: true
  validates :total_entries_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Custom validations
  validate :prevent_circular_hierarchy
  validate :prevent_deletion_with_entries, on: :destroy
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_type, ->(type) { where(account_type: type) }
  scope :by_currency, ->(currency) { where(currency: currency) }
  scope :root_accounts, -> { where(parent_account_id: nil) }
  scope :with_balance, -> { where.not(current_balance: 0) }
  
  # Callbacks
  before_destroy :check_can_delete
  
  # Instance Methods
  
  # Get current balance (uses cache or denormalized value)
  def balance(as_of: Time.current)
    if as_of.to_date == Date.current
      current_balance_cached
    else
      historical_balance(as_of)
    end
  end
  
  # Current balance with Redis caching
  def current_balance_cached
    # Try Redis cache first
    cached = BalanceCache.get(id, lock_version)
    return cached if cached
    
    # Fall back to denormalized column
    balance_value = current_balance
    
    # Warm cache for next time
    BalanceCache.set(id, lock_version, balance_value)
    
    balance_value
  end
  
  # Recalculate balance from entries and update denormalized column
  def recalculate_balance!
    # Use snapshot + recent entries for efficiency
    snapshot = balance_snapshots
      .where('snapshot_date < ?', Date.current)
      .order(snapshot_date: :desc)
      .first
    
    if snapshot
      # Only calculate from last snapshot
      recent_balance = entries
        .where('created_at > ?', snapshot.snapshot_date.end_of_day)
        .sum('COALESCE(debit, 0) - COALESCE(credit, 0)')
        .to_f
      
      new_balance = snapshot.balance + recent_balance
    else
      # No snapshot - calculate all (rare, only for new accounts)
      new_balance = entries.sum('COALESCE(debit, 0) - COALESCE(credit, 0)').to_f
    end
    
    update_columns(
      current_balance: new_balance,
      balance_updated_at: Time.current
    )
    
    # Update cache
    BalanceCache.set(id, lock_version, new_balance)
    
    new_balance
  end
  
  # Get balance as of a specific date
  def historical_balance(as_of)
    # Find nearest snapshot before requested date
    snapshot = balance_snapshots
      .where('snapshot_date <= ?', as_of.to_date)
      .order(snapshot_date: :desc)
      .first
    
    if snapshot
      # Calculate delta from snapshot to requested date
      delta = entries
        .where('created_at > ? AND created_at <= ?', 
               snapshot.snapshot_date.end_of_day, 
               as_of)
        .sum('COALESCE(debit, 0) - COALESCE(credit, 0)')
        .to_f
      
      snapshot.balance + delta
    else
      # No snapshot - calculate from beginning (slow but rare)
      entries
        .where('created_at <= ?', as_of)
        .sum('COALESCE(debit, 0) - COALESCE(credit, 0)')
        .to_f
    end
  end
  
  # Get account hierarchy path
  def hierarchy_path
    path = [self]
    current = self
    
    while current.parent_account.present?
      current = current.parent_account
      path.unshift(current)
    end
    
    path
  end
  
  # Get full account code with hierarchy
  def full_code
    hierarchy_path.map(&:code).join(':')
  end
  
  # Check if this is a debit-normal account
  def debit_normal?
    %w[ASSET EXPENSE].include?(account_type)
  end
  
  # Check if this is a credit-normal account
  def credit_normal?
    %w[LIABILITY EQUITY INCOME].include?(account_type)
  end
  
  # Deactivate account (soft delete)
  def deactivate!
    update!(active: false)
  end
 
  # Reactivate account
  def activate!
    update!(active: true)
  end
  
  private
  
  def prevent_circular_hierarchy
    return unless parent_account_id
    
    current = Account.find_by(id: parent_account_id)
    visited = Set.new([id])
    
    while current
      if visited.include?(current.id)
        errors.add(:parent_account_id, 'creates a circular reference')
        return
      end
      
      visited.add(current.id)
      current = current.parent_account
    end
  end
  
  def prevent_deletion_with_entries
    if total_entries_count > 0
      errors.add(:base, 'Cannot delete account with transaction history')
    end
  end
  
  def check_can_delete
    if total_entries_count > 0
      throw :abort
    end
  end
end
