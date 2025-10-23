-- Migration: Add telefon and data_naixement columns to socis table
-- Created: 2025-10-23
-- Purpose: Store phone and birth date information for members from CSV uploads

ALTER TABLE public.socis
ADD COLUMN IF NOT EXISTS telefon text,
ADD COLUMN IF NOT EXISTS data_naixement date;

COMMENT ON COLUMN public.socis.telefon IS 'Telèfon de contacte del soci (preferiblement mòbil)';
COMMENT ON COLUMN public.socis.data_naixement IS 'Data de naixement del soci';
