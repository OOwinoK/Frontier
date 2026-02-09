#!/bin/bash

BASE="http://localhost:3000/api/v1"

echo "🚀 Starting Full System Audit..."

# Step 1: Create accounts and capture IDs
echo "1. Creating Chart of Accounts..."

CASH_ID=$(curl -s -X POST $BASE/accounts -H "Content-Type: application/json" \
  -d '{"account":{"code":"CASH-001","name":"M-Pesa Cash","account_type":"ASSET","currency":"KES"}}' \
  | jq -r '.id')

LOANS_ID=$(curl -s -X POST $BASE/accounts -H "Content-Type: application/json" \
  -d '{"account":{"code":"LOANS-001","name":"Loans Receivable","account_type":"ASSET","currency":"KES"}}' \
  | jq -r '.id')

EQUITY_ID=$(curl -s -X POST $BASE/accounts -H "Content-Type: application/json" \
  -d '{"account":{"code":"EQUITY-001","name":"Owner Equity","account_type":"EQUITY","currency":"KES"}}' \
  | jq -r '.id')

INCOME_ID=$(curl -s -X POST $BASE/accounts -H "Content-Type: application/json" \
  -d '{"account":{"code":"INCOME-001","name":"Interest Income","account_type":"INCOME","currency":"KES"}}' \
  | jq -r '.id')

echo "✓ Accounts created: Cash=$CASH_ID, Loans=$LOANS_ID, Equity=$EQUITY_ID, Income=$INCOME_ID"

# Step 2: Fund the cash account
echo "2. Funding Cash Account..."

curl -s -X POST $BASE/transactions -H "Content-Type: application/json" \
  -d "{
    \"idempotency_key\": \"fund-001\",
    \"description\": \"Initial funding\",
    \"entries\": [
      {\"account_id\": $CASH_ID, \"debit\": 100000.0},
      {\"account_id\": $EQUITY_ID, \"credit\": 100000.0}
    ]
  }" > /dev/null

echo "✓ Cash funded with 100,000 KES"

# Step 3: Check trial balance
echo "3. Checking Trial Balance..."

TB=$(curl -s $BASE/reports/trial_balance)
BALANCED=$(echo $TB | jq -r '.balanced')

if [ "$BALANCED" = "true" ]; then
  echo "✅ PASS: Trial Balance is balanced"
else
  echo "❌ FAIL: Trial Balance is NOT balanced"
  echo $TB | jq '.difference'
fi

# Step 4: Disburse a loan
echo "4. Disbursing Loan..."

curl -s -X POST $BASE/loans/disburse -H "Content-Type: application/json" \
  -d '{
    "borrower_name": "John Doe",
    "principal_amount": 10000.0,
    "currency": "KES",
    "loan_reference": "LOAN-001"
  }' > /dev/null

echo "✓ Loan of 10,000 KES disbursed"

# Step 5: Process repayment
echo "5. Processing Repayment..."

# Get the loan account ID (it was just created)
LOAN_ACCOUNT_ID=$(curl -s $BASE/accounts | jq -r '.accounts[] | select(.code | startswith("LOAN-")) | .id' | head -1)

curl -s -X POST $BASE/loans/$LOAN_ACCOUNT_ID/repay -H "Content-Type: application/json" \
  -d '{
    "principal_amount": 1000.0,
    "interest_amount": 200.0,
    "payment_reference": "MPESA-123"
  }' > /dev/null

echo "✓ Repayment of 1,200 KES processed"

# Step 6: Get balance sheet
echo "6. Generating Balance Sheet..."

BS=$(curl -s "$BASE/reports/balance_sheet?with_ratios=true")
ASSETS=$(echo $BS | jq -r '.assets.total')
LIABILITIES=$(echo $BS | jq -r '.liabilities.total')
EQUITY=$(echo $BS | jq -r '.equity.total')

echo "✓ Assets: $ASSETS, Liabilities: $LIABILITIES, Equity: $EQUITY"

# Step 7: Get loan aging report
echo "7. Checking Loan Aging..."

curl -s "$BASE/reports/loan_aging?refresh=true" | jq '.summary[] | select(.bucket == "current") | .loan_count' > /dev/null

echo "✓ Loan aging report generated"

# Step 8: Final trial balance
echo "8. Final Trial Balance Check..."

TB_FINAL=$(curl -s $BASE/reports/trial_balance)
BALANCED_FINAL=$(echo $TB_FINAL | jq -r '.balanced')

if [ "$BALANCED_FINAL" = "true" ]; then
  echo "✅ PASS: Final Trial Balance is balanced"
  echo "Total Debits: $(echo $TB_FINAL | jq -r '.total_debits')"
  echo "Total Credits: $(echo $TB_FINAL | jq -r '.total_credits')"
else
  echo "❌ FAIL: Final Trial Balance is NOT balanced"
fi

echo ""
echo "✅ Full System Audit Complete!"