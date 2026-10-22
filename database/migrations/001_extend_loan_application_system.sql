-- Migration: 001_extend_loan_application_system.sql
-- Purpose: Extend customer profiles and loan application details for professional loan processing.
-- Version: 1.2 (Final Correction)

BEGIN;

-- 1. Add residential address to customers
-- Actual type of customers.customer_id is 'integer'.
ALTER TABLE customers
ADD COLUMN IF NOT EXISTS residential_address TEXT;

-- 2. Create customer_employment table
-- Employment Model: One current employment profile per customer.
-- We use a UNIQUE constraint on customer_id to ensure a 1:1 relationship for the current profile.
-- Changed to ON DELETE RESTRICT to resolve conflict with NOT NULL customer_id.
CREATE TABLE IF NOT EXISTS customer_employment (
    employment_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL UNIQUE,
    employment_type VARCHAR(50) NOT NULL CHECK (employment_type IN ('Salaried', 'Self-employed', 'Student', 'Unemployed')),
    employer_name VARCHAR(255),
    monthly_income NUMERIC(15, 2) NOT NULL CHECK (monthly_income >= 0),
    years_of_experience INTEGER CHECK (years_of_experience >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_employment_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT
);

-- 3. Extend loan_applications table
-- Loan types match the frontend dropdown: 'Personal', 'Home', 'Education', 'Vehicle', 'Business'.
ALTER TABLE loan_applications
ADD COLUMN IF NOT EXISTS loan_type VARCHAR(50) CHECK (loan_type IN ('Personal', 'Home', 'Education', 'Vehicle', 'Business')),
ADD COLUMN IF NOT EXISTS requested_tenure_months INTEGER CHECK (requested_tenure_months > 0),
ADD COLUMN IF NOT EXISTS loan_purpose TEXT,
ADD COLUMN IF NOT EXISTS existing_monthly_emi NUMERIC(15, 2) DEFAULT 0 CHECK (existing_monthly_emi >= 0);

-- Indexing for performance
CREATE INDEX IF NOT EXISTS idx_employment_customer ON customer_employment(customer_id);
CREATE INDEX IF NOT EXISTS idx_loan_apps_customer ON loan_applications(customer_id);

COMMIT;

/*
REVISION NOTES:

1. CONFLICT RESOLUTION:
   - Fixed the conflict between 'customer_id INTEGER NOT NULL' and 'ON DELETE SET NULL'.
   - A column cannot be 'NOT NULL' and 'SET NULL' simultaneously.
   - Implementation: Changed to 'ON DELETE RESTRICT'. This prevents a customer from being deleted if they have an associated employment profile, ensuring data integrity and preventing orphan records.

2. DATA TYPE COMPATIBILITY:
   - Verified 'customers.customer_id' is 'integer'. 'customer_employment.customer_id' matches.

3. EMPLOYMENT MODEL:
   - Single Current Profile: UNIQUE constraint on 'customer_id' ensures 1:1 mapping.

4. FIELD MATCHING:
   - 'employment_type' and 'loan_type' match frontend form options exactly.

5. BACKWARD COMPATIBILITY:
   - Use of 'IF NOT EXISTS' for all structural changes.
   - New columns in existing tables are nullable or have defaults (DEFAULT 0 for EMI), preserving existing rows.
   - No 'DROP', 'TRUNCATE', or 'UPDATE' statements used on existing data.
*/
