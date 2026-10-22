# AIWIZE Labs Loan Management System - Database Audit & Gap Analysis

**Audit Date:** October 22, 2026  
**Audited Database:** PostgreSQL (`loan_management` / public schema)  
**Reference Document:** AIWIZE Labs 7-Day SQL + UI/UX Guidance (`AIWIZE_Fresher_7_Day_SQL_UIUX_Guidence.pdf`)  
**Scope:** Schema verification, referential integrity, constraints, indexes, sample profiling, and readiness across 7-day SQL + UI/UX requirements.

---

## 1. Executive Summary

A comprehensive inspection of the existing PostgreSQL database for the AIWIZE Labs Loan Management System was conducted via direct database introspection without altering any schema, tables, or records.

All **10 database tables** (9 core lending domain tables + 1 recent migration extension table) are present in the public schema. The foundational entity relationships (`customers -> loan_applications -> loans -> emi_schedule / payments / disbursements`) and supporting organizational entities (`branches`, `employees`, `credit_policies`, `customer_employment`) are functional and maintain zero referential integrity violations.

However, several critical gaps exist when measured against the **AIWIZE Labs 7-Day SQL Practice & Assessment Plan (65% SQL / 35% UI/UX)**:
1. **Schema & Domain Attributes:** The mandatory Indian lending identity attribute `PAN` (Permanent Account Number), explicitly featured in Slide 7 of the preparation guide (`ABCDE1234F`), is completely missing from both `customers` and `loan_applications`. Furthermore, `credit_score` is missing from `customers` and `loan_applications`, making rule-based credit policy evaluation against `credit_policies.min_credit_score` impossible.
2. **Amortization Truncation:** While loans have tenures of 36 and 48 months, only 3 and 2 installments exist in `emi_schedule` respectively (Loan 1 is missing 33 installments; Loan 2 is missing 46 installments). Only 1 payment record exists in `payments`. Consequently, Level 3 SQL scenarios such as "running balances" and cumulative loan payoff tracking cannot be fully computed or tested.
3. **Data Cardinality & Edge Cases:** Every customer in the database has exactly 1 application, preventing proper testing of the Slide 6 Level 2 requirement ("latest application per customer"). There are 0 duplicate records, 0 closed loans, 0 defaulted loans, and no overdue status updates (Installment #4 is past due date by 6 days but marked 'Pending').
4. **Performance & Optimization:** 6 foreign key columns lack indexes, and high-frequency search/filter columns (`status`, `application_date`, `due_date`) are unindexed.

---

## 2. PostgreSQL Schema & Inventory Inspection

### 2.1 Complete Table & Column Inventory

| Table Name | Column Name | Data Type | Nullable | Identity / Default | Constraints & Keys |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **branches** | `branch_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`branches_pkey`) |
| | `branch_name` | character varying | NO | - | - |
| | `city` | character varying | NO | - | - |
| | `ifsc_code` | character varying | NO | - | **UNIQUE** (`branches_ifsc_code_key`) |
| **credit_policies** | `policy_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`credit_policies_pkey`) |
| | `policy_name` | character varying | NO | - | - |
| | `min_credit_score` | integer | NO | - | `CHECK (min_credit_score BETWEEN 300 AND 900)` |
| | `annual_interest_rate` | numeric | NO | - | `CHECK (annual_interest_rate > 0 AND <= 100)` |
| | `max_loan_amount` | numeric | NO | - | `CHECK (max_loan_amount > 0)` |
| **employees** | `employee_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`employees_pkey`) |
| | `branch_id` | integer | NO | - | **FK** -> `branches(branch_id)` |
| | `full_name` | character varying | NO | - | - |
| | `job_title` | character varying | NO | - | - |
| **customers** | `customer_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`customers_pkey`) |
| | `full_name` | character varying | NO | - | - |
| | `email` | character varying | YES | - | **UNIQUE** (`customers_email_key`) |
| | `phone` | character varying | YES | - | - |
| | `date_of_birth` | date | YES | - | - |
| | `created_at` | timestamp without time zone | YES | `CURRENT_TIMESTAMP` | - |
| | `residential_address`| text | YES | - | Added via Migration 001 |
| **customer_employment**| `employment_id` | integer | NO | `nextval(seq)` (SERIAL) | **PK** (`customer_employment_pkey`) |
| | `customer_id` | integer | NO | - | **FK** -> `customers(customer_id) ON DELETE RESTRICT`, **UNIQUE** |
| | `employment_type` | character varying | NO | - | `CHECK (employment_type IN ('Salaried', 'Self-employed', 'Student', 'Unemployed'))` |
| | `employer_name` | character varying | YES | - | - |
| | `monthly_income` | numeric(15,2) | NO | - | `CHECK (monthly_income >= 0)` |
| | `years_of_experience` | integer | YES | - | `CHECK (years_of_experience >= 0)` |
| | `created_at` | timestamptz | YES | `CURRENT_TIMESTAMP` | - |
| | `updated_at` | timestamptz | YES | `CURRENT_TIMESTAMP` | - |
| **loan_applications** | `application_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`loan_applications_pkey`) |
| | `customer_id` | integer | NO | - | **FK** -> `customers(customer_id)` |
| | `branch_id` | integer | NO | - | **FK** -> `branches(branch_id)` |
| | `employee_id` | integer | YES | - | **FK** -> `employees(employee_id)` |
| | `policy_id` | integer | YES | - | **FK** -> `credit_policies(policy_id)` |
| | `application_date` | date | NO | `CURRENT_DATE` | - |
| | `requested_amount` | numeric | NO | - | `CHECK (requested_amount > 0)` |
| | `status` | character varying | NO | `'Pending'` | `CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Disbursed'))` |
| | `loan_type` | character varying(50)| YES | - | `CHECK (loan_type IN ('Personal', 'Home', 'Education', 'Vehicle', 'Business'))` |
| | `requested_tenure_months`| integer | YES | - | `CHECK (requested_tenure_months > 0)` |
| | `loan_purpose` | text | YES | - | - |
| | `existing_monthly_emi` | numeric(15,2) | YES | `0` | `CHECK (existing_monthly_emi >= 0)` |
| **loans** | `loan_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`loans_pkey`) |
| | `application_id` | integer | NO | - | **FK** -> `loan_applications(application_id)`, **UNIQUE** |
| | `customer_id` | integer | NO | - | **FK** -> `customers(customer_id)` |
| | `principal_amount` | numeric | NO | - | `CHECK (principal_amount > 0)` |
| | `annual_interest_rate` | numeric | NO | - | `CHECK (annual_interest_rate > 0 AND <= 100)` |
| | `tenure_months` | integer | NO | - | `CHECK (tenure_months > 0)` |
| | `loan_date` | date | NO | `CURRENT_DATE` | - |
| | `status` | character varying | NO | `'Active'` | `CHECK (status IN ('Active', 'Closed', 'Defaulted'))` |
| **emi_schedule** | `emi_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`emi_schedule_pkey`) |
| | `loan_id` | integer | NO | - | **FK** -> `loans(loan_id)` |
| | `installment_number` | integer | NO | - | `CHECK (installment_number > 0)` |
| | `due_date` | date | NO | - | - |
| | `emi_amount` | numeric | NO | - | `CHECK (emi_amount > 0)` |
| | `principal_component`| numeric | NO | - | `CHECK (principal_component >= 0)` |
| | `interest_component` | numeric | NO | - | `CHECK (interest_component >= 0)` |
| | `status` | character varying | NO | `'Pending'` | `CHECK (status IN ('Pending', 'Partially Paid', 'Paid', 'Overdue'))` |
| | *(Composite Key)* | `(loan_id, installment_number)` | NO | - | **UNIQUE** (`emi_schedule_loan_id_installment_number_key`) |
| **payments** | `payment_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`payments_pkey`) |
| | `emi_id` | integer | NO | - | **FK** -> `emi_schedule(emi_id)` |
| | `payment_date` | date | NO | `CURRENT_DATE` | - |
| | `amount` | numeric | NO | - | `CHECK (amount > 0)` |
| | `payment_method` | character varying | NO | - | - |
| | `transaction_reference`| character varying | YES | - | **UNIQUE** (`payments_transaction_reference_key`) |
| **disbursements** | `disbursement_id` | integer | NO | `ALWAYS AS IDENTITY` | **PK** (`disbursements_pkey`) |
| | `loan_id` | integer | NO | - | **FK** -> `loans(loan_id)`, **UNIQUE** (`disbursements_loan_id_key`) |
| | `disbursement_date` | date | NO | `CURRENT_DATE` | - |
| | `amount` | numeric | NO | - | `CHECK (amount > 0)` |
| | `transaction_reference`| character varying | YES | - | **UNIQUE** (`disbursements_transaction_reference_key`) |

---

### 2.2 Foreign Key Referential Integrity & Delete Action Audit

Referential integrity was audited via SQL cross-table joins. All 11 foreign keys currently reference valid parent records (0 orphaned records detected):

| Foreign Key Constraint | Source Column | Target Column | On Delete Rule | Index Status |
| :--- | :--- | :--- | :--- | :--- |
| `employees -> branches` | `employees.branch_id` | `branches.branch_id` | `NO ACTION` | **MISSING** |
| `loan_applications -> customers` | `loan_applications.customer_id` | `customers.customer_id` | `NO ACTION` | Covered (`idx_loan_apps_customer`) |
| `loan_applications -> branches` | `loan_applications.branch_id` | `branches.branch_id` | `NO ACTION` | **MISSING** |
| `loan_applications -> employees` | `loan_applications.employee_id` | `employees.employee_id` | `NO ACTION` | **MISSING** |
| `loan_applications -> credit_policies` | `loan_applications.policy_id` | `credit_policies.policy_id` | `NO ACTION` | **MISSING** |
| `loans -> loan_applications` | `loans.application_id` | `loan_applications.application_id` | `NO ACTION` | Covered (`loans_application_id_key`) |
| `loans -> customers` | `loans.customer_id` | `customers.customer_id` | `NO ACTION` | **MISSING** |
| `customer_employment -> customers` | `customer_employment.customer_id` | `customers.customer_id` | `RESTRICT` | Covered (`customer_employment_customer_id_key`) |
| `disbursements -> loans` | `disbursements.loan_id` | `loans.loan_id` | `NO ACTION` | Covered (`disbursements_loan_id_key`) |
| `emi_schedule -> loans` | `emi_schedule.loan_id` | `loans.loan_id` | `NO ACTION` | Covered (`emi_schedule_loan_id_installment_number_key`) |
| `payments -> emi_schedule` | `payments.emi_id` | `emi_schedule.emi_id` | `NO ACTION` | **MISSING** |

---

### 2.3 Index Inventory & Query Optimization Audit

In accordance with Slide 6 Level 3 requirements (*"query optimization and indexes"*), the existing database indexes were analyzed:

1. **Existing Indexes (20 total):**
   - 10 Primary Key Unique B-Trees (`*_pkey` on all 10 tables)
   - 7 Unique Business Constraint B-Trees (`branches.ifsc_code`, `customers.email`, `loans.application_id`, `disbursements.loan_id`, `disbursements.transaction_reference`, `payments.transaction_reference`, `emi_schedule(loan_id, installment_number)`)
   - 1 Unique 1:1 Index: `customer_employment.customer_id`
   - 2 Explicit Performance B-Trees: `idx_employment_customer` (on `customer_employment.customer_id`), `idx_loan_apps_customer` (on `loan_applications.customer_id`).

2. **Identified Index Deficiencies:**
   - **Redundant Index:** Column `customer_employment.customer_id` has both a UNIQUE constraint index (`customer_employment_customer_id_key`) and an explicit B-tree index (`idx_employment_customer`). The second index is redundant and incurs write overhead.
   - **Missing Foreign Key Indexes:** 6 foreign keys are unindexed. In PostgreSQL, missing indexes on foreign key columns can cause table-level locks during parent deletions and slow down table joins (`JOIN loan_applications la ON b.branch_id = la.branch_id`).
   - **Missing Filter Indexes:** Slide 6 Level 1 requires filtering applications by `status` and `application_date`. No composite or individual index exists on `loan_applications(status, application_date)`. Similarly, Level 2 requires overdue calculations, but `emi_schedule(status, due_date)` is unindexed.

---

## 3. Row Counts & Sanitized Data Profile

### 3.1 Record Counts Summary

| Table | Row Count | Primary Key Range | Comments / Observations |
| :--- | :--- | :--- | :--- |
| `branches` | 2 | 1 – 2 | Central Branch (Delhi), Business Branch (Faridabad) |
| `credit_policies` | 3 | 1 – 3 | Personal (12.5%), Home (8.5%), Education (9.0%) |
| `employees` | 3 | 1 – 3 | 2 Loan Officers, 1 Branch Manager across 2 branches |
| `customers` | 8 | 1 – 8 | 5 legacy seed records + 3 regression/QA records |
| `customer_employment` | 3 | 1 – 3 | Associated only with customers 6, 7, and 8 |
| `loan_applications` | 8 | 1 – 8 | 1 application per customer exactly |
| `loans` | 2 | 1 – 2 | Derived from Applications #1 and #5 |
| `disbursements` | 2 | 1 – 2 | ₹200,000 for Loan #1; ₹300,000 for Loan #2 |
| `emi_schedule` | 5 | 1 – 5 | 3 installments for Loan #1; 2 installments for Loan #2 |
| `payments` | 1 | 1 | Single ₹6,680 UPI payment for Loan #1, Installment #1 |

---

### 3.2 Categorical Value Distribution

```
loan_applications.status:
  - Pending:    4 records (50.0%)
  - Disbursed:  2 records (25.0%)
  - Approved:   1 record  (12.5%)
  - Rejected:   1 record  (12.5%)

