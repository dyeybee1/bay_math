-- =============================================================================
-- Migration: 0002_enums.sql
-- Source: Phase 2 schema §2 (Enumerations).
--
-- content_share_type is defined here for completeness/documentation but its
-- owning table (content_shares) is explicitly out of Phase 2/3 build scope
-- (schema doc §3.21: "reserved — not implemented this phase"). Defining the
-- enum now costs nothing and avoids a naming collision later; no table uses
-- it yet.
--
-- audit_logs.action is deliberately NOT an enum here — see schema §9,
-- Recommendation 3 (confirmed): the action catalog is expected to grow and
-- is validated at the application layer instead of via a rigid Postgres type.
-- =============================================================================

create type profile_role as enum ('admin', 'teacher');

create type profile_status as enum ('pending', 'approved', 'rejected', 'suspended');

create type school_year_status as enum ('active', 'closed');

create type grade_level as enum ('grade_4', 'grade_5', 'grade_6');

create type section_status as enum ('active', 'archived');

create type enrollment_status as enum ('active', 'transferred', 'completed');

create type content_source_type as enum ('built_in', 'teacher');

create type lesson_progress_status as enum ('not_started', 'in_progress', 'completed');

create type quiz_type as enum ('internal', 'external_activity');

create type external_platform_hint as enum (
  'google_forms', 'microsoft_forms', 'youtube', 'khan_academy',
  'geogebra', 'desmos', 'pdf', 'other'
);

create type quiz_attempt_status as enum ('active', 'superseded');

create type audit_actor_role as enum ('admin', 'teacher', 'system');

-- Reserved for the future content_shares table (schema §3.21) — not used by
-- any table created in this migration set.
create type content_share_type as enum ('lesson', 'quiz');
