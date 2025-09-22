-- ===============================================
-- FIX EXTENSION IN PUBLIC SCHEMA
-- ===============================================
-- Moves btree_gist extension from public to extensions schema

-- Create extensions schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;

-- Move the btree_gist extension to extensions schema
-- Note: This requires superuser privileges in PostgreSQL
-- You may need to run this with elevated permissions

-- First, create extension in the new schema
-- (This will fail if extension already exists, but that's expected)
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA extensions;

-- Drop from public schema (this may require CASCADE if there are dependencies)
DROP EXTENSION IF EXISTS btree_gist CASCADE;

-- Recreate in extensions schema
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA extensions;

-- Grant usage on extensions schema to necessary roles
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT USAGE ON SCHEMA extensions TO anon;

-- Verification: Check extension location
SELECT 
    e.extname as extension_name,
    n.nspname as schema_name,
    CASE 
        WHEN n.nspname = 'public' THEN 'STILL IN PUBLIC - SECURITY RISK'
        ELSE 'PROPERLY LOCATED'
    END as status
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE e.extname = 'btree_gist';

-- List all extensions and their schemas
SELECT 
    e.extname as extension_name,
    n.nspname as schema_name
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY e.extname;