require('dotenv').config({ path: '.env.cloud' });
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function createSocialLeagueClassificationsFunction() {
  const client = new Client({
    host: process.env.PGHOST,
    port: process.env.PGPORT || 5432,
    database: process.env.PGDATABASE,
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('🔗 Connecting to Supabase database...');
    await client.connect();
    console.log('✅ Connected successfully!');

    // Read the SQL function
    const sqlPath = path.join(__dirname, 'create-get-social-league-classifications-function.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('📝 Creating get_social_league_classifications function...');
    await client.query(sql);
    console.log('✅ Function created successfully!');

    // Test the function with a sample call
    console.log('🧪 Testing function...');
    const testResult = await client.query(`
      SELECT * FROM get_social_league_classifications($1) LIMIT 5;
    `, ['8a81a82e-96c9-4c49-9fbe-b492394462ac']);

    console.log('✅ Function test successful!');
    console.log('📊 Sample results:', JSON.stringify(testResult.rows, null, 2));

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await client.end();
    console.log('🔌 Database connection closed');
  }
}

createSocialLeagueClassificationsFunction();