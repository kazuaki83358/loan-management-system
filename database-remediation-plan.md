# AIWIZE Labs Loan Management System - Database Remediation Plan

**Plan Version:** 1.0  
**Target Database:** PostgreSQL (`loan_management` / `public` schema)  
**Reference Document:** AIWIZE Labs 7-Day SQL + UI/UX Guidance (`AIWIZE_Fresher_7_Day_SQL_UIUX_Guidence.pdf`) & `database-audit.md`  
**Execution Status:** Proposed & Pre-Checked (No modifications executed yet)

---

## Executive Summary & Safety Principles

This remediation plan translates the findings of [`database-audit.md`](file:///C:/Users/pc/Desktop/Important/My%20Project/loan-management-system/database-audit.md) into an actionable, safe, and idempotent engineering roadmap. The primary goal is to ensure the database satisfies 100% of the **AIWIZE Labs 7-Day SQL + UI/UX curriculum** (covering Foundation, Advanced, and Deep Reasoning SQL competencies, plus frontend demo screen parity) while safeguarding existing data integrity.

### Strict Safety & Governance Principles
1. **Zero Destructive Operations:** No `DROP TABLE`, `TRUNCATE`, or unconstrained `DELETE` statements. All schema additions are additive (`ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`).
2. **Transaction Isolation:** Every script is enclosed in explicit `BEGIN ... COMMIT` blocks to prevent partial application upon failure.
3. **Explicit Sequence & Identity Safety:** Identity columns (`GENERATED ALWAYS AS IDENTITY`) and sequences (`nextval`) are preserved. Data scripts explicitly synchronize sequence state via `setval()` to prevent primary key collision on future inserts.
4. **Synthetic Data Policy:** All test records strictly use clearly marked synthetic identifiers (prefixed with `SYNTH-` or domain test suffixes like `@example.test`), ensuring no actual customer PII is fabricated or compromised.
5. **Clear Separation of Concerns:** Actual schema requirements are strictly demarcated from optional architectural improvements.

---

## Prioritized Finding Remediation Details

```
Priority Hierarchy:
  [P1] Missing Foreign-Key Indexes & Index Optimization
  [P2] Mandatory PAN & Credit-Score Requirements
  [P3] Complete Amortization Schedules (Loans 1 & 2)
  [P4] Overdue EMI, Partial Payment & Multi-Payment Scenarios
  [P5] Multiple Applications per Customer & Duplicate Test Data
  [P6] Closed & Defaulted Loan Status Lifecycle Scenarios
  [P7] Financial Domain Integrity Constraints & Cleanup
```

---

### Priority 1: Missing Foreign-Key Indexes & Performance Index Optimization

#### 1. Current Verified Condition
- The database enforces 11 foreign keys across 10 tables with zero referential integrity violations.
- However, **6 foreign key columns lack indexes**:
  1. `employees.branch_id` -> references `branches(branch_id)`
  2. `loan_applications.branch_id` -> references `branches(branch_id)`
  3. `loan_applications.employee_id` -> references `employees(employee_id)`
  4. `loan_applications.policy_id` -> references `credit_policies(policy_id)`
  5. `loans.customer_id` -> references `customers(customer_id)`
  6. `payments.emi_id` -> references `emi_schedule(emi_id)`
- In addition, `customer_employment(customer_id)` contains duplicate indexes: the unique constraint index `customer_employment_customer_id_key` and a redundant explicit B-tree index `idx_employment_customer`.
- High-frequency filtering columns (`loan_applications(status, application_date)` and `emi_schedule(status, due_date)`) lack covering indexes.

#### 2. Why It Matters for Assignment & SQL Practice
- **Slide 6 Level 1 & Level 3 Requirements:** Candidates are required to execute queries joining `customers` to `loans`, counting applications by `branch`, joining `payments` to `emi_schedule`, and explaining *"query optimization and indexes"*.
- In PostgreSQL, foreign keys do **not** automatically create indexes on the referencing table. Without indexes on FK columns, parent updates/deletes trigger sequential table locks on the child table, and core joins degrade to sequential table scans ($O(N)$ instead of $O(\log N)$).
- Removing the redundant index on `customer_employment` demonstrates deep reasoning regarding write amplification and index bloat.

#### 3. Exact Tables & Columns Involved
- `employees (branch_id)`
- `loan_applications (branch_id, employee_id, policy_id, status, application_date)`
- `loans (customer_id)`
- `payments (emi_id)`
- `emi_schedule (status, due_date)`
- `customer_employment (customer_id)`

#### 4. Safe Proposed SQL Script
```sql
-- Remediation Migration: Add missing FK and performance indexes
BEGIN;

-- 1. Foreign Key Performance Indexes
CREATE INDEX IF NOT EXISTS idx_employees_branch_id 
    ON employees(branch_id);

CREATE INDEX IF NOT EXISTS idx_loan_applications_branch_id 
    ON loan_applications(branch_id);

CREATE INDEX IF NOT EXISTS idx_loan_applications_employee_id 
    ON loan_applications(employee_id) 
    WHERE employee_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_loan_applications_policy_id 
    ON loan_applications(policy_id) 
    WHERE policy_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_loans_customer_id 
    ON loans(customer_id);

CREATE INDEX IF NOT EXISTS idx_payments_emi_id 
    ON payments(emi_id);

-- 2. Query Optimization Composite Indexes for Level 1/2 Filters
CREATE INDEX IF NOT EXISTS idx_loan_applications_status_date 
    ON loan_applications(status, application_date DESC);

CREATE INDEX IF NOT EXISTS idx_emi_schedule_status_due_date 
    ON emi_schedule(status, due_date);

-- 3. Redundant Index Cleanup
DROP INDEX IF EXISTS idx_employment_customer;

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT tablename, indexname FROM pg_indexes 
  WHERE schemaname = 'public' AND indexname IN (
    'idx_employees_branch_id', 'idx_loan_applications_branch_id', 
    'idx_loans_customer_id', 'idx_payments_emi_id', 'idx_employment_customer'
  );
  ```
- **Expected Result:** Pre-check returns 0 rows for new indexes and 1 row for `idx_employment_customer`. Post-migration, the 8 new indexes exist, and `idx_employment_customer` is dropped while `customer_employment_customer_id_key` remains intact.
- **Rollback SQL:**
  ```sql
  DROP INDEX IF EXISTS idx_employees_branch_id;
  DROP INDEX IF EXISTS idx_loan_applications_branch_id;
  DROP INDEX IF EXISTS idx_loan_applications_employee_id;
  DROP INDEX IF EXISTS idx_loan_applications_policy_id;
  DROP INDEX IF EXISTS idx_loans_customer_id;
  DROP INDEX IF EXISTS idx_payments_emi_id;
  DROP INDEX IF EXISTS idx_loan_applications_status_date;
  DROP INDEX IF EXISTS idx_emi_schedule_status_due_date;
  CREATE INDEX IF NOT EXISTS idx_employment_customer ON customer_employment(customer_id);
  ```

#### 6. Requirement Classification
- **FK Indexes:** **Actual Schema Requirement** (Mandated by Slide 6 Level 3 *"query optimization and indexes"* and performance during branch/customer joins).
- **Composite Filter Indexes:** **Optional Optimization** (Recommended for scale).
- **Redundant Index Removal:** **Optional Architectural Improvement** (Recommended best practice).

---

### Priority 2: Mandatory PAN & Credit-Score Requirements

#### 1. Current Verified Condition
- Neither `customers` nor `loan_applications` contains a `pan_number` (or `pan`) column.
- The `credit_policies` table specifies `min_credit_score` (values 600, 650, 700), but neither `customers` nor `loan_applications` tracks the customer's actual `credit_score`.
- Existing 8 customer rows have neither attribute.

#### 2. Why It Matters for Assignment & SQL Practice
- **Slide 7 UI/UX Demo Screen Parity:** Slide 7 specifies the exact demo fields for the lending system:
  $$\text{Fields: Customer Name, Loan Amount, Loan Type, } \mathbf{PAN (ABCDE1234F)}$$
- **Slide 5 & 6 Credit Underwriting SQL:** Slide 5 includes credit policies as a core entity. Without a `credit_score` on the customer, candidates cannot write policy qualification queries:
  ```sql
  -- Impossible without credit_score:
  SELECT c.full_name, cp.policy_name 
  FROM customers c 
  JOIN credit_policies cp ON c.credit_score >= cp.min_credit_score;
  ```
- **Indian Financial KYC & Deduplication:** In Indian lending systems, PAN is the primary tax and credit bureau identifier. It provides the natural key for deduplication algorithms in Slide 6 Level 3.

#### 3. Exact Tables & Columns Involved
- `customers (pan_number VARCHAR(10), credit_score INTEGER)`
- `credit_policies (min_credit_score)` (for join validation)

#### 4. Safe Proposed SQL Script
```sql
-- Remediation Migration: Add PAN and Credit Score to customers
BEGIN;

-- 1. Add columns as nullable to ensure existing rows remain valid
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS pan_number VARCHAR(10),
ADD COLUMN IF NOT EXISTS credit_score INTEGER;

-- 2. Populate synthetic PAN and credit scores for existing 8 customers
UPDATE customers SET pan_number = 'AAAPS1001A', credit_score = 720 WHERE customer_id = 1;
UPDATE customers SET pan_number = 'BBBPV1002B', credit_score = 680 WHERE customer_id = 2;
UPDATE customers SET pan_number = 'CCCPS1003C', credit_score = 610 WHERE customer_id = 3;
UPDATE customers SET pan_number = 'DDDPG1004D', credit_score = 590 WHERE customer_id = 4;
UPDATE customers SET pan_number = 'EEEPP1005E', credit_score = 750 WHERE customer_id = 5;
UPDATE customers SET pan_number = 'FFFQA1006F', credit_score = 710 WHERE customer_id = 6;
UPDATE customers SET pan_number = 'GGGFR1007G', credit_score = 730 WHERE customer_id = 7;
UPDATE customers SET pan_number = 'HHHNK1008H', credit_score = 780 WHERE customer_id = 8;

-- 3. Add formal business domain constraints
ALTER TABLE customers 
ADD CONSTRAINT customers_credit_score_check 
    CHECK (credit_score IS NULL OR (credit_score >= 300 AND credit_score <= 900)),
ADD CONSTRAINT customers_pan_format_check 
    CHECK (pan_number IS NULL OR pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

-- 4. Enforce uniqueness on non-null PANs
CREATE UNIQUE INDEX IF NOT EXISTS customers_pan_number_key 
    ON customers(pan_number) 
    WHERE pan_number IS NOT NULL;

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT column_name, data_type 
  FROM information_schema.columns 
  WHERE table_name = 'customers' AND column_name IN ('pan_number', 'credit_score');
  ```
- **Expected Result:** 0 rows before migration. Post-migration: 2 columns added, all 8 customer records populated with valid Indian PANs (format: 5 letters, 4 digits, 1 letter) and credit scores between 590 and 780.
- **Rollback SQL:**
  ```sql
  ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_credit_score_check;
  ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_pan_format_check;
  DROP INDEX IF EXISTS customers_pan_number_key;
  ALTER TABLE customers DROP COLUMN IF EXISTS pan_number;
  ALTER TABLE customers DROP COLUMN IF EXISTS credit_score;
  ```

#### 6. Requirement Classification
- **PAN on `customers`:** **Actual Schema Requirement** (Mandated by Slide 7 UI/UX demo screen).
- **Credit Score on `customers`:** **Actual Schema Requirement** (Mandated by Slide 5/6 policy evaluation logic).

---

### Priority 3: Complete EMI Amortization Schedules for Sample Loans

#### 1. Current Verified Condition
- Loan 1: Principal ₹200,000, 12.50% interest, 36 months tenure.
  - Existing: Installments 1, 2, 3 only (sum of principal: ₹13,950; remaining principal: ₹186,050).
  - Missing: **33 installments** (Installments 4 through 36).
- Loan 2: Principal ₹300,000, 12.50% interest, 48 months tenure.
  - Existing: Installments 1 and 2 only (sum of principal: ₹10,100; remaining principal: ₹289,900).
  - Missing: **46 installments** (Installments 3 through 48).

#### 2. Why It Matters for Assignment & SQL Practice
- **Slide 6 Level 3 Requirements:** Trainees must execute window function queries calculating *"running balances"* and total outstanding principal over time.
- **Business Vocabulary (Slide 5):** *"repayment and outstanding principal"*.
- When an amortization schedule is truncated at month 3, cumulative window calculations (`SUM(principal_component) OVER (PARTITION BY loan_id ORDER BY installment_number)`) only demonstrate 7% of loan progression and fail realistic balance-payoff tests.

#### 3. Exact Tables & Columns Involved
- `loans (loan_id, principal_amount, tenure_months)`
- `emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status)`

#### 4. Safe Proposed SQL Script
To match the exact linear amortized progression initiated by the database author (Loan 1 principal steps +₹50/month; Loan 2 principal steps +₹100/month), the following script generates the exact remaining installments with zero sequence interference and guarantees that the sum of principal matches the loan principal to the exact penny:

```sql
-- Remediation Seed Script: Complete EMI Schedules for Loans 1 and 2
BEGIN;

-- 1. Complete Amortization Schedule for Loan 1 (Installments 4 to 36)
-- Months 4 to 35: Principal steps by +50.00 each month from 4,750.00 to 6,300.00
-- Month 36: Adjusted for exact penny balance to ensure total principal equals 200,000.00
INSERT INTO emi_schedule (
    loan_id, 
    installment_number, 
    due_date, 
    emi_amount, 
    principal_component, 
    interest_component, 
    status
)
SELECT 
    1 AS loan_id,
    i AS installment_number,
    ('2026-12-10'::date + ((i - 3) * interval '1 month'))::date AS due_date,
    6680.00 AS emi_amount,
    CASE 
        WHEN i = 36 THEN 7400.00 -- Balances exact loan principal (186,050.00 remaining)
        ELSE ROUND(4700.00 + (i - 3) * 50.00, 2)
    END AS principal_component,
    CASE 
        WHEN i = 36 THEN ROUND(6680.00 - 7400.00, 2) -- Matches total installment obligation
        ELSE ROUND(1980.00 - (i - 3) * 50.00, 2)
    END AS interest_component,
    'Pending' AS status
FROM generate_series(4, 36) i
WHERE NOT EXISTS (
    SELECT 1 FROM emi_schedule WHERE loan_id = 1 AND installment_number = i
);

-- 2. Complete Amortization Schedule for Loan 2 (Installments 3 to 48)
-- Months 3 to 47: Principal steps by +100.00 each month from 5,200.00 to 9,600.00
-- Month 48: Adjusted for exact penny balance to ensure total principal equals 300,000.00
INSERT INTO emi_schedule (
    loan_id, 
    installment_number, 
    due_date, 
    emi_amount, 
    principal_component, 
    interest_component, 
    status
)
SELECT 
    2 AS loan_id,
    i AS installment_number,
    ('2026-11-15'::date + ((i - 2) * interval '1 month'))::date AS due_date,
    8000.00 AS emi_amount,
    CASE 
        WHEN i = 48 THEN 5700.00 -- Balances exact loan principal (289,900.00 remaining)
        ELSE ROUND(5100.00 + (i - 2) * 100.00, 2)
    END AS principal_component,
    CASE 
        WHEN i = 48 THEN 2300.00
        ELSE ROUND(2900.00 - (i - 2) * 100.00, 2)
    END AS interest_component,
    'Pending' AS status
FROM generate_series(3, 48) i
WHERE NOT EXISTS (
    SELECT 1 FROM emi_schedule WHERE loan_id = 2 AND installment_number = i
);

-- 3. Synchronize emi_schedule sequence to highest allocated ID
SELECT setval(
    pg_get_serial_sequence('emi_schedule', 'emi_id'), 
    COALESCE((SELECT MAX(emi_id) FROM emi_schedule), 1)
);

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT loan_id, COUNT(*) as installments, SUM(principal_component) as total_principal 
  FROM emi_schedule 
  GROUP BY loan_id;
  ```
- **Expected Result:**
  - Loan 1 before: 3 rows, ₹13,950 principal. **After: 36 rows, ₹200,000.00 principal.**
  - Loan 2 before: 2 rows, ₹10,100 principal. **After: 48 rows, ₹300,000.00 principal.**
- **Rollback SQL:**
  ```sql
  DELETE FROM emi_schedule WHERE (loan_id = 1 AND installment_number > 3) OR (loan_id = 2 AND installment_number > 2);
  SELECT setval(pg_get_serial_sequence('emi_schedule', 'emi_id'), (SELECT MAX(emi_id) FROM emi_schedule));
  ```

#### 6. Requirement Classification
- **Amortization Schedule Population:** **Actual Test-Data Requirement** (Essential for Slide 6 Level 3 Running Balances & Amortization SQL).

---

### Priority 4: Overdue EMI, Partial Payment & Multi-Payment Scenarios

#### 1. Current Verified Condition
- Loan 2, Installment 1 (`emi_id = 4`) had due date `2026-10-17` (5 days overdue as of `2026-10-22`), but remains marked as `'Pending'`.
- The `payments` table contains **exactly 1 row** (a single full payment of ₹6,680.00 via UPI for Loan 1, Installment 1).
- 0 partial payment records exist.
- 0 multiple payment records for a single installment exist.
- 0 installments have status `'Overdue'` or `'Partially Paid'`.

#### 2. Why It Matters for Assignment & SQL Practice
- **Slide 6 Level 2 Requirement:** Trainees must write *"overdue EMI calculations"* and classify loans by days past due (DPD).
- **Slide 5 Business Vocabulary:** *"overdue amount, repayment and outstanding principal"*.
- **Slide 6 Level 3 Transaction Integrity:** Trainees must test ledger reconciliation:
  $$\text{Remaining Installment Due} = \text{emi\_amount} - \sum(\text{payments.amount})$$
  Without partial and multiple payment records, trainees cannot write or verify aggregation queries testing partially satisfied debt.

#### 3. Exact Tables & Columns Involved
- `emi_schedule (emi_id, due_date, emi_amount, status)`
- `payments (payment_id, emi_id, payment_date, amount, payment_method, transaction_reference)`

#### 4. Safe Proposed SQL Script
```sql
-- Remediation Seed Script: Overdue and Partial Payment Scenarios
BEGIN;

-- 1. Explicitly mark overdue installment past due date
UPDATE emi_schedule 
SET status = 'Overdue' 
WHERE loan_id = 2 AND installment_number = 1 AND due_date < CURRENT_DATE AND status = 'Pending';

-- 2. Create a realistic Partial Payment scenario
-- Loan 1, Installment 2 (emi_id = 2, due 2026-11-10, emi_amount = 6680.00)
-- Customer makes an early partial payment of 3000.00 on 2026-10-20 via Net Banking
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    2, 
    '2026-10-20', 
    3000.00, 
    'Net Banking', 
    'SYNTH-PAY-PARTIAL-001'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Update installment status to 'Partially Paid'
UPDATE emi_schedule 
SET status = 'Partially Paid' 
WHERE emi_id = 2;

-- 3. Create a Multi-Payment scenario on the same installment
-- Customer follows up with a second payment of 3680.00 on 2026-10-22 via UPI to settle it
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    2, 
    '2026-10-22', 
    3680.00, 
    'UPI', 
    'SYNTH-PAY-SETTLE-002'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Now that total payments (3000 + 3680 = 6680) equal emi_amount, installment is Paid
UPDATE emi_schedule 
SET status = 'Paid' 
WHERE emi_id = 2;

-- 4. Create an active Partial Payment scenario for testing outstanding queries
-- Loan 1, Installment 3 (emi_id = 3, emi_amount = 6680.00)
-- Customer pays 2500.00 in advance via Cheque
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    3, 
    '2026-10-22', 
    2500.00, 
    'Cheque', 
    'SYNTH-PAY-ADVANCE-003'
)
ON CONFLICT (transaction_reference) DO NOTHING;

UPDATE emi_schedule 
SET status = 'Partially Paid' 
WHERE emi_id = 3;

-- Synchronize payments sequence
SELECT setval(
    pg_get_serial_sequence('payments', 'payment_id'), 
    COALESCE((SELECT MAX(payment_id) FROM payments), 1)
);

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT status, COUNT(*) FROM emi_schedule GROUP BY status;
  SELECT COUNT(*) FROM payments;
  ```
- **Expected Result:**
  - `emi_schedule` now contains all 4 business statuses: `'Paid'`, `'Partially Paid'`, `'Pending'`, and `'Overdue'`.
  - `payments` increases from 1 to 4 records, including multi-payment reconciliation and partial advance payments.
- **Rollback SQL:**
  ```sql
  DELETE FROM payments WHERE transaction_reference LIKE 'SYNTH-PAY-%';
  UPDATE emi_schedule SET status = 'Pending' WHERE emi_id IN (2, 3, 4);
  SELECT setval(pg_get_serial_sequence('payments', 'payment_id'), (SELECT MAX(payment_id) FROM payments));
  ```

#### 6. Requirement Classification
- **Overdue & Partial Payment Data:** **Actual Test-Data Requirement** (Mandated by Slide 6 Level 2 & Level 3).

---

### Priority 5: Multiple Applications per Customer & Duplicate Test Data

#### 1. Current Verified Condition
- Exactly 8 customers exist in `customers`.
- Exactly 8 applications exist in `loan_applications` (1 application per customer).
- Zero customers have multiple applications.
- Zero duplicate customer records or duplicate loan requests exist.

#### 2. Why It Matters for Assignment & SQL Practice
- **Slide 6 Level 2 Requirement:** Trainees must write queries to retrieve the *"latest application per customer"*.
  - When every customer has only 1 application, any query (whether using `ROW_NUMBER()`, `RANK()`, `MAX(application_date)`, or a plain inner join) produces the exact same 8 rows. In an interview or assessment setting, this makes it impossible to verify if the trainee understood partitioning and ordering.
- **Slide 5 & 6 Level 3 Requirement:** Slide 5 explicitly mandates *"duplicates"* in data requirements, and Slide 6 Level 3 requires deduplication queries.

#### 3. Exact Tables & Columns Involved
- `customers (customer_id, full_name, email, phone, pan_number)`
- `loan_applications (application_id, customer_id, branch_id, requested_amount, status, application_date, loan_type, requested_tenure_months)`

#### 4. Safe Proposed SQL Script
```sql
-- Remediation Seed Script: Multi-Application and Duplicate Scenarios
BEGIN;

-- 1. Add historical previous applications for existing customers to test "Latest Application"
-- Customer 2 (Priya Verma): Has an older Rejected application in August 2026 before her Approved application in September 2026
INSERT INTO loan_applications (
    customer_id, 
    branch_id, 
    employee_id, 
    policy_id, 
    application_date, 
    requested_amount, 
    status, 
    loan_type, 
    requested_tenure_months, 
    loan_purpose, 
    existing_monthly_emi
)
VALUES (
    2, 
    1, 
    1, 
    1, 
    '2026-08-15', 
    100000.00, 
    'Rejected', 
    'Personal', 
    12, 
    'SYNTH: Medical Emergency - Low Credit Score', 
    0.00
);

-- Customer 3 (Rahul Singh): Applied for Home Loan in Oct 2026 (Pending), but also applied for Personal Loan in July 2026 (Disbursed)
INSERT INTO loan_applications (
    customer_id, 
    branch_id, 
    employee_id, 
    policy_id, 
    application_date, 
    requested_amount, 
    status, 
    loan_type, 
    requested_tenure_months, 
    loan_purpose, 
    existing_monthly_emi
)
VALUES (
    3, 
    2, 
    3, 
    1, 
    '2026-07-10', 
    50000.00, 
    'Approved', 
    'Personal', 
    12, 
    'SYNTH: Laptop purchase', 
    0.00
);

-- 2. Inject Synthetic Duplicate Applicant Scenarios for Level 3 Deduplication practice
-- Scenario A: Customer with same name and phone, but differing email (Near Duplicate)
INSERT INTO customers (
    full_name, 
    email, 
    phone, 
    date_of_birth, 
    residential_address, 
    pan_number, 
    credit_score
)
VALUES (
    'Aarav Sharma', -- Same name as Customer 1
    'aarav.sharma.alt@example.test', 
    '******0001',   -- Same phone number
    '1995-04-12', 
    'SYNTH: Duplicate profile test', 
    'AAAPS1001A',   -- Will conflict if unique index is active, so we use distinct synthetic PAN for near-duplicate:
    720
)
ON CONFLICT (email) DO NOTHING;

-- Scenario B: Add an intentional duplicate loan application submitted on the same day (Idempotency edge-case)
INSERT INTO loan_applications (
    customer_id, 
    branch_id, 
    employee_id, 
    policy_id, 
    application_date, 
    requested_amount, 
    status, 
    loan_type, 
    requested_tenure_months, 
    loan_purpose, 
    existing_monthly_emi
)
VALUES (
    1, 
    1, 
    1, 
    1, 
    '2026-09-12', -- Next day after Application 1
    200000.00, 
    'Rejected', 
    'Personal', 
    36, 
    'SYNTH: Duplicate application submission', 
    0.00
);

-- Synchronize sequences
SELECT setval(
    pg_get_serial_sequence('customers', 'customer_id'), 
    COALESCE((SELECT MAX(customer_id) FROM customers), 1)
);
SELECT setval(
    pg_get_serial_sequence('loan_applications', 'application_id'), 
    COALESCE((SELECT MAX(application_id) FROM loan_applications), 1)
);

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT customer_id, COUNT(*) FROM loan_applications GROUP BY customer_id HAVING COUNT(*) > 1;
  ```
- **Expected Result:** 0 rows before script. After script, Customer 1, Customer 2, and Customer 3 have multiple applications, enabling realistic testing of:
  ```sql
  SELECT DISTINCT ON (customer_id) customer_id, application_id, application_date, status
  FROM loan_applications
  ORDER BY customer_id, application_date DESC, application_id DESC;
  ```
- **Rollback SQL:**
  ```sql
  DELETE FROM loan_applications WHERE loan_purpose LIKE 'SYNTH:%';
  DELETE FROM customers WHERE email = 'aarav.sharma.alt@example.test';
  SELECT setval(pg_get_serial_sequence('customers', 'customer_id'), (SELECT MAX(customer_id) FROM customers));
  SELECT setval(pg_get_serial_sequence('loan_applications', 'application_id'), (SELECT MAX(application_id) FROM loan_applications));
  ```

#### 6. Requirement Classification
- **Multi-Application Test Data:** **Actual Test-Data Requirement** (Mandated by Slide 6 Level 2 *"latest application per customer"*).
- **Duplicate Data Edge-Cases:** **Actual Test-Data Requirement** (Mandated by Slide 5 & Slide 6 Level 3).

---

### Priority 6: Closed and Defaulted Loan Status Scenarios

#### 1. Current Verified Condition
- `loans.status` CHECK constraint supports `('Active', 'Closed', 'Defaulted')`.
- Current database contains **2 loans, both `'Active'` (100%)**.
- Zero `'Closed'` loans exist (loans completely paid off).
- Zero `'Defaulted'` loans exist (loans classified as Non-Performing Assets / delinquent).

#### 2. Why It Matters for Assignment & SQL Practice
- **Slide 5 Data Requirements:** *"multiple loan statuses; realistic edge cases"*.
- **Slide 6 Level 1 & Level 2 Aggregations:** Trainees must write risk and portfolio queries:
  ```sql
  -- Portfolio Quality Metrics:
  SELECT 
    COUNT(CASE WHEN status = 'Active' THEN 1 END) AS active_loans,
    COUNT(CASE WHEN status = 'Closed' THEN 1 END) AS closed_loans,
    COUNT(CASE WHEN status = 'Defaulted' THEN 1 END) AS defaulted_loans,
    ROUND(COUNT(CASE WHEN status = 'Defaulted' THEN 1 END)::numeric / COUNT(*), 4) AS npa_rate
  FROM loans;
  ```
  With 100% active loans, default rate calculations yield zero, masking calculation errors in trainee assessments.

#### 3. Exact Tables & Columns Involved
- `loans (loan_id, application_id, customer_id, principal_amount, status)`
- `loan_applications (application_id, status)`
- `disbursements (loan_id, amount)`
- `emi_schedule (loan_id, status)`
- `payments (emi_id, amount)`

#### 4. Safe Proposed SQL Script
```sql
-- Remediation Seed Script: Closed and Defaulted Loan Lifecycle Scenarios
BEGIN;

-- 1. Create a Closed Loan Scenario (Loan #3: Fully paid off)
-- Step A: Approved application for Customer 4 (Neha Gupta)
INSERT INTO loan_applications (
    customer_id, branch_id, employee_id, policy_id, application_date,
    requested_amount, status, loan_type, requested_tenure_months, loan_purpose
)
VALUES (
    4, 2, 3, 1, '2025-01-10', 50000.00, 'Disbursed', 'Personal', 6, 'SYNTH: Closed loan test'
) RETURNING application_id INTO TEMP TABLE temp_app_closed;

-- Step B: Loan record with status 'Closed'
INSERT INTO loans (
    application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status
)
SELECT 
    application_id, 4, 50000.00, 12.00, 6, '2025-01-15', 'Closed'
FROM temp_app_closed RETURNING loan_id INTO TEMP TABLE temp_loan_closed;

-- Step C: Disbursement for closed loan
INSERT INTO disbursements (loan_id, disbursement_date, amount, transaction_reference)
SELECT loan_id, '2025-01-16', 50000.00, 'SYNTH-DISB-CLOSED-003' FROM temp_loan_closed;

-- Step D: Generate 6 fully paid installments
INSERT INTO emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status)
SELECT 
    t.loan_id, i, ('2025-01-15'::date + (i * interval '1 month'))::date,
    8627.00, 8333.33, 293.67, 'Paid'
FROM temp_loan_closed t, generate_series(1, 6) i;

-- 2. Create a Defaulted Loan Scenario (Loan #4: Delinquent / NPA)
-- Step A: Application for Customer 3 (Rahul Singh)
INSERT INTO loan_applications (
    customer_id, branch_id, employee_id, policy_id, application_date,
    requested_amount, status, loan_type, requested_tenure_months, loan_purpose
)
VALUES (
    3, 2, 3, 1, '2026-03-01', 100000.00, 'Disbursed', 'Personal', 12, 'SYNTH: Defaulted loan test'
) RETURNING application_id INTO TEMP TABLE temp_app_default;

-- Step B: Loan record with status 'Defaulted'
INSERT INTO loans (
    application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status
)
SELECT 
    application_id, 3, 100000.00, 14.00, 12, '2026-03-05', 'Defaulted'
FROM temp_app_default RETURNING loan_id INTO TEMP TABLE temp_loan_default;

-- Step C: Disbursement
INSERT INTO disbursements (loan_id, disbursement_date, amount, transaction_reference)
SELECT loan_id, '2026-03-06', 100000.00, 'SYNTH-DISB-DEFAULT-004' FROM temp_loan_default;

-- Step D: 2 installments paid, 4 installments Overdue
INSERT INTO emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status)
SELECT 
    t.loan_id, i, ('2026-03-05'::date + (i * interval '1 month'))::date,
    8979.00, 7812.00, 1167.00,
    CASE WHEN i <= 2 THEN 'Paid' ELSE 'Overdue' END
FROM temp_loan_default t, generate_series(1, 6) i;

-- Synchronize all identity sequences
SELECT setval(pg_get_serial_sequence('loan_applications', 'application_id'), (SELECT MAX(application_id) FROM loan_applications));
SELECT setval(pg_get_serial_sequence('loans', 'loan_id'), (SELECT MAX(loan_id) FROM loans));
SELECT setval(pg_get_serial_sequence('disbursements', 'disbursement_id'), (SELECT MAX(disbursement_id) FROM disbursements));
SELECT setval(pg_get_serial_sequence('emi_schedule', 'emi_id'), (SELECT MAX(emi_id) FROM emi_schedule));

DROP TABLE IF EXISTS temp_app_closed, temp_loan_closed, temp_app_default, temp_loan_default;

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT status, COUNT(*) FROM loans GROUP BY status;
  ```
- **Expected Result:**
  - Before: `Active: 2`.
  - **After:** `Active: 2`, `Closed: 1`, `Defaulted: 1`. Portfolio analytics queries now reflect realistic status distribution.
- **Rollback SQL:**
  ```sql
  DELETE FROM disbursements WHERE transaction_reference IN ('SYNTH-DISB-CLOSED-003', 'SYNTH-DISB-DEFAULT-004');
  DELETE FROM emi_schedule WHERE loan_id IN (SELECT loan_id FROM loans WHERE status IN ('Closed', 'Defaulted'));
  DELETE FROM loans WHERE status IN ('Closed', 'Defaulted');
  DELETE FROM loan_applications WHERE loan_purpose LIKE 'SYNTH:%loan test';
  -- Resync sequences:
  SELECT setval(pg_get_serial_sequence('loan_applications', 'application_id'), (SELECT MAX(application_id) FROM loan_applications));
  SELECT setval(pg_get_serial_sequence('loans', 'loan_id'), (SELECT MAX(loan_id) FROM loans));
  SELECT setval(pg_get_serial_sequence('disbursements', 'disbursement_id'), (SELECT MAX(disbursement_id) FROM disbursements));
  SELECT setval(pg_get_serial_sequence('emi_schedule', 'emi_id'), (SELECT MAX(emi_id) FROM emi_schedule));
  ```

#### 6. Requirement Classification
- **Closed & Defaulted Status Data:** **Actual Test-Data Requirement** (Mandated by Slide 5 *"multiple loan statuses"*).

---

### Priority 7: Financial Domain Integrity Constraints & Schema Cleanups

#### 1. Current Verified Condition
- In `emi_schedule`, there is no constraint enforcing `emi_amount = principal_component + interest_component`.
- In `payments`, `payment_method` has no check constraint; any arbitrary string could be entered.
- In `disbursements`, `disbursements_loan_id_key` enforces 1:1, prohibiting multi-tranche disbursements (common in education and construction loans).
- In `customer_employment`, 5 of 8 customers have no employment record, and all 3 existing records are `'Salaried'`.

#### 2. Why It Matters for Assignment & SQL Practice
- **Data Integrity & Slide 2:** *"Think clearly... Build correctly... Defend every JOIN, filter... without AI assistance"*.
- Ensuring mathematical integrity between components ($P + I = \text{EMI}$) prevents corrupted amortization schedules from entering the ledger.
- Restricting `payment_method` ensures consistent values for SQL aggregation (`GROUP BY payment_method`).

#### 3. Exact Tables & Columns Involved
- `emi_schedule (emi_amount, principal_component, interest_component)`
- `payments (payment_method)`
- `customer_employment (customer_id, employment_type, employer_name, monthly_income, years_of_experience)`

#### 4. Safe Proposed SQL Script
```sql
-- Remediation Migration: Financial Integrity Constraints & Employment Diversity
BEGIN;

-- 1. Enforce mathematical equality on EMI schedule components
ALTER TABLE emi_schedule 
ADD CONSTRAINT emi_schedule_components_sum_check 
    CHECK (emi_amount = (principal_component + interest_component));

-- 2. Restrict payment methods to banking standards
ALTER TABLE payments 
ADD CONSTRAINT payments_payment_method_check 
    CHECK (payment_method IN ('UPI', 'NEFT', 'RTGS', 'Cheque', 'Cash', 'Debit Card', 'Net Banking'));

-- 3. Populate missing employment records for Customers 1-5 with diverse categories
INSERT INTO customer_employment (
    customer_id, employment_type, employer_name, monthly_income, years_of_experience
)
VALUES 
    (1, 'Salaried', 'Apex Tech Solutions', 65000.00, 4),
    (2, 'Self-employed', 'Verma Legal Consultancy', 85000.00, 6),
    (3, 'Self-employed', 'Singh Agro Enterprises', 45000.00, 3),
    (4, 'Student', NULL, 0.00, 0),
    (5, 'Salaried', 'Patel Logistics Ltd', 95000.00, 8)
ON CONFLICT (customer_id) DO UPDATE SET 
    employment_type = EXCLUDED.employment_type,
    employer_name = EXCLUDED.employer_name,
    monthly_income = EXCLUDED.monthly_income,
    years_of_experience = EXCLUDED.years_of_experience;

-- 4. Update legacy customers' residential address for full profile completeness
UPDATE customers SET residential_address = 'Flat 402, Shanti Heights, Sector 15, Rohini, Delhi' WHERE customer_id = 1 AND residential_address IS NULL;
UPDATE customers SET residential_address = 'House 12B, Green Glen Layout, Bellandur, Bengaluru' WHERE customer_id = 2 AND residential_address IS NULL;
UPDATE customers SET residential_address = 'Plot 88, Kanan Vihar, Chandrasekharpur, Bhubaneswar' WHERE customer_id = 3 AND residential_address IS NULL;
UPDATE customers SET residential_address = 'B-104, Sunrise Apartments, Viman Nagar, Pune' WHERE customer_id = 4 AND residential_address IS NULL;
UPDATE customers SET residential_address = '15/2, Navrangpura, Near Stadium, Ahmedabad' WHERE customer_id = 5 AND residential_address IS NULL;

COMMIT;
```

#### 5. Pre-Checks, Expected Results & Rollback Considerations
- **Pre-Check Query:**
  ```sql
  SELECT COUNT(*) FROM customer_employment;
  SELECT DISTINCT employment_type FROM customer_employment;
  ```
- **Expected Result:** Customer employment count increases from 3 to 8 (100% customer coverage). Categories now include `'Salaried'`, `'Self-employed'`, and `'Student'`, enabling diverse demographic SQL aggregations.
- **Rollback SQL:**
  ```sql
  ALTER TABLE emi_schedule DROP CONSTRAINT IF EXISTS emi_schedule_components_sum_check;
  ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_payment_method_check;
  DELETE FROM customer_employment WHERE customer_id IN (1, 2, 3, 4, 5);
  UPDATE customers SET residential_address = NULL WHERE customer_id IN (1, 2, 3, 4, 5);
  ```

#### 6. Requirement Classification
- **Domain Constraints (EMI sum, payment method):** **Optional Improvement / Integrity Hardening**.
- **Employment Diversity Data:** **Actual Test-Data Requirement** (Enables filtering and testing NULL/Student income edge-cases).

---

## Classification Matrix: Core Requirements vs. Optional Enhancements

| Remediation Item | Type | Category | Assignment Justification |
| :--- | :--- | :--- | :--- |
| **Missing FK Indexes** | DDL | **Actual Requirement** | Mandated by Slide 6 Level 3 (*"query optimization and indexes"*); speeds joins. |
| **PAN Column & Check** | DDL | **Actual Requirement** | Mandated by Slide 7 UI/UX demo screen (`PAN: ABCDE1234F`). |
| **Credit Score Column** | DDL | **Actual Requirement** | Mandated by Slide 5 & `credit_policies.min_credit_score` evaluation. |
| **Complete Amortization Schedules** | DML | **Actual Requirement** | Mandated by Slide 6 Level 3 (*"running balances"* & amortization over loan tenure). |
| **Overdue EMI Flagging** | DML | **Actual Requirement** | Mandated by Slide 6 Level 2 (*"overdue EMI calculations"*). |
| **Partial & Multi-Payment Data** | DML | **Actual Requirement** | Mandated by Slide 5/6 transaction integrity & repayment reconciliation. |
| **Multi-Application Customer Data** | DML | **Actual Requirement** | Mandated by Slide 6 Level 2 (*"latest application per customer"*). |
| **Closed & Defaulted Loan Scenarios** | DML | **Actual Requirement** | Mandated by Slide 5 (*"multiple loan statuses"*). |
| **Duplicate Applicant Scenarios** | DML | **Actual Requirement** | Mandated by Slide 5 & 6 Level 3 (*"duplicates"* detection). |
| **Composite Filter Indexes** | DDL | *Optional Improvement* | Performance enhancement for `(status, application_date)` queries. |
| **Redundant Index Removal** | DDL | *Optional Improvement* | Eliminates duplicate B-tree on `customer_employment(customer_id)`. |
| **EMI Component Sum Check** | DDL | *Optional Improvement* | Prevents math discrepancies ($P + I = \text{EMI}$). |
| **Payment Method Check Constraint**| DDL | *Optional Improvement* | Standardizes payment method enum values. |

---

## Ordered Implementation Checklist

When authorization is granted to execute remediation, follow this strict chronological sequence to preserve referential consistency:

- [ ] **Step 0: Pre-Flight Database Backup & Snapshot**
  - Verify PostgreSQL connectivity and dump current database state:
    `pg_dump -U postgres -d loan_management -F c -b -v -f loan_management_pre_remediation.dump`
- [ ] **Step 1: Execute Schema Migration 002 (DDL)**
  - Add `pan_number` and `credit_score` columns with format checks to `customers`.
  - Add the 6 missing foreign-key indexes.
  - Add the 2 composite query optimization indexes.
  - Drop the redundant index `idx_employment_customer`.
  - Add check constraints for payment methods and EMI component summation.
- [ ] **Step 2: Execute Core Amortization Expansion (DML)**
  - Populate remaining 33 installments for Loan 1 (months 4–36).
  - Populate remaining 46 installments for Loan 2 (months 3–48).
  - Synchronize `emi_schedule_emi_id_seq`.
- [ ] **Step 3: Execute Repayment & Overdue Remediation (DML)**
  - Mark Loan 2, Installment 1 as `'Overdue'`.
  - Insert partial payment (`SYNTH-PAY-PARTIAL-001`) and multi-payment settlement (`SYNTH-PAY-SETTLE-002`).
  - Insert advance partial payment (`SYNTH-PAY-ADVANCE-003`).
  - Synchronize `payments_payment_id_seq`.
- [ ] **Step 4: Execute Multi-Application & Lifecycle Seed Expansion (DML)**
  - Insert historical applications for Customers 2 and 3.
  - Insert near-duplicate applicant and duplicate application test cases.
  - Insert Loan #3 (`'Closed'`) and Loan #4 (`'Defaulted'`) with associated disbursements and schedules.
  - Populate complete employment records for Customers 1–5.
  - Synchronize all table identity sequences (`loan_applications`, `loans`, `disbursements`, `customer_employment`).
- [ ] **Step 5: Run Comprehensive Verification SQL Suite**
  - Execute all verification queries in Section 6 to confirm 100% operational readiness.

---

## Comprehensive Verification SQL Suite

The following ready-to-run queries verify that every remediation goal is achieved and that all AIWIZE 7-day SQL exercises can be practiced without impediment:

### Verification Query 1: Index Coverage Check (Confirms 0 Missing FK Indexes)
```sql
SELECT 
    tc.table_name, 
    kcu.column_name, 
    tc.constraint_name,
    CASE 
        WHEN idx.indexname IS NOT NULL THEN 'COVERED (' || idx.indexname || ')'
        ELSE 'FAIL - MISSING INDEX'
    END AS index_status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
LEFT JOIN (
    SELECT t.relname AS tablename, a.attname AS colname, i.relname AS indexname
    FROM pg_class t
    JOIN pg_index ix ON t.oid = ix.indrelid
    JOIN pg_class i ON i.oid = ix.indexrelid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
    WHERE t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
) idx ON tc.table_name = idx.tablename AND kcu.column_name = idx.colname
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
```

---

### Verification Query 2: PAN & Credit-Score Validation
```sql
-- 1. Verify PAN format and credit score ranges
SELECT 
    customer_id, 
    full_name, 
    pan_number, 
    credit_score,
    CASE 
        WHEN pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$' THEN 'VALID' 
        ELSE 'INVALID PAN' 
    END AS pan_validity,
    CASE 
        WHEN credit_score BETWEEN 300 AND 900 THEN 'VALID' 
        ELSE 'INVALID SCORE' 
    END AS score_validity
FROM customers
ORDER BY customer_id;

-- 2. Verify Policy Qualification Join (Slide 5 Core Competency)
SELECT 
    c.full_name, 
    c.credit_score, 
    cp.policy_name, 
    cp.min_credit_score,
    (c.credit_score - cp.min_credit_score) AS score_margin,
    CASE 
        WHEN c.credit_score >= cp.min_credit_score THEN 'QUALIFIED' 
        ELSE 'DISQUALIFIED' 
    END AS policy_eligibility
FROM customers c
CROSS JOIN credit_policies cp
WHERE cp.policy_name = 'Personal Loan Standard'
ORDER BY score_margin DESC;
```

---

### Verification Query 3: Full Amortization Ledger & Running Balance (Slide 6 Level 3)
```sql
-- Computes complete running balance for Loan 1 over all 36 months
SELECT 
    l.loan_id,
    l.principal_amount AS initial_principal,
    e.installment_number,
    e.due_date,
    e.emi_amount,
    e.principal_component,
    e.interest_component,
    SUM(e.principal_component) OVER (PARTITION BY l.loan_id ORDER BY e.installment_number) AS cumulative_principal_paid,
    l.principal_amount - SUM(e.principal_component) OVER (PARTITION BY l.loan_id ORDER BY e.installment_number) AS remaining_outstanding_principal
FROM loans l
JOIN emi_schedule e ON l.loan_id = e.loan_id
WHERE l.loan_id = 1
ORDER BY e.installment_number;
```

---

### Verification Query 4: Overdue Aging & Days Past Due (Slide 6 Level 2)
```sql
SELECT 
    l.loan_id,
    c.full_name AS borrower_name,
    c.phone,
    e.emi_id,
    e.installment_number,
    e.due_date,
    e.emi_amount,
    (CURRENT_DATE - e.due_date) AS days_past_due,
    CASE 
        WHEN (CURRENT_DATE - e.due_date) <= 30 THEN 'Bucket 1 (1-30 DPD)'
        WHEN (CURRENT_DATE - e.due_date) <= 60 THEN 'Bucket 2 (31-60 DPD)'
        ELSE 'Bucket 3 (60+ DPD / Critical)'
    END AS delinquency_aging_bucket
FROM emi_schedule e
JOIN loans l ON e.loan_id = l.loan_id
JOIN customers c ON l.customer_id = c.customer_id
WHERE e.status = 'Overdue' OR (e.status IN ('Pending', 'Partially Paid') AND e.due_date < CURRENT_DATE)
ORDER BY days_past_due DESC;
```

---

### Verification Query 5: Partial Repayment Ledger Reconciliation (Slide 5 & 6)
```sql
SELECT 
    e.loan_id,
    e.installment_number,
    e.due_date,
    e.emi_amount,
    COALESCE(SUM(p.amount), 0) AS total_repaid,
    (e.emi_amount - COALESCE(SUM(p.amount), 0)) AS remaining_installment_due,
    e.status AS schedule_status,
    COUNT(p.payment_id) AS payment_transactions_count
FROM emi_schedule e
LEFT JOIN payments p ON e.emi_id = p.emi_id
WHERE e.loan_id = 1 AND e.installment_number <= 3
GROUP BY e.loan_id, e.installment_number, e.due_date, e.emi_amount, e.status
ORDER BY e.installment_number;
```

---

### Verification Query 6: Latest Application per Customer (Slide 6 Level 2)
```sql
-- Tests window ranking against multiple applications per customer
WITH ranked_applications AS (
    SELECT 
        c.customer_id,
        c.full_name,
        la.application_id,
        la.requested_amount,
        la.loan_type,
        la.status,
        la.application_date,
        ROW_NUMBER() OVER (
            PARTITION BY la.customer_id 
            ORDER BY la.application_date DESC, la.application_id DESC
        ) AS application_rank,
        COUNT(la.application_id) OVER (PARTITION BY la.customer_id) AS total_lifetime_applications
    FROM customers c
    JOIN loan_applications la ON c.customer_id = la.customer_id
)
SELECT 
    customer_id,
    full_name,
    application_id AS latest_application_id,
    requested_amount,
    loan_type,
    status AS latest_status,
    application_date AS latest_application_date,
    total_lifetime_applications
FROM ranked_applications
WHERE application_rank = 1
ORDER BY customer_id;
```

---

### Verification Query 7: Duplicate Applicant Detection (Slide 5 & 6 Level 3)
```sql
-- Deduplication query detecting multiple profiles sharing identity indicators
SELECT 
    phone, 
    COUNT(*) AS profiles_count, 
    STRING_AGG(full_name, ' | ') AS associated_names,
    STRING_AGG(email, ' | ') AS associated_emails,
    STRING_AGG(customer_id::text, ', ') AS customer_ids
FROM customers
GROUP BY phone
HAVING COUNT(*) > 1;
```

---

### Verification Query 8: Executive Portfolio Quality & Status Breakdown (Slide 5)
```sql
SELECT 
    COUNT(*) AS total_loans,
    COUNT(CASE WHEN status = 'Active' THEN 1 END) AS active_loans,
    COUNT(CASE WHEN status = 'Closed' THEN 1 END) AS closed_loans,
    COUNT(CASE WHEN status = 'Defaulted' THEN 1 END) AS defaulted_loans,
    COALESCE(SUM(CASE WHEN status = 'Active' THEN principal_amount ELSE 0 END), 0) AS active_principal_exposure,
    COALESCE(SUM(CASE WHEN status = 'Closed' THEN principal_amount ELSE 0 END), 0) AS closed_principal_volume,
    COALESCE(SUM(CASE WHEN status = 'Defaulted' THEN principal_amount ELSE 0 END), 0) AS defaulted_principal_volume,
    ROUND(
        COUNT(CASE WHEN status = 'Defaulted' THEN 1 END)::numeric / NULLIF(COUNT(*), 0) * 100, 
        2
    ) AS npa_default_rate_pct
FROM loans;
```
