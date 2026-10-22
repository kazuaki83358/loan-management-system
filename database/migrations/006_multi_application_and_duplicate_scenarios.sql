-- Migration: 006_multi_application_and_duplicate_scenarios.sql
-- Purpose: Implement Phase P5 of Database Remediation Plan.
--          1. Add historical and subsequent loan applications for existing customers (Customers 1, 2, and 3).
--          2. Create synthetic near-duplicate applicant profiles (matching name/phone and matching name/DOB).
--          3. Create rapid re-application duplicate test case for customer 2.
--          4. Ensure 100% idempotency, transaction safety, and sequence synchronization.
-- Author: AIWIZE Labs Remediation
-- Date: 2026-10-22

BEGIN;

-- 1. Multiple Applications for Existing Customer 1 (Aarav Sharma)
-- Current app: App #1 (2026-09-12, Disbursed, 200,000.00).
-- Adding a newer second application: 2026-10-15 (Pending, 500,000.00, Home loan).
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
SELECT 
    1, 
    1, 
    1, 
    2, 
    '2026-10-15', 
    500000.00, 
    'Pending', 
    'Home', 
    60, 
    'SYNTH: Home extension and renovation (Second Application)', 
    6680.00
WHERE NOT EXISTS (
    SELECT 1 FROM loan_applications 
    WHERE customer_id = 1 AND loan_purpose = 'SYNTH: Home extension and renovation (Second Application)'
);

-- 2. Multiple Applications for Existing Customer 2 (Priya Verma)
-- Current app: App #2 (2026-09-27, Approved, 150,000.00).
-- Adding an older previous application: 2026-08-15 (Rejected, 100,000.00, Personal loan - low initial score).
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
SELECT 
    2, 
    1, 
    1, 
    1, 
    '2026-08-15', 
    100000.00, 
    'Rejected', 
    'Personal', 
    12, 
    'SYNTH: Medical expense support (Historical Application 1)', 
    0.00
WHERE NOT EXISTS (
    SELECT 1 FROM loan_applications 
    WHERE customer_id = 2 AND loan_purpose = 'SYNTH: Medical expense support (Historical Application 1)'
);

-- Adding a rapid re-application on the same date at Branch 2 to test duplicate application detection:
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
SELECT 
    2, 
    2, 
    3, 
    1, 
    '2026-09-27', 
    150000.00, 
    'Rejected', 
    'Personal', 
    12, 
    'SYNTH: Duplicate application submitted same day to Branch 2', 
    0.00
WHERE NOT EXISTS (
    SELECT 1 FROM loan_applications 
    WHERE customer_id = 2 AND loan_purpose = 'SYNTH: Duplicate application submitted same day to Branch 2'
);

-- 3. Multiple Applications for Existing Customer 3 (Rahul Singh)
-- Current app: App #3 (2026-10-02, Pending, 2,500,000.00 Home Loan).
-- Adding an older application: 2026-06-20 (Approved, 75,000.00 Personal Loan).
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
SELECT 
    3, 
    2, 
    3, 
    1, 
    '2026-06-20', 
    75000.00, 
    'Approved', 
    'Personal', 
    12, 
    'SYNTH: Equipment purchase (Historical Application 1)', 
    0.00
WHERE NOT EXISTS (
    SELECT 1 FROM loan_applications 
    WHERE customer_id = 3 AND loan_purpose = 'SYNTH: Equipment purchase (Historical Application 1)'
);

-- Adding a recent application: 2026-10-22 (Pending, 120,000.00 Education Loan).
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
SELECT 
    3, 
    2, 
    null, 
    3, 
    '2026-10-22', 
    120000.00, 
    'Pending', 
    'Education', 
    24, 
    'SYNTH: Professional certification tuition (Recent Application 3)', 
    0.00
WHERE NOT EXISTS (
    SELECT 1 FROM loan_applications 
    WHERE customer_id = 3 AND loan_purpose = 'SYNTH: Professional certification tuition (Recent Application 3)'
);

-- 4. Near-Duplicate Applicant 1: Matching Name and Phone with Customer 1 (Aarav Sharma)
-- Shares exact full_name 'Aarav Sharma' and exact phone '9000000001'.
-- Has unique email 'aarav.sharma.alt@example.test' and unique synthetic PAN 'AAAPS1001B'.
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
    'Aarav Sharma', 
    'aarav.sharma.alt@example.test', 
    '9000000001', 
    '1995-04-12', 
    'Flat 402, Shanti Heights, Sector 15, Rohini, Delhi', 
    'AAAPS1001B', 
    720
)
ON CONFLICT (email) DO NOTHING;

-- Loan application for Near-Duplicate Customer 1
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
SELECT 
    c.customer_id, 
    1, 
    1, 
    1, 
    '2026-09-15', 
    200000.00, 
    'Rejected', 
    'Personal', 
    24, 
    'SYNTH: Near-duplicate applicant test application (Matching Phone)', 
    0.00
FROM customers c
WHERE c.email = 'aarav.sharma.alt@example.test'
  AND NOT EXISTS (
      SELECT 1 FROM loan_applications la 
      WHERE la.customer_id = c.customer_id 
        AND la.loan_purpose = 'SYNTH: Near-duplicate applicant test application (Matching Phone)'
  );

-- 5. Near-Duplicate Applicant 2: Matching Name and Date of Birth with Customer 4 (Neha Gupta)
-- Shares exact full_name 'Neha Gupta' and exact DOB '1997-11-05'.
-- Has unique email 'neha.gupta.work@example.test' and unique synthetic PAN 'DDDPG1004E'.
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
    'Neha Gupta', 
    'neha.gupta.work@example.test', 
    '+91 90000 00044', 
    '1997-11-05', 
    'B-104, Sunrise Apartments, Viman Nagar, Pune', 
    'DDDPG1004E', 
    590
)
ON CONFLICT (email) DO NOTHING;

-- Loan application for Near-Duplicate Customer 2
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
SELECT 
    c.customer_id, 
    2, 
    3, 
    1, 
    '2026-10-18', 
    300000.00, 
    'Pending', 
    'Personal', 
    36, 
    'SYNTH: Near-duplicate applicant test application (Matching DOB & Address)', 
    0.00
FROM customers c
WHERE c.email = 'neha.gupta.work@example.test'
  AND NOT EXISTS (
      SELECT 1 FROM loan_applications la 
      WHERE la.customer_id = c.customer_id 
        AND la.loan_purpose = 'SYNTH: Near-duplicate applicant test application (Matching DOB & Address)'
  );

-- 6. Synchronize identity sequences
SELECT setval(
    pg_get_serial_sequence('customers', 'customer_id'),
    COALESCE((SELECT MAX(customer_id) FROM customers), 1)
);

SELECT setval(
    pg_get_serial_sequence('loan_applications', 'application_id'),
    COALESCE((SELECT MAX(application_id) FROM loan_applications), 1)
);

COMMIT;
