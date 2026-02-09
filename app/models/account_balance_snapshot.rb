# == Schema Information
#
# Table name: account_balance_snapshots
#
#  id            :bigint           not null, primary key
#  account_id    :bigint           not null
#  snapshot_date :date             not null
#  balance       :decimal(20, 4)   not null
#  entries_count :bigint           default(0), not null
#  metadata      :jsonb
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class AccountBalanceSnapshot < ApplicationRecord
  # Associations
  belongs_to :account
  
  # Validations
  validates :snapshot_date, presence: true, uniqueness: { scope: :account_id }
  validates :balance, presence: true, numericality: true
  validates :entries_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :for_date, ->(date) { where(snapshot_date: date) }
  scope :recent, -> { order(snapshot_date: :desc) }
  scope :before_date, ->(date) { where('snapshot_date < ?', date) }
  scope :after_date, ->(date) { where('snapshot_date > ?', date) }
  
  # Class Methods
  
  # Create snapshot for an account on a specific date
  def self.create_for_account(account, date = Date.yesterday)
    # Calculate balance up to end of date
    balance = account.entries
      .where('created_at <= ?', date.end_of_day)
      .sum('COALESCE(debit, 0) - COALESCE(credit, 0)')
      .to_f
    
    entries_count = account.entries
      .where('created_at <= ?', date.end_of_day)
      .count
    
    create!(
      account: account,
      snapshot_date: date,
      balance: balance,
      entries_count: entries_count,
      metadata: {
        created_by: 'system',
        snapshot_type: 'daily'
      }
    )
  end
  
  # Create snapshots for all accounts
  def self.create_daily_snapshots(date = Date.yesterday)
    Account.active.find_each do |account|
      # Skip if snapshot already exists
      next if exists?(account_id: account.id, snapshot_date: date)
      
      create_for_account(account, date)
    rescue => e
      Rails.logger.error("Failed to create snapshot for account #{account.id}: #{e.message}")
    end
  end
  
  # Instance Methods
  
  # Get the next snapshot for this account
  def next_snapshot
    account.balance_snapshots
      .where('snapshot_date > ?', snapshot_date)
      .order(snapshot_date: :asc)
      .first
  end
  
  # Get the previous snapshot for this account
  def previous_snapshot
    account.balance_snapshots
      .where('snapshot_date < ?', snapshot_date)
      .order(snapshot_date: :desc)
      .first
  end
  
  # Calculate balance change since last snapshot
  def balance_change
    prev = previous_snapshot
    return balance if prev.nil?
    
    balance - prev.balance
  end
  
  # Calculate entries added since last snapshot
  def entries_added
    prev = previous_snapshot
    return entries_count if prev.nil?
    
    entries_count - prev.entries_count
  end
end
