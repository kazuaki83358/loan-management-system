-- Migration: 005_overdue_and_partial_payment_scenarios.sql
-- Purpose: Implement Phase P4 of Database Remediation Plan.
--          1. Mark Loan 2, Installment 1 as 'Overdue' (unpaid, due_date < CURRENT_DATE).
--          2. Create a multiple-payment scenario completing Loan 1, Installment 2 in full ('Paid').
--          3. Create a single partial-payment scenario for Loan 1, Installment 3 ('Partially Paid').
--          4. Create a multiple partial-payment scenario for Loan 2, Installment 2 ('Partially Paid').
--          5. Ensure 100% transaction safety, idempotency via unique transaction references, and sequence synchronization.
-- Author: AIWIZE Labs Remediation
-- Date: 2026-10-22

BEGIN;

-- 1. Scenario 1: Overdue Unpaid EMI (Loan 2, Installment 1)
-- Due date 2026-10-17 is in the past relative to current date (2026-10-22).
-- Zero payments recorded; balance remaining is full 8,000.00.
UPDATE emi_schedule 
SET status = 'Overdue' 
WHERE emi_id = 4 
  AND loan_id = 2 
  AND installment_number = 1 
  AND due_date < CURRENT_DATE;

-- 2. Scenario 2: Multiple Payments Completing an EMI in Full (Loan 1, Installment 2)
-- emi_amount = 6680.00, due_date = 2026-11-11.
-- Payment 1: 3,000.00 via Net Banking on 2026-10-18
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    2, 
    '2026-10-18', 
    3000.00, 
    'Net Banking', 
    'SYNTH-PAY-L1-INST2-PART1'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Payment 2: 3,680.00 via UPI on 2026-10-21 (completes 6,680.00)
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    2, 
    '2026-10-21', 
    3680.00, 
    'UPI', 
    'SYNTH-PAY-L1-INST2-PART2'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Set status to 'Paid' because total payments (3000 + 3680 = 6680.00) equal required emi_amount
UPDATE emi_schedule 
SET status = 'Paid' 
WHERE emi_id = 2 
  AND (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE emi_id = 2) >= emi_amount;

-- 3. Scenario 3: Single Partial-Payment Scenario (Loan 1, Installment 3)
-- emi_amount = 6680.00, due_date = 2026-12-11.
-- Payment of 2,500.00 via Cheque on 2026-10-22 (remaining balance: 4,180.00)
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
    'SYNTH-PAY-L1-INST3-PARTIAL'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Set status to 'Partially Paid' because payments (2500.00) are strictly less than emi_amount (6680.00)
UPDATE emi_schedule 
SET status = 'Partially Paid' 
WHERE emi_id = 3 
  AND (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE emi_id = 3) < emi_amount;

-- 4. Scenario 4: Multiple Partial-Payment Scenario (Loan 2, Installment 2)
-- emi_amount = 8000.00, due_date = 2026-11-16.
-- Payment A: 2,000.00 via UPI on 2026-10-19
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    5, 
    '2026-10-19', 
    2000.00, 
    'UPI', 
    'SYNTH-PAY-L2-INST2-PART1'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Payment B: 1,500.00 via UPI on 2026-10-21 (total 3,500.00; remaining balance: 4,500.00)
INSERT INTO payments (
    emi_id, 
    payment_date, 
    amount, 
    payment_method, 
    transaction_reference
)
VALUES (
    5, 
    '2026-10-21', 
    1500.00, 
    'UPI', 
    'SYNTH-PAY-L2-INST2-PART2'
)
ON CONFLICT (transaction_reference) DO NOTHING;

-- Set status to 'Partially Paid' because payments (3500.00) are strictly less than emi_amount (8000.00)
UPDATE emi_schedule 
SET status = 'Partially Paid' 
WHERE emi_id = 5 
  AND (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE emi_id = 5) < emi_amount;

-- 5. Synchronize payments identity sequence
SELECT setval(
    pg_get_serial_sequence('payments', 'payment_id'),
    COALESCE((SELECT MAX(payment_id) FROM payments), 1)
);

COMMIT;
