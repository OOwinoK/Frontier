# 🚀 Core Banking Loan Management Service (LMS)

[cite_start]This repository contains a production-grade **double-entry accounting system** designed for high-volume fintech operations[cite: 6, 7]. [cite_start]It serves as the core ledger for a digital lending platform, handling everything from mobile money disbursements to real-time regulatory reporting[cite: 9, 11, 12].

---

## 🏛 Business Context
The system is engineered to meet the demands of modern digital lending:
* [cite_start]**High Volume**: Capable of processing thousands of transactions per day[cite: 14].
* [cite_start]**Multi-Lender Support**: Manages funds pooled from multiple lenders[cite: 11].
* [cite_start]**Mobile Integration**: Designed for disbursements via M-Pesa and other mobile money platforms[cite: 11].
* [cite_start]**Compliance Ready**: Built to satisfy strict banking regulations and audit requirements[cite: 13].

---

## ⚖️ Core Accounting Logic
[cite_start]The ledger is built on the fundamental principles of double-entry bookkeeping[cite: 30]:
* [cite_start]**The Golden Rule**: Total Debits must always equal Total Credits for every transaction[cite: 34].
* **Balance Behavior**:
    * [cite_start]**Debits** increase **ASSET** and **EXPENSE** accounts[cite: 32].
    * [cite_start]**Credits** increase **LIABILITY**, **EQUITY**, and **INCOME** accounts[cite: 33].

---

## ✨ Key Features

### 1. Account Management
* [cite_start]**Chart of Accounts**: Supports ASSET, LIABILITY, EQUITY, INCOME, and EXPENSE[cite: 18, 19, 20, 21].
* [cite_start]**Hierarchies**: Implements parent-child relationships (e.g., Assets → Cash → M-Pesa)[cite: 25, 26].
* [cite_start]**Multi-Currency**: Native support for **KES, UGX, and USD**[cite: 24].
* [cite_start]**Data Integrity**: Prevents the deletion of any account that has transaction history[cite: 28].

### 2. Transaction Engine
* [cite_start]**Idempotency**: Prevents duplicate disbursements by returning the original transaction for repeated `idempotency_key` requests[cite: 55, 56, 57].
* [cite_start]**Concurrency Control**: Uses **Optimistic Locking** (version numbers) to prevent race conditions during simultaneous updates[cite: 61, 62].
* [cite_start]**Auditability**: Supports transaction reversals with offsetting entries and maintains a permanent audit trail[cite: 58, 59, 60].

### 3. Loan Lifecycle Workflows
* [cite_start]**Disbursement**: Automatically records Loan Receivables and associated Fee Income[cite: 65, 68, 73].
* [cite_start]**Repayment**: Correctly splits incoming cash between Principal and Interest Income[cite: 74, 76, 80, 81].
* [cite_start]**Default/Write-off**: Recognizes Bad Debt Expenses when loans are unrecoverable[cite: 83, 84, 86, 88].

---

## 📊 Reporting & Analytics
[cite_start]The system provides high-performance queries (< 50ms) for critical financial reports[cite: 91, 97]:
* [cite_start]**Trial Balance**: Aggregates all debit and credit balances by account type to ensure audit integrity[cite: 102, 103, 104, 105].
* [cite_start]**Balance Sheet**: A real-time snapshot of financial position where **Assets = Liabilities + Equity**[cite: 106, 107, 108].
* [cite_start]**Loan Aging**: Categorizes the loan book into buckets (Current, 30-59, 60-89, 90+ days overdue)[cite: 109, 111, 112, 113, 114, 115].

---

## 🚀 Getting Started

1. **Install Dependencies**:
   ```bash
   bundle install
   bin/rails db:prepare