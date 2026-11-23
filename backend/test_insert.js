const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DB_PASSWORD,
});

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Simulate authenticated user kong (427659a8-19fc-4e88-be74-32f5a58fa862)
    await client.query(`SET LOCAL role = 'authenticated';`);
    await client.query(`SELECT set_config('request.jwt.claim.sub', '427659a8-19fc-4e88-be74-32f5a58fa862', true);`);

    // Check profile
    const profileRes = await client.query(`SELECT id, role, is_active, team_id FROM public.profiles WHERE id = auth.uid();`);
    console.log('Profile via auth.uid():', profileRes.rows);

    // Try insert into cases
    const insertRes = await client.query(`
      INSERT INTO public.cases (
        title, priority, status, team_id, category, created_by
      ) VALUES (
        'Test Diagnostic Case', 'medium', 'open', 'cf4ae5f9-b455-4d42-9516-77b5cf41aa67', 'UI/UX', '427659a8-19fc-4e88-be74-32f5a58fa862'
      ) RETURNING *;
    `);
    console.log('Insert success:', insertRes.rows);

    await client.query('ROLLBACK');
  } catch (err) {
    console.error('Insert failed with error:', err.message);
    console.error('Error detail:', err.detail);
    console.error('Error hint:', err.hint);
    console.error('Error code:', err.code);
    await client.query('ROLLBACK');
  } finally {
    client.release();
    await pool.end();
  }
}

run();
