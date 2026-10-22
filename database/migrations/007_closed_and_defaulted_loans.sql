-- Remediation Seed Script: Closed and Defaulted Loan Lifecycle Scenarios
-- Phase P6 Implementation

BEGIN;

-- 1. Create a Closed Loan Scenario (Loan #3: Fully paid off)
-- Step A: Approved application for Customer 4 (Neha Gupta)
-- Using a temporary table to capture the generated application_id
CREATE TEMP TABLE temp_app_closed AS
INSERT INTO loan_applications (
    customer_id, branch_id, employee_id, policy_id, application_date,
    requested_amount, status, loan_type, requested_tenure_months, loan_purpose
)
VALUES (
    4, 2, 3, 1, '2025-01-10', 50000.00, 'Disbursed', 'Personal', 6, 'SYNTH: Closed loan test'
)
RETURNING application_id;

-- Step B: Loan record with status 'Closed'
CREATE TEMP TABLE temp_loan_closed AS
INSERT INTO loans (
    application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status
)
SELECT
    application_id, 4, 50000.00, 12.00, 6, '2025-01-15', 'Closed'
FROM temp_app_closed
RETURNING loan_id;

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
CREATE TEMP TABLE temp_app_default AS
INSERT INTO loan_applications (
    customer_id, branch_id, employee_id, policy_id, application_date,
    requested_amount, status, loan_type, requested_tenure_months, loan_purpose
)
VALUES (
    3, 2, 3, 1, '2026-03-01', 100000.00, 'Disbursed', 'Personal', 12, 'SYNTH: Defaulted loan test'
)
RETURNING application_id;

-- Step B: Loan record with status 'Defaulted'
CREATE TEMP TABLE temp_loan_default AS
INSERT INTO loans (
    application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status
)
SELECT
    application_id, 3, 100000.00, 14.00, 12, '2026-03-05', 'Defaulted'
FROM temp_app_default
RETURNING loan_id;

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