loans.status:
  - Active:     2 records (100.0%)
  - Closed:     0 records (0.0%)    [Missing test case]
  - Defaulted:  0 records (0.0%)    [Missing test case]

emi_schedule.status:
  - Pending:    4 records (80.0%)
  - Paid:       1 record  (20.0%)
  - Overdue:    0 records (0.0%)    [Installment #4 is past due date but flagged 'Pending']
  - Partially Paid: 0 records (0.0%)[Missing test case]

customer_employment.employment_type:
  - Salaried:       3 records (100.0%)
  - Self-employed:  0 records (0.0%) [Missing test case]
  - Student:        0 records (0.0%) [Missing test case]
  - Unemployed:     0 records (0.0%) [Missing test case]
```

---

### 3.3 Sanitized Sample Data (Secrets & PII Masked)

#### `customers` (Sample Records)
```json
[
  {
    "customer_id": 1,
    "full_name": "Aarav Sharma",
    "email": "aa***@example.com",
    "phone": "******0001",
    "date_of_birth": "1995-04-12",
    "residential_address": null
  },
  {
    "customer_id": 5,
    "full_name": "Vikram Patel",
    "email": "vi***@example.com",
    "phone": "******0005",
    "date_of_birth": "1990-06-25",
    "residential_address": null
  },
  {
    "customer_id": 8,
    "full_name": "Nishant Kumar",
    "email": "ni***@gmail.com",
    "phone": "*********7684",
    "date_of_birth": "2004-11-14",
    "residential_address": "Deepawali Enclave, Ismailpur"
  }
]
```

#### `loans` & `disbursements`
```json
[
  {
    "loan_id": 1,
    "application_id": 1,
    "customer_id": 1,
    "principal_amount": "200000.00",
    "annual_interest_rate": "12.50",
    "tenure_months": 36,
    "status": "Active",
    "disbursement": {
      "amount": "200000.00",
      "date": "2026-09-15",
      "ref": "DEMO-DISB-001"
    }
  },
  {
    "loan_id": 2,
    "application_id": 5,
    "customer_id": 5,
    "principal_amount": "300000.00",
    "annual_interest_rate": "12.50",
    "tenure_months": 48,
    "status": "Active",
    "disbursement": {
      "amount": "300000.00",
      "date": "2026-10-15",
      "ref": "DEMO-DISB-002"
    }
  }
]
```

#### `emi_schedule` & `payments`
```json
[
  {
    "emi_id": 1,
    "loan_id": 1,
    "installment_number": 1,
    "due_date": "2026-10-12",
    "emi_amount": "6680.00",
    "principal_component": "4600.00",
    "interest_component": "2080.00",
    "status": "Paid",
    "payments": [{ "amount": "6680.00", "method": "UPI", "ref": "DEMO-PAY-001" }]
  },
  {
    "emi_id": 2,
    "loan_id": 1,
    "installment_number": 2,
    "due_date": "2026-11-11",
    "emi_amount": "6680.00",
    "principal_component": "4650.00",
    "interest_component": "2030.00",
    "status": "Pending",
    "payments": []
  },
  {
    "emi_id": 4,
    "loan_id": 2,
    "installment_number": 1,
    "due_date": "2026-10-17",
    "emi_amount": "8000.00",
    "principal_component": "5000.00",
    "interest_component": "3000.00",
    "status": "Pending",
    "days_overdue": 5,
    "payments": []
  }
]
```

---

## 4. Gap Analysis: Verified Complete, Needs Testing, and Missing

### Section 4.1: Verified Complete

The following database components, constraints, and query scenarios are verified to be fully implemented, syntactically correct, and executing properly:

1. **Entity Presence (10 / 10 Tables):**
   - Core lending lifecycle entities: `customers`, `loan_applications`, `loans`, `emi_schedule`, `payments`, `disbursements`.
   - Supporting domain entities: `branches`, `employees`, `credit_policies`, `customer_employment`.
2. **Referential Integrity & Constraints:**
   - All 11 foreign keys are valid with zero orphaned records across any table.
   - Primary keys configured cleanly (9 tables use `GENERATED ALWAYS AS IDENTITY`, 1 uses `SERIAL`).
   - Domain CHECK constraints enforce:
     * Non-negative amounts on `loans`, `disbursements`, `emi_schedule`, `payments`.
     * Valid rate ranges (`annual_interest_rate` between 0 and 100).
     * Valid credit score ranges (`credit_policies.min_credit_score` between 300 and 900).
     * Valid enum sets on `loan_applications.status`, `loan_applications.loan_type`, `loans.status`, `emi_schedule.status`, `customer_employment.employment_type`.
3. **Slide 6 Level 1 Foundation Queries:**
   - **Filter applications by status and date:** Verified. Successfully filters applications (e.g., status = 'Pending' and date >= '2026-10-01' returns 4 rows).
   - **Join customers and loans:** Verified. Joining `customers` to `loans` accurately yields active borrower portfolios.
   - **Count applications by branch:** Verified. Correctly aggregates counts across branches (Central Branch: 3, Business Branch: 5).
   - **Calculate disbursed totals:** Verified. Aggregates `disbursements.amount` to exactly ₹500,000.00.
4. **Slide 6 Level 2 Query Mechanics:**
   - **CTEs and Conditional Aggregation:** Verified. Complex CTE queries computing status breakdowns (`COUNT(CASE WHEN status='Approved' THEN 1 END)`) run without issue.
   - **Window Function Syntax:** Verified. Partitioning and cumulative sums (`SUM(...) OVER (PARTITION BY loan_id ORDER BY installment_number)`) execute cleanly.

---

### Section 4.2: Needs Testing

The following items are structurally present in the database, but either contain data limitations that prevent realistic assessment or exhibit behavioral discrepancies:

1. **"Latest Application Per Customer" Query Validation:**
   - *Requirement (Slide 6 Level 2):* Trainees must write queries to extract the latest loan application per customer using CTEs, `ROW_NUMBER()`, or `DISTINCT ON`.
   - *Issue:* Currently, every single customer in the database has **exactly 1 application** (8 customers, 8 applications). Any query written by a trainee—even if flawed—will yield all 8 rows.
   - *Testing Need:* Requires customers with multiple applications (e.g., Customer A applied on September 1 and was Rejected; applied again on October 15 and is Pending) to definitively prove query correctness.
2. **Overdue EMI Status Synchronization:**
   - *Requirement (Slide 5 & 6 Level 2):* Calculate overdue amounts and identify delinquent loans.
   - *Issue:* Loan #2 installment #1 (`emi_id = 4`) had a due date of `2026-10-17`. The current database date is `2026-10-22` (5 days past due). However, its stored status in `emi_schedule.status` remains `'Pending'`.
   - *Testing Need:* Evaluate whether overdue status should be dynamically evaluated via `WHERE due_date < CURRENT_DATE AND status = 'Pending'` or maintained via a nightly batch update/trigger.
3. **Running Balance & Loan Amortization Completeness:**
   - *Requirement (Slide 6 Level 3):* Trainees must compute running principal balances and outstanding balances over time.
   - *Issue:* Loan #1 has a tenure of 36 months, but only installments 1, 2, and 3 are populated in `emi_schedule` (representing only ₹13,950 of ₹200,000 principal). Loan #2 has a tenure of 48 months, but only installments 1 and 2 are populated (representing ₹10,100 of ₹300,000 principal). 79 total installments are missing.
   - *Testing Need:* Without a full amortization schedule or at least 12–24 continuous months, running balance calculations cannot be audited against standard financial payoff schedules.
4. **Payment Ledger & Partial Payment Scenarios:**
   - *Requirement (Slide 5 & 6):* Repayment tracking and transaction integrity.
   - *Issue:* The `payments` table contains only **1 single row** (a full payment of ₹6,680 for installment #1). Loan #2 has zero payments.
   - *Testing Need:* Need test scenarios for partial payments (e.g., paying ₹3,000 on an ₹8,000 EMI), multiple payments for a single EMI, and overpayments to test ledger reconciliation queries.
5. **Referential Actions on Deletion (`ON DELETE`):**
   - *Issue:* 10 of 11 foreign keys default to `ON DELETE NO ACTION`. Only `customer_employment` explicitly specifies `ON DELETE RESTRICT`.
   - *Testing Need:* Verify that application behavior gracefully handles attempts to delete parent records (e.g., deleting a customer who has active loan applications).

---

### Section 4.3: Missing

The following entities, columns, constraints, and test scenarios are completely absent from the database:

1. **Mandatory Identity Attribute: PAN (Permanent Account Number):**
   - *Requirement (Slide 7 UI/UX Demo Screen):* The required loan application screen explicitly mandates:
     $$\text{PAN: } \mathbf{ABCDE1234F}$$
   - *Gap:* The database has **no PAN column** in either `customers` or `loan_applications`.
   - *Impact:* KYC compliance, duplicate applicant detection via PAN, and standard Indian lending workflows cannot be implemented or validated.
   - *Recommended Fix (When instructed):* Add `pan_number VARCHAR(10) CHECK (pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$')` with a UNIQUE constraint to `customers`.
2. **Credit Score in Customer / Application Schema:**
   - *Requirement (Slide 5 & Credit Policies):* The table `credit_policies` enforces `min_credit_score` (values 600, 650, 700).
   - *Gap:* Neither `customers` nor `loan_applications` stores a `credit_score`!
   - *Impact:* SQL queries cannot evaluate whether an applicant satisfies a credit policy, nor can automated underwriting rules be written.
   - *Recommended Fix:* Add `credit_score INTEGER CHECK (credit_score BETWEEN 300 AND 900)` to `customers` (or `loan_applications`).
3. **Slide 6 Level 3 Duplicate Data Test Cases:**
   - *Requirement (Slide 5 & 6 Level 3):* Slide 5 specifies data requirements must include *"duplicates"*, and Slide 6 Level 3 requires writing queries to detect and resolve duplicates.
   - *Gap:* There are currently **0 duplicate customer names, emails, phones, or applications** in the database.
   - *Impact:* Trainees cannot execute duplicate detection queries (e.g. `HAVING COUNT(*) > 1` on applicant identifiers).
4. **Multiple Loan Statuses & Employment Variety in Data:**
   - *Requirement (Slide 5):* Data requirements specify *"multiple loan statuses"* and *"realistic edge cases"*.
   - *Gap:*
     * In `loans`, 100% of rows are `Active`. There are 0 `Closed` loans and 0 `Defaulted` loans.
     * In `customer_employment`, 100% of rows are `Salaried`. There are 0 `Self-employed`, `Student`, or `Unemployed` records.
     * Customers 1 through 5 have no record in `customer_employment` and have `residential_address = NULL`.
     * Loan applications 6, 7, and 8 have `employee_id = NULL` and `policy_id = NULL`.
5. **Query Optimization Foreign Key Indexes:**
   - *Requirement (Slide 6 Level 3):* *"Query optimization and indexes"*.
   - *Gap:* 6 foreign key columns lack indexes:
     * `employees(branch_id)`
     * `loan_applications(branch_id)`
     * `loan_applications(employee_id)`
     * `loan_applications(policy_id)`
     * `loans(customer_id)`
     * `payments(emi_id)`
   - *Redundancy:* `customer_employment` contains duplicate indexes on `customer_id`.
6. **Financial Integrity Constraints:**
   - *EMI Component Integrity:* In `emi_schedule`, there is no constraint enforcing `emi_amount = principal_component + interest_component`.
   - *Payment Method Validation:* In `payments`, `payment_method` has no check constraint (e.g., `CHECK (payment_method IN ('UPI', 'NEFT', 'RTGS', 'Cheque', 'Cash', 'Debit Card'))`).
   - *Loan Amount vs Disbursement Consistency:* No check or trigger verifies that `disbursements.amount` matches `loans.principal_amount`.
   - *Multi-Tranche Disbursement Restriction:* `disbursements.loan_id` has a `UNIQUE` constraint, which prohibits multi-tranche disbursements (e.g. for construction or education loans).
7. **Business Vocabulary Fields:**
   - Slide 5 highlights business vocabulary: *"Approval, rejection, disbursement, EMI, overdue amount, repayment and outstanding principal"*.
   - *Gap:* The database has no column or view for `outstanding_principal` on `loans`, nor does `emi_schedule` support penalty/late-fee calculations.

---

## 5. Comparative Readiness Matrix (AIWIZE 7-Day Plan)

| Day / Level | Required Competency | Existing DB Readiness | Status |
| :--- | :--- | :--- | :--- |
| **Day 1: Setup** | Realistic Financial DB + Basic Form | 10 tables created, basic schema active, Express server connected | **PASS** |
| **Day 2: SQL Basics** | 15 SQL Queries (Joins, Filters, Aggregations) | Basic joins, filters, branch counts, and disbursement sums execute | **PASS** |
| **Day 3: Complexity** | CTEs, Subqueries, Conditional Aggregations | Supported syntactically; aggregations work as expected | **PASS** |
| **Day 4: Depth** | Latest app per customer, Overdue EMI math | **BLOCKED**: Customers have only 1 application; no overdue records | **NEEDS SEED DATA** |
| **Day 5: Debugging** | Broken SQL queries, edge cases, NULLs | Partially ready: NULLs exist, but 0 duplicate edge cases exist | **NEEDS SEED DATA** |
| **Day 6: Solo Practice** | Window functions, Running balance, Deduplication | **BLOCKED**: Amortization schedules truncated; 1 payment only | **NEEDS SEED DATA** |
| **Day 7: Assessment** | Timed, no-AI mock test + F2F defense | Schema lacks PAN, credit score, and foreign key indexes | **NEEDS SCHEMA UPDATE** |

---

## 6. Actionable Recommendations (Next Steps)

*Note: Per explicit prompt instructions, no files, schema, records, or application code have been modified.*

When authorized to proceed with schema and seed improvements, the recommended actions are:

1. **Migration 002 (Schema Enhancements):**
   - Add `pan_number` (VARCHAR(10) UNIQUE with Indian PAN format regex) to `customers`.
   - Add `credit_score` (INTEGER CHECK BETWEEN 300 AND 900) to `customers`.
   - Add missing B-tree indexes on all unindexed foreign key columns.
   - Drop the redundant index `idx_employment_customer` on `customer_employment(customer_id)`.
   - Add check constraint on `payments.payment_method` and `emi_schedule (emi_amount = principal_component + interest_component)`.
2. **Seed Data Expansion Script:**
   - Generate full 36-month and 48-month amortization schedules for Loan #1 and Loan #2.
   - Add multiple applications for at least 2 existing customers to enable true "latest application" query testing.
   - Add realistic edge-case records: 1 Closed loan, 1 Defaulted loan, 2 overdue EMI records, and 1 duplicate customer/PAN scenario for deduplication practice.
   - Add multiple payment transactions (including partial payments) to test running balance calculations.
3. **Frontend & API Alignment:**
   - Add the PAN input field (`ABCDE1234F`) to Step 1 of the frontend modal form (`index.html`) to match Slide 7.
   - Update `server.js` to accept and persist `pan_number` during customer creation.
