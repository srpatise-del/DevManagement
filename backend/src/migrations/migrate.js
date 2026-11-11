const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');

async function runMigration() {
  const sqlPath = path.join(__dirname, 'init.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');

  try {
    console.log('Running database migration...');
    await pool.query(sql);
    console.log('Database migration completed successfully.');
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await pool.end();
  }
}

runMigration();
