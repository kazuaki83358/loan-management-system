const { Pool } = require('pg');
require('dotenv').config();
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

async function checkState() {
  const payments = await pool.query('SELECT * FROM payments ORDER BY payment_id');
  console.log('=== PAYMENTS ===');
  console.log(JSON.stringify(payments.rows, null, 2));

  const loanConstraints = await pool.query(`
    SELECT conname, pg_get_constraintdef(oid) as definition
    FROM pg_constraint
    WHERE conrelid = 'loans'::regclass
  `);
  console.log('=== LOANS CONSTRAINTS ===');
  console.log(JSON.stringify(loanConstraints.rows, null, 2));

  const emiConstraints = await pool.query(`
    SELECT conname, pg_get_constraintdef(oid) as definition
    FROM pg_constraint
    WHERE conrelid = 'emi_schedule'::regclass
  `);
  console.log('=== EMI_SCHEDULE CONSTRAINTS ===');
  console.log(JSON.stringify(emiConstraints.rows, null, 2));

  const disb = await pool.query('SELECT * FROM disbursements ORDER BY disbursement_id');
  console.log('=== DISBURSEMENTS ===');
  console.log(JSON.stringify(disb.rows, null, 2));

  const apps = await pool.query('SELECT application_id, customer_id, status, loan_type, loan_purpose FROM loan_applications ORDER BY application_id');
  console.log('=== APPLICATIONS SUMMARY ===');
  console.log(JSON.stringify(apps.rows, null, 2));

  await pool.end();
}
checkState();
