-- Migration: 002_add_foreign_key_and_performance_indexes.sql
-- Purpose: Implement Phase P1 of Database Remediation Plan.
--          1. Add missing foreign key indexes to optimize joins and prevent table-level locks.
--          2. Add composite filter indexes for application and EMI queries.
--          3. Remove proven redundant index idx_employment_customer.
-- Author: AIWIZE Labs Remediation
-- Date: 2026-10-22

BEGIN;

-- 1. Foreign Key Performance Indexes
-- Index for employees -> branches(branch_id)
CREATE INDEX IF NOT EXISTS idx_employees_branch_id 
    ON employees(branch_id);

-- Index for loan_applications -> branches(branch_id)
CREATE INDEX IF NOT EXISTS idx_loan_applications_branch_id 
    ON loan_applications(branch_id);

-- Partial index for loan_applications -> employees(employee_id) (nullable FK)
CREATE INDEX IF NOT EXISTS idx_loan_applications_employee_id 
    ON loan_applications(employee_id) 
    WHERE employee_id IS NOT NULL;

-- Partial index for loan_applications -> credit_policies(policy_id) (nullable FK)
CREATE INDEX IF NOT EXISTS idx_loan_applications_policy_id 
    ON loan_applications(policy_id) 
    WHERE policy_id IS NOT NULL;

-- Index for loans -> customers(customer_id)
CREATE INDEX IF NOT EXISTS idx_loans_customer_id 
    ON loans(customer_id);

-- Index for payments -> emi_schedule(emi_id)
CREATE INDEX IF NOT EXISTS idx_payments_emi_id 
    ON payments(emi_id);

-- 2. Query Optimization Composite Indexes for Level 1/2 Filters
-- Composite index for filtering applications by status and date
CREATE INDEX IF NOT EXISTS idx_loan_applications_status_date 
    ON loan_applications(status, application_date DESC);

-- Composite index for overdue EMI queries and aging
CREATE INDEX IF NOT EXISTS idx_emi_schedule_status_due_date 
    ON emi_schedule(status, due_date);

-- 3. Redundant Index Cleanup
-- Proven redundancy: customer_employment.customer_id is already covered by the UNIQUE
-- B-tree index 'customer_employment_customer_id_key'. Dropping 'idx_employment_customer'
-- eliminates write amplification and duplicate index maintenance without affecting read capability.
DROP INDEX IF EXISTS idx_employment_customer;

COMMIT;
