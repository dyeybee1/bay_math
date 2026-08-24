-- =============================================================================
-- Migration: 0001_extensions_and_schema.sql
-- Phase 3 — SQL Implementation, derived from the APPROVED Phase 2 schema
-- (docs/architecture/phase-2-database-schema-design.md).
--
-- Purpose: required extensions, and a private helper schema for RLS support
-- functions that must never be exposed via the PostgREST API.
-- =============================================================================

-- gen_random_uuid() — used as the default for every surrogate primary key
-- (Phase 2 §0: "every table uses a surrogate id (UUID), generated server-side").
create extension if not exists pgcrypto;

-- Private schema for RLS helper functions (role/section lookups) and any
-- SECURITY DEFINER logic that must not be directly callable via the REST API.
-- Supabase's PostgREST layer only exposes schemas explicitly configured for
-- API access (by default: public, graphql_public) — `app` is intentionally
-- left out of that list, so nothing here is reachable except through calls
-- made from within Postgres itself (RLS policies, triggers, other functions).
create schema if not exists app;

comment on schema app is
  'Private helper schema: RLS support functions and internal logic. '
  'Not exposed via the Supabase API — do not add this schema to the API '
  'schema exposure list.';
