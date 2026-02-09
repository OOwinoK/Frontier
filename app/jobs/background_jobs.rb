# app/jobs/create_daily_balance_snapshots_job.rb
class CreateDailyBalanceSnapshotsJob < ApplicationJob
  queue_as :default
  def perform(date = Date.yesterday)
    AccountBalanceSnapshot.create_daily_snapshots(date)
  end
end

# app/jobs/refresh_loan_aging_report_job.rb  
class RefreshLoanAgingReportJob < ApplicationJob
  queue_as :reports
  def perform
    LoanAgingReport.refresh!
  end
end

# app/jobs/create_entries_partition_job.rb
class CreateEntriesPartitionJob < ApplicationJob
  queue_as :default
  def perform
    next_month = 1.month.from_now
    partition_name = "entries_#{next_month.strftime('%Y_%m')}"
    start_date = next_month.beginning_of_month
    end_date = (next_month + 1.month).beginning_of_month
    
    sql = <<-SQL
      CREATE TABLE IF NOT EXISTS #{partition_name} 
      PARTITION OF entries
      FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
      
      CREATE INDEX IF NOT EXISTS idx_#{partition_name}_account 
        ON #{partition_name}(account_id, created_at);
      
      CREATE INDEX IF NOT EXISTS idx_#{partition_name}_transaction
        ON #{partition_name}(transaction_id);
    SQL
    
    ActiveRecord::Base.connection.execute(sql)
  end
end

# app/jobs/warm_balance_cache_job.rb
class WarmBalanceCacheJob < ApplicationJob
  queue_as :low_priority
  def perform(cache_misses)
    BalanceCache.bulk_set(cache_misses)
  end
end
