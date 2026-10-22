-- Remediation Seed Script: Closed and Defaulted Loan Lifecycle Scenarios
-- Phase P6 Implementation
-- Author: AIWIZE Labs 
-- Date: 2026-10-22
-- Idempotent, transaction-safe implementation

BEGIN;

-- 1. Create Closed Loan Scenario (Loan #3)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM loan_applications WHERE loan_purpose = 'SYNTH: Closed loan lifecycle test - P6') THEN
    INSERT INTO loan_applications (
      customer_id, branch_id, employee_id, policy_id, application_date,
      requested_amount, status, loan_type, requested_tenure_months, loan_purpose
    ) VALUES (4, 2, 3, 1, '2025-01-10', 50000.00, 'Disbursed', 'Personal', 6, 'SYNTH: Closed loan lifecycle test - P6');
  END IF;
END $$;

-- Check closed loan was created
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM loan_applications WHERE loan_purpose = 'SYNTH: Closed loan lifecycle test - P6') THEN
    -- Create loan with Closed status
    INSERT INTO loans (application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status)
    SELECT application_id, 4, 50000.00, 12.00, 6, '2025-01-15', 'Closed'
    FROM loan_applications WHERE loan_purpose = 'SYNTH: Closed loan lifecycle test - P6'
    ON CONFLICT (application_id) DO NOTHING;
  END IF;
END $$;

-- Create disbursement for closed loan
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM loans WHERE status = 'Closed') THEN
    INSERT INTO disbursements (loan_id, disbursement_date, amount, transaction_reference)
    SELECT loan_id, '2025-01-16', 50000.00, 'SYNTH-DISB-CLOSED-P6-001'
    FROM loans WHERE status = 'Closed'
    ON CONFLICT (transaction_reference) DO NOTHING;
  END IF;
END $$;

-- Generate 6 paid installments for closed loan
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM loans WHERE status = 'Closed') THEN
    INSERT INTO emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status)
    SELECT l.loan_id, i, ('2025-01-15'::date + (i * interval '1 month'))::date,
      8627.00, 8333.33, 293.67, 'Paid'
    FROM loans l CROSS JOIN generate_series(1, 6) i
    WHERE l.status = 'Closed'
    ON CONFLICT (loan_id, installment_number) DO NOTHING;
  END IF;
END $$;

-- 2. Create Defaulted Loan Scenario (Loan #4)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM loan_applications WHERE loan_purpose = 'SYNTH: Defaulted loan lifecycle test - P6') THEN
    INSERT INTO loan_applications (
      customer_id, branch_id, employee_id, policy_id, application_date,
      requested_amount, status, loan_type, requested_tenure_months, loan_purpose
    ) VALUES (3, 2, 3, 1, '2026-03-01', 100000.00, 'Disbursed', 'Personal', 12, 'SYNTH: Defaulted loan lifecycle test - P6');
  END IF;
END $$;

-- Check defaulted loan was created
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM loan_applications WHERE loan_purpose = 'SYNTH: Defaulted loan lifecycle test - P6') THEN
    -- Create loan with Defaulted status
    INSERT INTO loans (application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status)
    SELECT application_id, 3, 100000.00, 14.00, 12, '2026-03-05', 'Defaulted'
    FROM loan_applications WHERE loan_purpose = 'SYNTH: Defaulted loan lifecycle test - P6'
    ON CONFLICT (application_id) DO NOTHING;
  END IF;
END $$;

-- Create disbursement for defaulted loan
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM loans WHERE status = 'Defaulted') THEN
    INSERT INTO disbursements (loan_id, disbursement_date, amount, transaction_reference)
    SELECT loan_id, '2026-03-06', 100000.00, 'SYNTH-DISB-DEFAULT-P6-002'
    FROM loans WHERE status = 'Defaulted'
    ON CONFLICT (transaction_reference) DO NOTHING;
  END IF;
END $$;

-- Generate 6 installments: 2 Paid + 4 Overdue
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM loans WHERE status = 'Defaulted') THEN
    INSERT INTO emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status)
    SELECT l.loan_id, i, ('2026-03-05'::date + (i * interval '1 month'))::date,
      8979.00, 7812.00, 1167.00,
      CASE WHEN i <= 2 THEN 'Paid' ELSE 'Overdue' END
    FROM loans l CROSS JOIN generate_series(1, 6) i
    WHERE l.status = 'Defaulted'
    ON CONFLICT (loan_id, installment_number) DO NOTHING;
  END IF;
END $$;

-- Synchronize all identity sequences
SELECT setval(pg_get_serial_sequence('loan_applications', 'application_id'), COALESCE((SELECT MAX(application_id) FROM loan_applications), 1));
SELECT setval(pg_get_serial_sequence('loans', 'loan_id'), COALESCE((SELECT MAX(loan_id) FROM loans), 1));
SELECT setval(pg_get_serial_sequence('disbursements', 'disbursement_id'), COALESCE((SELECT MAX(disbursement_id) FROM disbursements), 1));
SELECT setval(pg_get_serial_sequence('emi_schedule', 'emi_id'), COALESCE((SELECT MAX(emi_id) FROM emi_schedule), 1));

COMMIT;