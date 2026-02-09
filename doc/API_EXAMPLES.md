# API Usage Examples

Complete examples for all API endpoints with curl commands and expected responses.

## Table of Contents
- [Setup](#setup)
- [Accounts](#accounts)
- [Transactions](#transactions)
- [Loans](#loans)
- [Reports](#reports)

## Setup

Base URL: `http://localhost:3000/api/v1`

All requests return JSON.

## Accounts

### Create an Account

```bash
curl -X POST http://localhost:3000/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "account": {
      "code": "CASH-001",
      "name": "Main Cash Account",
      "account_type": "ASSET",
      "currency": "KES",
      "description": "Primary cash account for operations"
    }
  }'
```

**Response (201 Created):**
```json
{
  "id": 1,
  "code": "CASH-001",
  "name": "Main Cash Account",
  "account_type": "ASSET",
  "currency": "KES",
  "current_balance": 0.0,
  "active": true,
  "description": "Primary cash account for operations",
  "total_entries_count": 0,
  "balance_updated_at": null
}
```

### List All Accounts

```bash
# All accounts
curl http://localhost:3000/api/v1/accounts

# Filter by type
curl http://localhost:3000/api/v1/accounts?account_type=ASSET

# Filter by currency
curl http://localhost:3000/api/v1/accounts?currency=KES

# Pagination
curl http://localhost:3000/api/v1/accounts?page=2&per_page=20
```

### Get Account Balance

```bash
# Current balance
curl http://localhost:3000/api/v1/accounts/1/balance

# Historical balance
curl http://localhost:3000/api/v1/accounts/1/balance?as_of=2026-01-15
```

**Response:**
```json
{
  "account_id": 1,
  "account_code": "CASH-001",
  "account_name": "Main Cash Account",
  "account_type": "ASSET",
  "currency": "KES",
  "balance": 50000.0,
  "as_of": "2026-02-08T10:30:00Z"
}
```

### Get Account Transaction History

```bash
curl http://localhost:3000/api/v1/accounts/1/history?page=1&per_page=50
```

**Response:**
```json
{
  "account_id": 1,
  "account_name": "Main Cash Account",
  "current_balance": 50000.0,
  "page": 1,
  "per_page": 50,
  "total_count": 125,
  "total_pages": 3,
  "transactions": [
    {
      "id": 1,
      "date": "2026-02-08T09:15:00Z",
      "description": "Loan disbursement",
      "debit": 10000.0,
      "credit": null,
      "balance": 50000.0,
      "status": "posted"
    }
  ]
}
```

## Transactions

### Create a Transaction

```bash
curl -X POST http://localhost:3000/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "idempotency_key": "txn-2026-02-08-001",
    "description": "Loan disbursement to John Doe",
    "entries": [
      {
        "account_id": 5,
        "debit": 10000.0000,
        "description": "Loan receivable"
      },
      {
        "account_id": 1,
        "credit": 10000.0000,
        "description": "Cash disbursed"
      }
    ],
    "metadata": {
      "loan_id": "LOAN-001",
      "borrower_id": "BOR-123"
    }
  }'
```

**Response (201 Created):**
```json
{
  "id": 15,
  "idempotency_key": "txn-2026-02-08-001",
  "description": "Loan disbursement to John Doe",
  "posted_at": "2026-02-08T10:30:00Z",
  "status": "posted",
  "total_debits": 10000.0,
  "total_credits": 10000.0,
  "balanced": true,
  "entries": [
    {
      "id": 30,
      "account_id": 5,
      "account_code": "LOAN-001",
      "account_name": "Loan Receivable - John Doe",
      "debit": 10000.0,
      "credit": null,
      "description": "Loan receivable"
    },
    {
      "id": 31,
      "account_id": 1,
      "account_code": "CASH-001",
      "account_name": "Main Cash Account",
      "debit": null,
      "credit": 10000.0,
      "description": "Cash disbursed"
    }
  ],
  "metadata": {
    "loan_id": "LOAN-001",
    "borrower_id": "BOR-123"
  }
}
```

### Void a Transaction

```bash
curl -X POST http://localhost:3000/api/v1/transactions/15/void
```

**Response:**
```json
{
  "original_transaction": {
    "id": 15,
    "status": "voided"
  },
  "reversal_transaction": {
    "id": 16,
    "idempotency_key": "txn-2026-02-08-001-void",
    "description": "VOID: Loan disbursement to John Doe",
    "status": "posted"
  },
  "message": "Transaction voided successfully"
}
```

### Search Transactions

```bash
curl http://localhost:3000/api/v1/transactions/search?q=loan
```

## Loans

### Disburse a Loan

```bash
curl -X POST http://localhost:3000/api/v1/loans/disburse \
  -H "Content-Type: application/json" \
  -d '{
    "borrower_name": "John Doe",
    "principal_amount": 10000.00,
    "origination_fee": 500.00,
    "currency": "KES",
    "loan_reference": "LOAN-2026-001",
    "metadata": {
      "borrower_id": "BOR-123",
      "loan_term_days": 90,
      "interest_rate": 15.0
    }
  }'
```

**Response (201 Created):**
```json
{
  "loan_account": {
    "id": 25,
    "code": "LOAN-LOAN-2026-001",
    "name": "Loan Receivable - John Doe",
    "currency": "KES",
    "current_balance": 10000.0,
    "active": true
  },
  "transaction": {
    "id": 20,
    "idempotency_key": "disbursement-LOAN-2026-001",
    "description": "Loan disbursement to Loan Receivable - John Doe",
    "posted_at": "2026-02-08T10:45:00Z",
    "status": "posted"
  },
  "net_disbursement": 9500.0
}
```

### Process Loan Repayment

```bash
curl -X POST http://localhost:3000/api/v1/loans/25/repay \
  -H "Content-Type: application/json" \
  -d '{
    "principal_amount": 1000.00,
    "interest_amount": 150.00,
    "fee_amount": 50.00,
    "payment_reference": "MPESA-XYZ789ABC",
    "metadata": {
      "payment_method": "M-Pesa",
      "phone_number": "+254712345678"
    }
  }'
```

**Response:**
```json
{
  "transaction": {
    "id": 21,
    "idempotency_key": "repayment-MPESA-XYZ789ABC",
    "description": "Loan repayment for Loan Receivable - John Doe",
    "posted_at": "2026-02-08T11:00:00Z",
    "status": "posted"
  },
  "total_amount": 1200.0,
  "remaining_balance": 9000.0
}
```

### Write Off a Loan

```bash
curl -X POST http://localhost:3000/api/v1/loans/25/writeoff \
  -H "Content-Type: application/json" \
  -d '{
    "writeoff_amount": 5000.00,
    "reason": "Borrower uncontactable for 6 months",
    "reference": "WRITEOFF-2026-001",
    "metadata": {
      "approval_by": "credit_manager_001"
    }
  }'
```

**Response:**
```json
{
  "transaction": {
    "id": 22,
    "idempotency_key": "writeoff-WRITEOFF-2026-001",
    "description": "Loan write-off: Borrower uncontactable for 6 months",
    "status": "posted"
  },
  "writeoff_amount": 5000.0,
  "remaining_balance": 4000.0
}
```

### Get Loan Details

```bash
curl http://localhost:3000/api/v1/loans/25
```

**Response:**
```json
{
  "loan_account": {
    "id": 25,
    "code": "LOAN-LOAN-2026-001",
    "name": "Loan Receivable - John Doe",
    "currency": "KES",
    "current_balance": 9000.0,
    "active": true
  },
  "balance": {
    "account_id": 25,
    "balance": 9000.0,
    "as_of": "2026-02-08T11:15:00Z"
  },
  "recent_transactions": {
    "transactions": [...]
  }
}
```

## Reports

### Trial Balance

```bash
# Current trial balance
curl http://localhost:3000/api/v1/reports/trial_balance

# Historical trial balance
curl http://localhost:3000/api/v1/reports/trial_balance?as_of=2026-01-31

# Filter by currency
curl http://localhost:3000/api/v1/reports/trial_balance?currency=KES
```

**Response:**
```json
{
  "as_of": "2026-02-08",
  "currency": "KES",
  "accounts_by_type": [
    {
      "account_type": "ASSET",
      "accounts": [
        {
          "account_id": 1,
          "account_code": "CASH-001",
          "account_name": "Main Cash Account",
          "debit": 50000.0,
          "credit": 0.0
        }
      ],
      "total_debit": 150000.0,
      "total_credit": 0.0
    },
    {
      "account_type": "LIABILITY",
      "total_debit": 0.0,
      "total_credit": 100000.0
    },
    {
      "account_type": "EQUITY",
      "total_debit": 0.0,
      "total_credit": 50000.0
    }
  ],
  "total_debits": 150000.0,
  "total_credits": 150000.0,
  "difference": 0.0,
  "balanced": true,
  "generated_at": "2026-02-08T11:20:00Z"
}
```

### Balance Sheet

```bash
# Current balance sheet
curl http://localhost:3000/api/v1/reports/balance_sheet

# With financial ratios
curl http://localhost:3000/api/v1/reports/balance_sheet?with_ratios=true

# Historical
curl http://localhost:3000/api/v1/reports/balance_sheet?as_of=2026-01-31
```

**Response:**
```json
{
  "as_of": "2026-02-08",
  "currency": "KES",
  "assets": {
    "total": 250000.0,
    "accounts": [...]
  },
  "liabilities": {
    "total": 150000.0,
    "accounts": [...]
  },
  "equity": {
    "total": 100000.0,
    "accounts": [...]
  },
  "total_assets": 250000.0,
  "total_liabilities": 150000.0,
  "total_equity": 100000.0,
  "total_liabilities_and_equity": 250000.0,
  "balanced": true,
  "ratios": {
    "debt_to_equity_ratio": 1.5,
    "equity_ratio": 40.0,
    "debt_ratio": 60.0,
    "current_ratio": 1.2
  },
  "generated_at": "2026-02-08T11:25:00Z"
}
```

### Loan Aging Report

```bash
# Get full report
curl http://localhost:3000/api/v1/reports/loan_aging

# Refresh materialized view first
curl http://localhost:3000/api/v1/reports/loan_aging?refresh=true

# Summary only
curl http://localhost:3000/api/v1/reports/loan_aging/summary

# Top overdue loans
curl http://localhost:3000/api/v1/reports/loan_aging/top_overdue?limit=20
```

**Response:**
```json
{
  "generated_at": "2026-02-08T11:30:00Z",
  "currency": "KES",
  "summary": [
    {
      "bucket": "current",
      "label": "Current (0-29 days)",
      "loan_count": 150,
      "total_outstanding": 1500000.0,
      "avg_loan_size": 10000.0,
      "percentage": 75.0
    },
    {
      "bucket": "30_59_days",
      "label": "30-59 days overdue",
      "loan_count": 30,
      "total_outstanding": 300000.0,
      "percentage": 15.0
    },
    {
      "bucket": "60_89_days",
      "label": "60-89 days overdue",
      "loan_count": 15,
      "total_outstanding": 150000.0,
      "percentage": 7.5
    },
    {
      "bucket": "90_plus_days",
      "label": "90+ days overdue",
      "loan_count": 5,
      "total_outstanding": 50000.0,
      "percentage": 2.5
    }
  ],
  "risk_metrics": {
    "total_loans": 200,
    "total_outstanding": 2000000.0,
    "overdue_loans": 50,
    "overdue_rate": 25.0,
    "severely_overdue_rate": 10.0
  },
  "buckets": [...]
}
```

### Refresh Materialized Views

```bash
curl -X POST http://localhost:3000/api/v1/reports/refresh_views
```

**Response:**
```json
{
  "message": "Materialized views refreshed successfully",
  "refreshed_at": "2026-02-08T11:35:00Z"
}
```

## Error Responses

### 404 Not Found
```json
{
  "error": "Not Found",
  "message": "Couldn't find Account with 'id'=999"
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Unprocessable Entity",
  "message": "Transaction must balance. Debits: 1000.0, Credits: 500.0"
}
```

### 400 Bad Request
```json
{
  "error": "Bad Request",
  "message": "Invalid date format"
}
```

## Rate Limiting

Currently no rate limiting implemented. Consider adding for production.

## Authentication

Currently no authentication. Add JWT or OAuth2 for production deployment.
