#!/usr/bin/env node

/**
 * Script to apply SQL migrations to Supabase database
 * Usage: node scripts/apply-migration.js <migration-file-path>
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Get migration file path from command line
const migrationFile = process.argv[2];

if (!migrationFile) {
  console.error('Error: Please provide a migration file path');
  console.error('Usage: node scripts/apply-migration.js <migration-file-path>');
  process.exit(1);
}

// Load environment variables
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Error: Missing Supabase credentials');
  console.error('Please set PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables');
  process.exit(1);
}

// Create Supabase client with service role key
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function applyMigration() {
  try {
    // Read migration file
    const migrationPath = resolve(migrationFile);
    console.log(`Reading migration file: ${migrationPath}`);
    const sql = readFileSync(migrationPath, 'utf8');

    console.log(`Applying migration...`);

    // Execute SQL using rpc (note: this requires a custom function on the DB)
    // Since Supabase doesn't have a direct SQL execution endpoint, we'll use the REST API
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`
      },
      body: JSON.stringify({ query: sql })
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Failed to apply migration: ${error}`);
    }

    console.log('Migration applied successfully!');

  } catch (error) {
    console.error('Error applying migration:', error.message);
    process.exit(1);
  }
}

applyMigration();
