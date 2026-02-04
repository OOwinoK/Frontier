# Core Banking Loan Management System (LMS/MIS)

Production-grade double-entry accounting system for loan operations.

## Features
- Double-entry bookkeeping
- Multi-currency support (KES, UGX, USD)
- Redis caching for <50ms balance queries
- Idempotent transactions
- PostgreSQL table partitioning
- Comprehensive financial reports

## Tech Stack
- Ruby 3.2.2
- Rails 7.1.2
- PostgreSQL (Windows host)
- Redis (WSL)
- Sidekiq

## Setup
```bash
# Start Redis
sudo service redis-server start

# Install dependencies
bundle install

# Run migrations (coming soon)
rails db:migrate

# Start server
rails server
```

## Architecture
- PostgreSQL: 172.18.192.1:5432
- Redis: localhost:6379
- Rails API: localhost:3000