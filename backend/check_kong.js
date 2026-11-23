const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DB_PASSWORD,
});

async function run() {
  const client = await pool.connect();
  try {
    const res = await client.query(`
      SELECT u.id as auth_id, u.email, p.id as profile_id, p.full_name, p.is_active, p.role, p.team_id
      FROM auth.users u
      LEFT JOIN public.profiles p ON u.id = p.id;
    `);
    console.log('All users in DB:', res.rows);
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(console.error);
