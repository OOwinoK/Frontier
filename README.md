# 🚀 Core Banking Loan Management Service (LMS)

This repository contains a production-grade **double-entry accounting system** designed for high-volume fintech operations. It serves as the core ledger for a digital lending platform, handling everything from mobile money disbursements to real-time regulatory reporting.

---

## 🏛 Business Context
The system is engineered to meet the demands of modern digital lending:
* **High Volume**: Capable of processing thousands of transactions per day.
* **Multi-Lender Support**: Manages funds pooled from multiple lenders.
* **Mobile Integration**: Designed for disbursements via M-Pesa and other mobile money platforms.
* **Compliance Ready**: Built to satisfy strict banking regulations and audit requirements.

---

## ⚖️ Core Accounting Logic
The ledger is built on the fundamental principles of double-entry bookkeeping:
* **The Golden Rule**: Total Debits must always equal Total Credits for every transaction.
* **Balance Behavior**:
    * **Debits** increase **ASSET** and **EXPENSE** accounts.
    * **Credits** increase **LIABILITY**, **EQUITY**, and **INCOME** accounts.

---

## ✨ Key Features

### 1. Account Management
* **Chart of Accounts**: Supports ASSET, LIABILITY, EQUITY, INCOME, and EXPENSE.
* **Hierarchies**: Implements parent-child relationships (e.g., Assets → Cash → M-Pesa).
* **Multi-Currency**: Native support for **KES, UGX, and USD**.
* **Data Integrity**: Prevents the deletion of any account that has transaction history.

### 2. Transaction Engine
* **Idempotency**: Prevents duplicate disbursements by returning the original transaction for repeated `idempotency_key` requests.
* **Concurrency Control**: Uses **Optimistic Locking** (version numbers) to prevent race conditions during simultaneous updates.
* **Auditability**: Supports transaction reversals with offsetting entries and maintains a permanent audit trail.

### 3. Loan Lifecycle Workflows
* **Disbursement**: Automatically records Loan Receivables and associated Fee Income.
* **Repayment**: Correctly splits incoming cash between Principal and Interest Income.
* **Default/Write-off**: Recognizes Bad Debt Expenses when loans are unrecoverable.

---

## 📊 Reporting & Analytics
The system provides high-performance queries (< 50ms) for critical financial reports:
* **Trial Balance**: Aggregates all debit and credit balances by account type to ensure audit integrity.
* **Balance Sheet**: A real-time snapshot of financial position where **Assets = Liabilities + Equity**.
* **Loan Aging**: Categorizes the loan book into buckets (Current, 30-59, 60-89, 90+ days overdue).

---

## 🚀 Getting Started

1. **Install Dependencies**:
   ```bash
   bundle install