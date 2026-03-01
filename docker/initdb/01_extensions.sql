-- =============================================================
-- pgr_dmmsy Docker initialisation
-- Executed automatically by the postgres entrypoint on first start.
-- =============================================================

-- PostGIS is required by pgRouting (declared dependency in pgrouting.control).
CREATE EXTENSION IF NOT EXISTS postgis;

-- pgRouting requires postgis and must be loaded before pgr_dmmsy.
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- Load the DMMSY extension.
CREATE EXTENSION IF NOT EXISTS pgr_dmmsy;
