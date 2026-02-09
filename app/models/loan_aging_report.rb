# == Schema Information
#
# Materialized View: loan_aging_report
#
#  loan_account_id         :bigint           primary key
#  loan_code               :string
#  borrower_name           :string
#  outstanding_balance     :decimal(20, 4)
#  disbursement_date       :datetime
#  last_payment_date       :datetime
#  days_since_last_payment :integer
#  aging_bucket            :string
#

class LoanAgingReport < ApplicationRecord
  # This is a readonly materialized view
  self.table_name = 'loan_aging_report'  # Add this line
  self.primary_key = 'loan_account_id'
  
  # Aging buckets
  AGING_BUCKETS = {
    'current' => { label: 'Current (0-29 days)', order: 1, days: 0..29 },
    '30_59_days' => { label: '30-59 days overdue', order: 2, days: 30..59 },
    '60_89_days' => { label: '60-89 days overdue', order: 3, days: 60..89 },
    '90_plus_days' => { label: '90+ days overdue', order: 4, days: 90..Float::INFINITY }
  }.freeze
  
  # Make this readonly
  def readonly?
    true
  end
  
  # Scopes
  scope :current, -> { where(aging_bucket: 'current') }
  scope :overdue_30_59, -> { where(aging_bucket: '30_59_days') }
  scope :overdue_60_89, -> { where(aging_bucket: '60_89_days') }
  scope :overdue_90_plus, -> { where(aging_bucket: '90_plus_days') }
  scope :overdue, -> { where.not(aging_bucket: 'current') }
  scope :by_outstanding, -> { order(outstanding_balance: :desc) }
  scope :by_days_overdue, -> { order(days_since_last_payment: :desc) }
  
  # Class Methods
  
  # Refresh the materialized view
  def self.refresh!(concurrently: true)
    sql = if concurrently
      'REFRESH MATERIALIZED VIEW CONCURRENTLY loan_aging_report'
    else
      'REFRESH MATERIALIZED VIEW loan_aging_report'
    end
    
    connection.execute(sql)
  end
  
  # Get summary by aging bucket
  def self.summary
    group(:aging_bucket)
      .select(
        'aging_bucket',
        'COUNT(*) as loan_count',
        'SUM(outstanding_balance) as total_outstanding',
        'AVG(outstanding_balance) as avg_loan_size',
        'MIN(outstanding_balance) as min_loan_size',
        'MAX(outstanding_balance) as max_loan_size'
      )
      .map do |record|
        bucket_info = AGING_BUCKETS[record.aging_bucket]
        {
          bucket: record.aging_bucket,
          label: bucket_info[:label],
          order: bucket_info[:order],
          loan_count: record.loan_count,
          total_outstanding: record.total_outstanding.to_f,
          avg_loan_size: record.avg_loan_size.to_f,
          min_loan_size: record.min_loan_size.to_f,
          max_loan_size: record.max_loan_size.to_f
        }
      end
      .sort_by { |b| b[:order] }
  end
  
  # Get risk metrics
  def self.risk_metrics
    total_outstanding = sum(:outstanding_balance).to_f
    overdue_outstanding = overdue.sum(:outstanding_balance).to_f
    severely_overdue_outstanding = where(aging_bucket: ['60_89_days', '90_plus_days'])
      .sum(:outstanding_balance).to_f
    
    {
      total_loans: count,
      total_outstanding: total_outstanding,
      current_loans: current.count,
      overdue_loans: overdue.count,
      overdue_rate: total_outstanding > 0 ? (overdue_outstanding / total_outstanding * 100).round(2) : 0,
      severely_overdue_rate: total_outstanding > 0 ? (severely_overdue_outstanding / total_outstanding * 100).round(2) : 0
    }
  end
  
  # Instance Methods
  
  # Get bucket information
  def bucket_info
    AGING_BUCKETS[aging_bucket]
  end
  
  # Check if loan is current
  def current?
    aging_bucket == 'current'
  end
  
  # Check if loan is overdue
  def overdue?
    !current?
  end
  
  # Check if severely overdue (60+ days)
  def severely_overdue?
    ['60_89_days', '90_plus_days'].include?(aging_bucket)
  end
  
  # Get related account
  def account
    @account ||= Account.find(loan_account_id)
  end
end
