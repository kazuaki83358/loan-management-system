const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT || 5432,
});

async function inspectSchema() {
  try {
    console.log('--- Database Schema Inspection ---\n');

    const tables = ['customers', 'branches', 'employees', 'credit_policies', 'loan_applications', 'loans', 'emi_schedule', 'payments', 'disbursements'];

    for (const table of tables) {
      console.log(`Table: ${table}`);
      const res = await pool.query(`
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position;
      `, [table]);

      res.rows.forEach(row => {
        console.log(`  - ${row.column_name} [${row.data_type}] Nullable: ${row.is_nullable} Default: ${row.column_default}`);
      });
      console.log('');
    }

    const constraints = await pool.query(`
      SELECT tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name
      FROM information_schema.table_constraints AS tc
      JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
      JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
      WHERE tc.constraint_type = 'FOREIGN KEY';
    `);
    console.log('--- Foreign Key Constraints ---');
    constraints.rows.forEach(row => {
      console.log(`${row.table_name}.${row.column_name} -> ${row.foreign_table_name}.${row.foreign_column_name}`);
    });

  } catch (err) {
    console.error('Inspection failed:', err.message);
  } finally {
    await pool.end();
  }
}

inspectSchema();
