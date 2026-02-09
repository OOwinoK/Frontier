# Deployment & Operations Guide

Production deployment guide for Core Banking LMS.

## Table of Contents
- [Production Checklist](#production-checklist)
- [Environment Setup](#environment-setup)
- [Database Setup](#database-setup)
- [Background Jobs](#background-jobs)
- [Monitoring](#monitoring)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Production Checklist

### Before Deployment

- [ ] Set up PostgreSQL 14+ with proper configuration
- [ ] Set up Redis 7+ with persistence
- [ ] Configure environment variables
- [ ] Enable SSL/TLS for database connections
- [ ] Set up backup strategy
- [ ] Configure logging
- [ ] Set up monitoring (Datadog, New Relic, etc.)
- [ ] Add authentication (JWT, OAuth2)
- [ ] Add rate limiting
- [ ] Configure CORS properly
- [ ] Set up CDN for static assets (if needed)
- [ ] Run security audit (Brakeman)
- [ ] Load testing

### Security

```ruby
# config/initializers/cors.rb - Production
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'yourdomain.com', 'app.yourdomain.com'  # Specific domains only
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

## Environment Setup

### Production Environment Variables

```env
# Database
POSTGRES_USER=production_user
POSTGRES_PASSWORD=strong_password_here
POSTGRES_HOST=db.production.internal
POSTGRES_PORT=5432
DATABASE_URL=postgresql://user:pass@host:5432/core_banking_lms_production

# Redis
REDIS_URL=redis://redis.production.internal:6379/0
REDIS_ENABLED=true

# Rails
RAILS_ENV=production
RAILS_MAX_THREADS=10
RAILS_SERVE_STATIC_FILES=false
RAILS_LOG_TO_STDOUT=true

# Secrets
SECRET_KEY_BASE=generate_with_rails_secret

# Application
ALLOWED_HOSTS=yourdomain.com,api.yourdomain.com
```

### Generate Secrets

```bash
# Generate secret key base
rails secret

# Generate master key
rails credentials:edit
```

## Database Setup

### PostgreSQL Configuration

**postgresql.conf**
```ini
# Connection Settings
max_connections = 200
shared_buffers = 4GB
effective_cache_size = 12GB
maintenance_work_mem = 1GB
work_mem = 20MB

# Write Performance
wal_buffers = 16MB
checkpoint_completion_target = 0.9
max_wal_size = 2GB
min_wal_size = 1GB

# Query Planning
random_page_cost = 1.1
effective_io_concurrency = 200
```

### Database Backups

**Daily Backups**
```bash
#!/bin/bash
# /usr/local/bin/backup_database.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/postgresql"
DB_NAME="core_banking_lms_production"

pg_dump -h localhost -U postgres -Fc $DB_NAME > $BACKUP_DIR/backup_$DATE.dump

# Keep only last 30 days
find $BACKUP_DIR -name "backup_*.dump" -mtime +30 -delete

# Upload to S3 (optional)
aws s3 cp $BACKUP_DIR/backup_$DATE.dump s3://your-bucket/backups/
```

**Cron Schedule**
```cron
# Daily at 2 AM
0 2 * * * /usr/local/bin/backup_database.sh
```

### Database Restore

```bash
# Restore from backup
pg_restore -h localhost -U postgres -d core_banking_lms_production backup_20260208.dump
```

### Partition Management

**Monthly Partition Creation**
```ruby
# Run on 25th of each month
CreateEntriesPartitionJob.perform_later
```

**Manual Partition Creation**
```sql
-- Create partition for March 2026
CREATE TABLE entries_2026_03 
PARTITION OF entries
FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

-- Create indexes
CREATE INDEX idx_entries_2026_03_account ON entries_2026_03(account_id, created_at);
CREATE INDEX idx_entries_2026_03_transaction ON entries_2026_03(transaction_id);
```

## Background Jobs

### Sidekiq Setup

**Procfile**
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

**config/sidekiq.yml**
```yaml
:concurrency: 5
:queues:
  - critical
  - default
  - reports
  - low_priority
```

### Scheduled Jobs

**config/initializers/sidekiq_scheduler.rb**
```ruby
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = {
      'daily_balance_snapshots' => {
        'cron' => '0 2 * * *',  # 2 AM daily
        'class' => 'CreateDailyBalanceSnapshotsJob'
      },
      'refresh_loan_aging' => {
        'cron' => '0 * * * *',  # Every hour
        'class' => 'RefreshLoanAgingReportJob'
      },
      'create_monthly_partition' => {
        'cron' => '0 0 25 * *',  # 25th of each month
        'class' => 'CreateEntriesPartitionJob'
      }
    }
    
    Sidekiq::Scheduler.reload_schedule!
  end
end
```

### Monitor Sidekiq

```bash
# Web UI (add to routes.rb)
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'

# Access at: http://yourdomain.com/sidekiq
```

## Monitoring

### Application Performance Monitoring

**New Relic**
```ruby
# Gemfile
gem 'newrelic_rpm'

# config/newrelic.yml
production:
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  app_name: Core Banking LMS
```

**Datadog**
```ruby
# Gemfile
gem 'ddtrace'

# config/initializers/datadog.rb
Datadog.configure do |c|
  c.tracing.instrument :rails
  c.tracing.instrument :redis
  c.tracing.instrument :pg
end
```

### Database Monitoring

```sql
-- Active queries
SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%'
ORDER BY query_start desc;

-- Slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 20;

-- Table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Redis Monitoring

```bash
# Redis CLI
redis-cli info stats
redis-cli info memory
redis-cli slowlog get 10

# Monitor cache hit rate
redis-cli info stats | grep keyspace
```

### Health Checks

```bash
# Application health
curl http://localhost:3000/health

# Database health
rails runner "puts ActiveRecord::Base.connection.active? ? 'OK' : 'FAIL'"

# Redis health
rails runner "puts REDIS.ping == 'PONG' ? 'OK' : 'FAIL'"
```

## Maintenance

### Daily Tasks

1. **Check Balance Snapshots**
```bash
rails runner "puts AccountBalanceSnapshot.where(snapshot_date: Date.yesterday).count"
```

2. **Verify Trial Balance**
```bash
rails runner "tb = TrialBalanceQuery.generate; puts tb[:balanced] ? 'OK' : 'UNBALANCED!'"
```

3. **Check Failed Jobs**
```bash
# Sidekiq dashboard or
rails runner "puts Sidekiq::Stats.new.failed"
```

### Weekly Tasks

1. **Refresh Materialized Views**
```bash
rails runner "LoanAgingReport.refresh!"
```

2. **Analyze Database Tables**
```sql
ANALYZE accounts;
ANALYZE transactions;
ANALYZE entries;
```

3. **Check Partition Health**
```sql
SELECT tablename FROM pg_tables 
WHERE tablename LIKE 'entries_%' 
ORDER BY tablename;
```

### Monthly Tasks

1. **Create Next Month's Partition**
```bash
CreateEntriesPartitionJob.perform_now
```

2. **Archive Old Snapshots** (optional)
```sql
-- Archive snapshots older than 1 year
DELETE FROM account_balance_snapshots 
WHERE snapshot_date < CURRENT_DATE - INTERVAL '1 year';
```

3. **Review Slow Queries**
```sql
SELECT * FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 50;
```

## Troubleshooting

### Common Issues

#### 1. Unbalanced Transactions

**Symptom:** Trial balance doesn't balance
```bash
# Check for rounding issues
rails runner "
  Account.find_each do |account|
    calculated = account.entries.sum('COALESCE(debit, 0) - COALESCE(credit, 0)')
    if (calculated - account.current_balance).abs > 0.01
      puts \"Account \#{account.code}: DB=\#{account.current_balance}, Calc=\#{calculated}\"
    end
  end
"
```

**Fix:**
```bash
# Recalculate all balances
rails runner "Account.find_each { |a| a.recalculate_balance! }"
```

#### 2. Partition Missing

**Symptom:** Entries insert fails with "no partition found"

**Fix:**
```bash
# Create missing partition
CreateEntriesPartitionJob.perform_now
```

#### 3. Redis Down

**Symptom:** Slow balance queries, but system still works

**Fix:**
```bash
# System degrades gracefully, but restart Redis
sudo service redis-server restart

# Clear stale cache
rails runner "BalanceCache.clear_all"
```

#### 4. Database Lock Timeout

**Symptom:** Transactions timeout with "could not obtain lock"

**Fix:**
```sql
-- Find blocking queries
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.usename AS blocked_user,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- Kill blocking query if needed
SELECT pg_terminate_backend(blocking_pid);
```

### Performance Degradation

**Check:**
1. Redis memory usage: `redis-cli info memory`
2. Database connections: `SELECT count(*) FROM pg_stat_activity`
3. Slow queries: `SELECT * FROM pg_stat_statements ORDER BY mean_time DESC`
4. Sidekiq queue depth: `Sidekiq::Stats.new.queues`

**Actions:**
1. Clear Redis cache if memory high
2. Analyze tables if queries slow
3. Scale workers if queue backing up
4. Add indexes if specific queries slow

### Data Integrity Checks

```bash
# Weekly integrity check script
rails runner "
  # 1. Verify trial balance
  tb = TrialBalanceQuery.generate
  raise 'Trial balance unbalanced!' unless tb[:balanced]
  
  # 2. Verify all transactions balanced
  unbalanced = Transaction.posted.select { |t| !t.balanced? }
  raise \"Unbalanced transactions: \#{unbalanced.map(&:id)}\" if unbalanced.any?
  
  # 3. Verify no orphaned entries
  orphans = Entry.left_joins(:transaction).where(transactions: { id: nil })
  raise \"Orphaned entries: \#{orphans.count}\" if orphans.any?
  
  puts 'All integrity checks passed!'
"
```

## Scaling Considerations

### Horizontal Scaling

- **Read replicas** for reporting queries
- **Load balancer** for multiple app servers
- **Redis cluster** for high availability
- **Partition by currency** if multi-region

### Vertical Scaling

- PostgreSQL: 8GB+ RAM, SSD storage
- Redis: 4GB+ RAM
- Application: 2GB+ RAM per worker

### Caching Strategy

- **L1:** Redis (5ms)
- **L2:** Denormalized columns (10ms)
- **L3:** Calculated (50-500ms)

## Contact

For production support: [your-email@domain.com]
