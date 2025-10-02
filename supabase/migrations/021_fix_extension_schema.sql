    -- Migration to fix Extension in Public schema warning
    -- Moves btree_gist extension from public to extensions schema
    -- Created: 2025-10-02

    -- Create extensions schema if it doesn't exist
    CREATE SCHEMA IF NOT EXISTS extensions;

    -- Move btree_gist extension to extensions schema
    -- Note: This requires recreating the extension
    DROP EXTENSION IF EXISTS btree_gist CASCADE;
    CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA extensions;

    -- Add comment for documentation
    COMMENT ON SCHEMA extensions IS 'Schema per extensions PostgreSQL - Migration 021';