const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DB_PASSWORD,
});

async function run() {
  const client = await pool.connect();
  try {
    await client.query(`
      DROP POLICY IF EXISTS "Users can view accessible cases" ON public.cases;
      CREATE POLICY "Users can view accessible cases"
        ON public.cases FOR SELECT
        TO authenticated
        USING (
          created_by = auth.uid()
          OR assignee_id = auth.uid()
          OR public.devc_case_user_can_access_case(auth.uid(), id)
        );
    `);
    console.log('SELECT policy on cases updated successfully!');
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(console.error);
