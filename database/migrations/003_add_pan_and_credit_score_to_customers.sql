-- Migration: 003_add_pan_and_credit_score_to_customers.sql
-- Purpose: Implement Phase P2 of Database Remediation Plan.
--          1. Add pan_number and credit_score columns to customers (nullable).
--          2. Add domain CHECK constraints for PAN format and credit score range (allowing NULL).
--          3. Create unique partial index on non-null pan_number.
--          4. Populate synthetic test values for existing customers.
-- Author: AIWIZE Labs Remediation
-- Date: 2026-10-22

BEGIN;

-- 1. Add columns as nullable
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS pan_number VARCHAR(10),
ADD COLUMN IF NOT EXISTS credit_score INTEGER;

-- 2. Add domain constraints (both permit NULL for backward compatibility)
ALTER TABLE customers 
DROP CONSTRAINT IF EXISTS customers_credit_score_check,
ADD CONSTRAINT customers_credit_score_check 
    CHECK (credit_score IS NULL OR (credit_score >= 300 AND credit_score <= 900)),
DROP CONSTRAINT IF EXISTS customers_pan_format_check,
ADD CONSTRAINT customers_pan_format_check 
    CHECK (pan_number IS NULL OR pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

-- 3. Enforce uniqueness on non-null PANs
CREATE UNIQUE INDEX IF NOT EXISTS customers_pan_number_key 
    ON customers(pan_number) 
    WHERE pan_number IS NOT NULL;

-- 4. Populate synthetic test values for existing test customers
UPDATE customers SET pan_number = 'AAAPS1001A', credit_score = 720 WHERE customer_id = 1 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'BBBPV1002B', credit_score = 680 WHERE customer_id = 2 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'CCCPS1003C', credit_score = 610 WHERE customer_id = 3 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'DDDPG1004D', credit_score = 590 WHERE customer_id = 4 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'EEEPP1005E', credit_score = 750 WHERE customer_id = 5 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'FFFQA1006F', credit_score = 710 WHERE customer_id = 6 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'GGGFR1007G', credit_score = 730 WHERE customer_id = 7 AND pan_number IS NULL;
UPDATE customers SET pan_number = 'HHHNK1008H', credit_score = 780 WHERE customer_id = 8 AND pan_number IS NULL;

COMMIT;
