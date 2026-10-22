-- Remediation Migration: P7 Financial Integrity Improvements
-- Ensures mathematical consistency and domain validation

BEGIN;

-- 1. EMI Component Integrity
-- Ensures emi_amount is always the sum of principal and interest components
ALTER TABLE emi_schedule
ADD CONSTRAINT emi_schedule_components_sum_check
    CHECK (emi_amount = (principal_component + interest_component));

-- 2. Payment Amount & Method Validation
-- Ensure payments are positive and use standard banking methods
ALTER TABLE payments
ADD CONSTRAINT payments_amount_positive_check
    CHECK (amount > 0);

ALTER TABLE payments
ADD CONSTRAINT payments_payment_method_check
    CHECK (payment_method IN ('UPI', 'NEFT', 'RTGS', 'Cheque', 'Cash', 'Debit Card', 'Net Banking'));

-- 3. Customer Data Validation
-- Ensure credit score is within valid bureau ranges (if not null)
ALTER TABLE customers
ADD CONSTRAINT customers_credit_score_range_check
    CHECK (credit_score IS NULL OR (credit_score BETWEEN 300 AND 900));

-- 4. PAN Format Validation
-- Ensures all PANs follow the standard Indian format: 5 letters, 4 digits, 1 letter
ALTER TABLE customers
ADD CONSTRAINT customers_pan_format_check
    CHECK (pan_number IS NULL OR pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

COMMIT;
