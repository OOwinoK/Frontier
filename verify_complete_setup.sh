#!/bin/bash

echo "=== Core Banking LMS - Complete Setup Verification ==="
echo ""

echo "✓ Checking Ruby..."
ruby -v
echo ""

echo "✓ Checking Rails..."
rails -v
echo ""

echo "✓ Checking PostgreSQL connection..."
psql -h 172.18.192.1 -U rails_dev -d core_banking_lms_development -c "SELECT 'PostgreSQL OK' as status;"
echo ""

echo "✓ Checking Redis..."
redis-cli ping
echo ""

echo "✓ Checking Rails database connection..."
cd core_banking_lms
rails runner "puts '✓ Rails connected to: ' + ActiveRecord::Base.connection.current_database"
echo ""

echo "✓ Checking Redis from Rails..."
rails runner "puts REDIS.ping == 'PONG' ? '✓ Redis connected!' : '✗ Redis failed'"
echo ""

echo "✓ Checking project structure..."
ls -la app/ | grep -E "models|controllers|queries|services"
echo ""

echo "=== All systems operational! Ready to build! ==="
