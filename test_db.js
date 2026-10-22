const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

async function testConnection() {
  try {
    const res = await pool.query('SELECT NOW()');
    console.log('Connection Successful. Database Time:', res.rows[0].now);

    console.log('\n--- Inspecting Schema ---');
    const tables = await pool.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
    `);
    console.log('Tables found:', tables.rows.map(r => r.table_name).join(', '));

    const targetTables = ['customers', 'branches', 'employees', 'credit_policies', 'loan_applications', 'loans', 'emi_schedule', 'payments', 'disbursements'];
    for (const table of targetTables) {
      console.log(`\nColumns for ${table}:`);
      const cols = await pool.query(`
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = $1
      `, [table]);
      cols.rows.forEach(r => console.log(` - ${r.column_name} (${r.data_type})`));
    }
  } catch (err) {
    console.error('Connection Failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

testConnection();
