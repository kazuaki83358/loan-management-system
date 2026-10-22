const { Pool } = require('pg');
require('dotenv').config();
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

async function runP6() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // 1. Create Closed Loan Scenario
    const appCheck = await client.query("SELECT COUNT(*) as cnt FROM loan_applications WHERE loan_purpose = 'SYNTH: Closed loan lifecycle test - P6'");
    if (appCheck.rows[0].cnt === 0) {
      await client.query("INSERT INTO loan_applications (customer_id, branch_id, employee_id, policy_id, application_date, requested_amount, status, loan_type, requested_tenure_months, loan_purpose) VALUES (4, 2, 3, 1, '2025-01-10', 50000.00, 'Disbursed', 'Personal', 6, 'SYNTH: Closed loan lifecycle test - P6')");
    }
    
    const appResult = await client.query("SELECT application_id FROM loan_applications WHERE loan_purpose = 'SYNTH: Closed loan lifecycle test - P6'");
    const appId = appResult.rows[0].application_id;
    
    await client.query("INSERT INTO loans (application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status) VALUES ($1, 4, 50000.00, 12.00, 6, '2025-01-15', 'Closed')", [appId]);
    
    await client.query("INSERT INTO disbursements (loan_id, disbursement_date, amount, transaction_reference) SELECT loan_id, '2025-01-16', 50000.00, 'SYNTH-DISB-CLOSED-P6-001' FROM loans WHERE status = 'Closed'");
    
    await client.query("INSERT INTO emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status) SELECT l.loan_id, i, ('2025-01-15'::date + (i * interval '1 month'))::date, 8627.00, 8333.33, 293.67, 'Paid' FROM generate_series(1, 6) i CROSS JOIN loans l WHERE l.status = 'Closed' ON CONFLICT (loan_id, installment_number) DO NOTHING");
    
    // 2. Create Defaulted Loan Scenario
    const appCheck2 = await client.query("SELECT COUNT(*) as cnt FROM loan_applications WHERE loan_purpose = 'SYNTH: Defaulted loan lifecycle test - P6'");
    if (appCheck2.rows[0].cnt === 0) {
      await client.query("INSERT INTO loan_applications (customer_id, branch_id, employee_id, policy_id, application_date, requested_amount, status, loan_type, requested_tenure_months, loan_purpose) VALUES (3, 2, 3, 1, '2026-03-01', 100000.00, 'Disbursed', 'Personal', 12, 'SYNTH: Defaulted loan lifecycle test - P6')");
    }
    
    const appResult2 = await client.query("SELECT application_id FROM loan_applications WHERE loan_purpose = 'SYNTH: Defaulted loan lifecycle test - P6'");
    const appId2 = appResult2.rows[0].application_id;
    
    await client.query("INSERT INTO loans (application_id, customer_id, principal_amount, annual_interest_rate, tenure_months, loan_date, status) VALUES ($1, 3, 100000.00, 14.00, 12, '2026-03-05', 'Defaulted')", [appId2]);
    
    await client.query("INSERT INTO disbursements (loan_id, disbursement_date, amount, transaction_reference) SELECT loan_id, '2026-03-06', 100000.00, 'SYNTH-DISB-DEFAULT-P6-002' FROM loans WHERE status = 'Defaulted'");
    
    await client.query("INSERT INTO emi_schedule (loan_id, installment_number, due_date, emi_amount, principal_component, interest_component, status) SELECT l.loan_id, i, ('2026-03-05'::date + (i * interval '1 month'))::date, 8979.00, 7812.00, 1167.00, CASE WHEN i <= 2 THEN 'Paid' ELSE 'Overdue' END FROM generate_series(1, 6) i CROSS JOIN loans l WHERE l.status = 'Defaulted' ON CONFLICT (loan_id, installment_number) DO NOTHING");
    
    // Synchronize all identity sequences
    await client.query("SELECT setval(pg_get_serial_sequence('loan_applications', 'application_id'), COALESCE((SELECT MAX(application_id) FROM loan_applications), 1));");
    await client.query("SELECT setval(pg_get_serial_sequence('loans', 'loan_id'), COALESCE((SELECT MAX(loan_id) FROM loans), 1));");
    await client.query("SELECT setval(pg_get_serial_sequence('disbursements', 'disbursement_id'), COALESCE((SELECT MAX(disbursement_id) FROM disbursements), 1));");
    await client.query("SELECT setval(pg_get_serial_sequence('emi_schedule', 'emi_id'), COALESCE((SELECT MAX(emi_id) FROM emi_schedule), 1));");
    
    await client.query('COMMIT');
    console.log('P6 Migration completed successfully!');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('P6 Migration failed:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

runP6();