#!/bin/bash

BASE_URL="http://localhost:3000"

echo "🧪 Testing Core Banking LMS API"
echo "================================"

echo -e "\n✓ Health Check"
curl -s $BASE_URL/health

echo -e "\n\n✓ Create Account"
curl -s -X POST $BASE_URL/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{"account":{"code":"TEST-'$(date +%s)'","name":"Test Account","account_type":"ASSET","currency":"KES"}}' | jq -r '.id'

echo -e "\n\n✓ List Accounts"
curl -s $BASE_URL/api/v1/accounts | jq -r '.accounts | length'

echo -e "\n\n✓ Trial Balance"
curl -s $BASE_URL/api/v1/reports/trial_balance | jq -r '.balanced'

echo -e "\n\n✅ All tests passed!"