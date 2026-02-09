# app/queries/loan_aging_query.rb
#
# Query class for generating loan aging reports
# Uses materialized view for performance

class LoanAgingQuery
  BUCKETS = LoanAgingReport::AGING_BUCKETS
  
  class << self
    # Generate complete loan aging report
    def generate(refresh: false, currency: nil)
      # Refresh materialized view if requested
      LoanAgingReport.refresh! if refresh
      
      # Try cache first (unless refresh requested)
      unless refresh
        cached = fetch_from_cache(currency)
        return cached if cached
      end
      
      # Build report
      report = build_report(currency)
      
      # Cache result
      cache_report(report, currency) unless currency
      
      report
    end
    
    # Get summary by aging bucket
    def summary(currency: nil)
      scope = LoanAgingReport.all
      scope = scope.joins(:account).merge(Account.where(currency: currency)) if currency
      
      summary = scope.group(:aging_bucket)
                    .select(
                      'aging_bucket',
                      'COUNT(*) as loan_count',
                      'SUM(outstanding_balance) as total_outstanding',
                      'AVG(outstanding_balance) as avg_loan_size',
                      'MIN(outstanding_balance) as min_loan_size',
                      'MAX(outstanding_balance) as max_loan_size'
                    )
                    .map do |record|
        bucket_info = BUCKETS[record.aging_bucket]
        {
          bucket: record.aging_bucket,
          label: bucket_info[:label],
          order: bucket_info[:order],
          loan_count: record.loan_count,
          total_outstanding: record.total_outstanding.to_f,
          avg_loan_size: record.avg_loan_size.to_f,
          min_loan_size: record.min_loan_size.to_f,
          max_loan_size: record.max_loan_size.to_f,
          percentage: 0 # Calculated below
        }
      end.sort_by { |b| b[:order] }
      
      # Calculate percentages
      total_outstanding = summary.sum { |b| b[:total_outstanding] }
      summary.each do |bucket|
        bucket[:percentage] = if total_outstanding > 0
          (bucket[:total_outstanding] / total_outstanding * 100).round(2)
        else
          0
        end
      end
      
      {
        summary: summary,
        total_outstanding: total_outstanding,
        currency: currency
      }
    end
    
    # Get top N overdue loans
    def top_overdue(limit: 10, currency: nil)
      scope = LoanAgingReport.overdue.by_outstanding
      scope = scope.joins(:account).merge(Account.where(currency: currency)) if currency
      
      scope.limit(limit).map do |loan|
        format_loan(loan)
      end
    end
    
    # Get loans in specific aging bucket
    def by_bucket(bucket, limit: 100, offset: 0, currency: nil)
      scope = LoanAgingReport.where(aging_bucket: bucket).by_outstanding
      scope = scope.joins(:account).merge(Account.where(currency: currency)) if currency
      
      total_count = scope.count
      loans = scope.limit(limit).offset(offset)
      
      {
        bucket: bucket,
        bucket_label: BUCKETS[bucket][:label],
        total_count: total_count,
        loans: loans.map { |loan| format_loan(loan) },
        page: (offset / limit) + 1,
        per_page: limit,
        total_pages: (total_count.to_f / limit).ceil
      }
    end
    
    private
    
    def build_report(currency)
      summary_data = summary(currency: currency)
      risk_data = risk_metrics(currency: currency)
      
      # Get detailed loans for each bucket
      buckets_with_loans = summary_data[:summary].map do |bucket|
        loans = LoanAgingReport.where(aging_bucket: bucket[:bucket])
                              .by_outstanding
                              .limit(100)
        
        loans = loans.joins(:account).merge(Account.where(currency: currency)) if currency
        
        bucket.merge(
          loans: loans.map { |loan| format_loan(loan) }
        )
      end
      
      {
        generated_at: Time.current,
        last_refreshed: get_last_refresh_time,
        currency: currency,
        summary: summary_data[:summary],
        buckets: buckets_with_loans,
        totals: {
          total_loans: summary_data[:summary].sum { |b| b[:loan_count] },
          total_outstanding: summary_data[:total_outstanding]
        },
        risk_metrics: risk_data
      }
    end
    
    def risk_metrics(currency: nil)
      scope = LoanAgingReport.all
      scope = scope.joins(:account).merge(Account.where(currency: currency)) if currency
      
      total_outstanding = scope.sum(:outstanding_balance).to_f
      total_loans = scope.count
      
      overdue_scope = scope.overdue
      overdue_outstanding = overdue_scope.sum(:outstanding_balance).to_f
      overdue_loans = overdue_scope.count
      
      severely_overdue_scope = scope.where(aging_bucket: ['60_89_days', '90_plus_days'])
      severely_overdue_outstanding = severely_overdue_scope.sum(:outstanding_balance).to_f
      severely_overdue_loans = severely_overdue_scope.count
      
      {
        total_loans: total_loans,
        total_outstanding: total_outstanding,
        overdue_loans: overdue_loans,
        overdue_outstanding: overdue_outstanding,
        overdue_rate: total_outstanding > 0 ? (overdue_outstanding / total_outstanding * 100).round(2) : 0,
        severely_overdue_loans: severely_overdue_loans,
        severely_overdue_outstanding: severely_overdue_outstanding,
        severely_overdue_rate: total_outstanding > 0 ? (severely_overdue_outstanding / total_outstanding * 100).round(2) : 0,
        average_loan_size: total_loans > 0 ? (total_outstanding / total_loans).round(2) : 0
      }
    end
    
    def format_loan(loan)
      {
        loan_account_id: loan.loan_account_id,
        loan_code: loan.loan_code,
        borrower_name: loan.borrower_name,
        outstanding_balance: loan.outstanding_balance.to_f,
        disbursement_date: loan.disbursement_date,
        last_payment_date: loan.last_payment_date,
        days_since_last_payment: loan.days_since_last_payment,
        aging_bucket: loan.aging_bucket,
        aging_bucket_label: BUCKETS[loan.aging_bucket][:label]
      }
    end
    
    def get_last_refresh_time
      result = ActiveRecord::Base.connection.exec_query(
        "SELECT last_autovacuum FROM pg_stat_user_tables WHERE relname = 'loan_aging_report'"
      )
      result.first&.fetch('last_autovacuum', nil)
    rescue => e
      Rails.logger.warn("Could not get last refresh time: #{e.message}")
      nil
    end
    
    def fetch_from_cache(currency)
      return nil unless defined?(REDIS) && REDIS
      return nil if currency # Don't cache filtered results
      
      cached = REDIS.get('loan_aging_report:current')
      JSON.parse(cached, symbolize_names: true) if cached
    rescue Redis::BaseError, JSON::ParserError
      nil
    end
    
    def cache_report(report, currency)
      return unless defined?(REDIS) && REDIS
      return if currency # Don't cache filtered results
      
      REDIS.setex('loan_aging_report:current', 15.minutes.to_i, report.to_json)
    rescue Redis::BaseError
      # Silent fail
    end
  end
end