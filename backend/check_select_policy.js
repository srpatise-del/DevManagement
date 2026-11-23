const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DB_PASSWORD,
});

async function run() {
  const client = await pool.connect();
  try {
    const res = await client.query(`
      SELECT policyname, cmd, qual, with_check
      FROM pg_policies
      WHERE tablename = 'cases';
    `);
    console.log('All cases policies:', res.rows);

    const funcRes = await client.query(`
      SELECT proname, prosrc
      FROM pg_proc
      WHERE proname LIKE '%view_case%';
    `);
    console.log('Function definition:', funcRes.rows);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
