-- =============================================================================
-- Migration: 0055_bulk_create_students.sql
-- (Renumbered from an earlier 0049 draft — 0049 was already taken by
-- another migration in this project; this file's content and every
-- decision documented below are otherwise unchanged by the renumbering.)
--
-- Adds a database-side BULK counterpart to app.create_student /
-- public.create_student (0017 / 0020). The existing single-student
-- functions are NOT modified, replaced, or called by this migration — this
-- is a completely separate pair of functions that happens to reuse the same
-- helpers, encryption pattern, and authorization checks.
--
--   public.create_students_bulk(...)   -- PostgREST-reachable wrapper
--       -> app.create_students_bulk(...)  -- actual implementation
--
-- Mirrors the existing architecture exactly:
--   Flutter -> Edge Function (holds STUDENT_CREDENTIALS_ENCRYPTION_KEY,
--   generates each plaintext temp password, forwards the caller's OWN JWT —
--   never service_role) -> public.create_students_bulk -> app.create_students_bulk
--
-- WHAT THIS MIGRATION DOES NOT DO (by design, per the approved scope):
--   - Does not touch app.create_student / public.create_student.
--   - Does not add student_number support (first version omits it, but the
--     input/insert shape below leaves room to add it later without a
--     redesign — see "STUDENT NUMBER" note further down).
--   - Does not add a batch-level audit_logs row/schema — every successful
--     student still gets exactly one 'student_created' audit event, the
--     same action name the single-student path already uses, so existing
--     audit tooling/queries keep working unchanged. The metadata for each
--     event additionally carries "bulk": true so bulk-created accounts are
--     distinguishable after the fact without a schema change.
--
-- NOT COMPILER-VERIFIED AGAINST A LIVE DATABASE: I do not have a Postgres
-- instance available in this session to actually run this migration. It is
-- written by close inspection of the real schema/functions supplied in this
-- project (0006, 0013, 0016, 0017, 0020, 0021, 0048), not by executing it.
--
-- CONSTRAINT NAME — NOT HARDCODED: 0006 defines "username text not null
-- unique" as an inline column constraint, and no migration in the supplied
-- project (checked: every file under supabase/migrations that mentions
-- "username") ever gives that constraint an explicit name via ALTER TABLE
-- ... ADD CONSTRAINT. That means Postgres's default auto-generated name
-- ("students_username_key", following its "<table>_<column>_key"
-- convention) is very likely correct, but it is NOT something the supplied
-- project itself states anywhere — writing it in as a literal would be
-- exactly the kind of unverified assumption this migration must not
-- contain. Instead, app.create_students_bulk below looks the constraint
-- name up itself at the start of every call, from information_schema,
-- by asking Postgres directly which UNIQUE constraint(s) on
-- public.students cover exactly the username column, explicitly aborting
-- if that comes back with zero or more than one match — see "USERNAME
-- CONCURRENCY" further down for the exact query and both abort cases.
-- This makes the migration self-contained and correct even if the
-- constraint is ever renamed later, with no manual verification step
-- required.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- app.create_students_bulk
--
-- Creates multiple students, all into ONE target section, in a single call.
-- Per input student: a students row + an active student_enrollments row +
-- a 'student_created' audit_logs event, exactly like app.create_student
-- creates for one student — just looped, with per-student isolation.
--
-- AUTHORIZATION: checked ONCE for the whole call, against the target
-- section, using the exact same helpers app.create_student already uses
-- (app.is_admin() / app.is_approved_teacher() + app.teacher_has_section()).
-- There is only one section for the whole batch, so there is nothing to
-- re-check per student. No new authorization mechanism is introduced.
--
-- ENCRYPTION: identical to app.create_student — pgp_sym_encrypt(password,
-- p_encryption_key), stored in students.password_encrypted. The plaintext
-- password is never persisted and never included in this function's
-- result. The encryption key is a call parameter only (per 0017's
-- established pattern: sourced from the Edge Function's own environment
-- secret), never stored, never echoed back.
--
-- USERNAME GENERATION:
--   1. Trim leading/trailing whitespace, lowercase.
--   2. Strip everything that is not classified as alphanumeric or
--      whitespace by Postgres's [:alnum:]/[:space:] POSIX bracket
--      character classes (covers punctuation and the common name
--      separators: hyphens, apostrophes, commas, periods). These classes
--      are locale-aware rather than hardcoded to ASCII, so under a
--      typical UTF8 database locale they do treat common accented Latin
--      letters as alphanumeric (see the diacritics note below) — but
--      exactly which characters they classify as alphanumeric/whitespace
--      is ultimately governed by the database server's locale/collation
--      configuration (LC_CTYPE, or the ICU provider if one is in use),
--      which is not something this migration controls or can guarantee
--      is identical across every PostgreSQL environment. This is a
--      statement about how Postgres's character classification actually
--      behaves, not a claim of full, environment-independent Unicode
--      support.
--   3. Collapse repeated whitespace to single spaces.
--   4. Split on spaces. First token = first-name part. All remaining
--      tokens are concatenated together (no separator) as the last-name
--      part. "Juan Dela Cruz" -> ["juan", "dela", "cruz"] -> base username
--      "juan.delacruz". A single-token name (e.g. "Cher") has no dot:
--      base username "cher".
--   5. If nothing usable survives normalization (e.g. the input was only
--      punctuation), that student is recorded as a per-student failure
--      (error_code 'invalid_full_name') and processing continues with the
--      next student.
--
--   KNOWN UNICODE LIMITATION (documented rather than pretended away, per
--   this task's instructions): this project has only the pgcrypto
--   extension installed (0001) — no `unaccent`. lower() correctly
--   lowercases accented Latin letters (e.g. "É" -> "é") because Postgres's
--   lower() is locale-aware, but it does NOT transliterate/strip
--   diacritics, and step 2 above does NOT strip them either, since under
--   a typical UTF8 database locale they are classified as alphanumeric
--   (not punctuation) and are therefore intentionally kept, not removed.
--   So "José Muñoz" normalizes to "josé.muñoz", not "jose.munoz". If
--   ASCII-only usernames are required, that needs the `unaccent`
--   extension (`create extension unaccent;`) plus an `unaccent(...)` call
--   added to step 1/2 — intentionally NOT added here since installing a
--   new extension is a schema change beyond "create only a new migration
--   for the approved bulk architecture", and the current single-student
--   flow has never needed to make that decision either (the teacher types
--   the username by hand today).
--
-- USERNAME CONCURRENCY (duplicate names, both within one batch and against
-- existing rows): this function does NOT do a "SELECT to check availability,
-- then INSERT" — that pattern is exactly what the task calls out as unsafe,
-- since another request (or another row later in this same batch) could
-- take the username in between. Instead, each candidate username is
-- attempted as a real INSERT. If it collides, Postgres itself is the
-- source of truth (the UNIQUE constraint), and the INSERT's own
-- unique_violation is caught and retried with the next numeric suffix
-- (juan.delacruz, juan.delacruz2, juan.delacruz3, ...) up to
-- v_max_username_suffix_attempts. This is what makes it safe both against
-- concurrent requests from other teachers AND against duplicate names
-- within the same batch (e.g. two "Juan Dela Cruz" rows in one paste) —
-- the second occurrence's first attempt collides with the first
-- occurrence's now-committed-within-this-transaction row and is retried
-- automatically, no special-casing needed.
--
--   Only ONE exception is treated as a retry-worthy collision: a
--   unique_violation whose constraint name matches the ONE UNIQUE
--   constraint that information_schema reports as covering exactly
--   public.students.username (looked up once, at the very start of the
--   call, into v_username_unique_constraint — see "CONSTRAINT NAME — NOT
--   HARDCODED" in this migration's header comment for why it's looked up
--   rather than written in literally). If that lookup finds no such
--   constraint at all, or finds more than one, the function raises
--   immediately and aborts before touching any student — it never falls
--   back to guessing a name or picking arbitrarily among several.
--   Every OTHER error — including a unique_violation on some other
--   constraint entirely — is re-raised, not swallowed. See "TRANSACTION
--   STRATEGY" below for what that means for the batch as a whole.
--
-- TRANSACTION STRATEGY: partial success is possible ONLY for explicitly
-- handled expected per-student failures. Any unexpected error aborts the
-- entire RPC transaction and rolls back all successful writes from the
-- batch.
--   - EXPECTED per-student failures — invalid/missing full_name, an
--     unusable normalized username (nothing left after stripping
--     punctuation), invalid/missing password, and username-suffix attempts
--     exhausted — are recorded as a failed row in that student's result
--     and do NOT affect any other student. Implemented via nested
--     BEGIN/EXCEPTION blocks per insert attempt, which Postgres backs with
--     an implicit savepoint: only that one attempt's writes (students +
--     student_enrollments, whichever happened before the failure) are
--     rolled back, nothing else about the surrounding transaction.
--   - UNEXPECTED errors — anything not explicitly recognized above,
--     including (per the task's own examples) a broken audit function, a
--     permission error, a missing database object, an unexpected
--     constraint violation, an encryption failure, or any other
--     programming/database error — are re-raised. The audit-log call in
--     particular lives inside the SAME atomic per-attempt block as the
--     students/student_enrollments inserts, specifically so a broken audit
--     write can never leave a student without one. Since nothing higher up
--     in this function catches these either, they propagate all the way
--     out of the function and abort the ENTIRE call — which, because the
--     whole RPC executes inside one Postgres transaction, ALSO rolls back
--     every student already successfully created earlier in the same
--     batch. The Edge Function/caller sees this as the RPC call itself
--     returning a Postgres error rather than a normal jsonb result, and
--     should treat that as "nothing in this batch was created."
--
-- PER-STUDENT ATOMICITY: for one student, one attempt's write set is
-- always {students row, student_enrollments row, audit_logs row} together,
-- or none of them — never a subset. See TRANSACTION STRATEGY above for the
-- mechanism (implicit savepoint per BEGIN/EXCEPTION block).
--
-- INPUT SHAPE: p_students is a JSONB array of {"full_name": text,
-- "password": text} objects. student_number is intentionally not accepted
-- in this first version (see "STUDENT NUMBER" below).
--
-- RESULT SHAPE: a JSONB array, one object per input element, in input
-- order, each with: index (0-based, matches the input array position so
-- the Edge Function can rejoin its own in-memory plaintext-password map by
-- position), full_name (echoed back exactly as submitted), success
-- (boolean), student_id (uuid, success only), username (text, success
-- only), error_code (text, failure only), error_message (text, failure
-- only). The plaintext password is deliberately never included — the Edge
-- Function generated it and already holds it in memory; it only needs this
-- function to hand back which username/student_id ended up matching which
-- input position. The encryption key is never included.
--
-- ENCRYPTION KEY VALIDATION: app.create_student (0017) does not validate
-- p_encryption_key at all before passing it straight into pgp_sym_encrypt —
-- there is no stronger or different established pattern in this project to
-- reuse. Since that means an invalid key would otherwise only surface as
-- whatever pgcrypto happens to raise partway through the first student, a
-- null-or-blank p_encryption_key is checked explicitly here and rejected as
-- a batch-level error (aborting before any student is processed), not as a
-- per-student failure — an unusable key is a call-configuration problem,
-- not a problem with any particular student's data.
--
-- USERNAME COLUMN LIMIT: public.students.username (0006) is plain
-- unrestricted `text` — no varchar length and no length-related check
-- constraint exist anywhere in the supplied project. There is therefore no
-- schema-level limit for the base-username-plus-numeric-suffix generation
-- below to respect, and none is invented here.
--
-- STUDENT NUMBER: not accepted or generated in this version, per the
-- approved scope. The insert below only ever writes NULL into
-- students.student_number (its existing column default already allows
-- NULL — see 0006), so adding an optional p_student_number-per-element
-- input later is additive: it would not require changing the function's
-- signature shape, the loop structure, or the result shape, only adding
-- one more field read out of each input element and passed into the
-- existing INSERT. A fabricated student_number is NOT invented here.
--
-- SECURITY: SECURITY DEFINER (like app.create_student) so it can write
-- audit_logs despite `authenticated` having no direct INSERT grant there
-- (0015/0016 — the only sanctioned write path is app.log_audit_event()).
-- search_path is pinned to `public, extensions` — the same fix 0021
-- applied to app.create_student and its siblings, needed here for the
-- exact same reason: pgp_sym_encrypt lives in the `extensions` schema on
-- this project, not `public`. Grants (below, and the public wrapper) are
-- to `authenticated` only, matching app.create_student exactly — this
-- function must be called via an Edge Function that forwards the calling
-- teacher's own JWT, never service_role, so that auth.uid()-based
-- authorization and app.log_audit_event()'s actor resolution both still
-- resolve to the real teacher. This is unchanged from 0017's existing
-- rule; nothing here weakens it.
-- ---------------------------------------------------------------------------
create or replace function app.create_students_bulk(
  p_section_id      uuid,
  p_students        jsonb,
  p_encryption_key  text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_max_batch_size                constant integer := 100;
  v_max_username_suffix_attempts  constant integer := 1000;

  -- Looked up at runtime below — see "CONSTRAINT NAME — NOT HARDCODED" in
  -- this migration's header comment. Intentionally NOT a constant/literal.
  -- v_username_unique_constraints collects EVERY matching constraint name
  -- so ambiguity (more than one match) can be detected explicitly, rather
  -- than letting a plain SELECT INTO silently pick an arbitrary one.
  v_username_unique_constraints text[];
  v_username_unique_constraint  text;

  v_results         jsonb := '[]'::jsonb;
  v_idx             integer;
  v_elem            jsonb;
  v_full_name_raw   text;
  v_password        text;
  v_normalized      text;
  v_parts           text[];
  v_base_username   text;
  v_candidate       text;
  v_attempt         integer;
  v_created         boolean;
  v_student_id      uuid;
  v_constraint_name text;
  v_error_code      text;
  v_error_message   text;
begin
  -- -------------------------------------------------------------------
  -- Authorization — checked once for the whole batch/section, exactly
  -- the same rule app.create_student enforces per student.
  -- -------------------------------------------------------------------
  if p_section_id is null then
    raise exception 'section_id is required';
  end if;

  if not (app.is_admin() or (app.is_approved_teacher() and app.teacher_has_section(p_section_id))) then
    raise exception 'not authorized to create students in section %', p_section_id;
  end if;

  -- -------------------------------------------------------------------
  -- Encryption key validation. Not validated by app.create_student
  -- (0017) either, but an unusable key is a call-configuration problem
  -- for the whole batch, not any one student's fault — see "ENCRYPTION
  -- KEY VALIDATION" in this migration's header comment.
  -- -------------------------------------------------------------------
  if p_encryption_key is null or length(btrim(p_encryption_key)) = 0 then
    raise exception 'p_encryption_key is required';
  end if;

  -- -------------------------------------------------------------------
  -- Batch-level input validation. These are function-misuse-level
  -- problems (not a specific student's fault), so they abort the whole
  -- call rather than being reported as a per-student failure.
  -- -------------------------------------------------------------------
  if p_students is null or jsonb_typeof(p_students) is distinct from 'array' then
    raise exception 'p_students must be a JSON array';
  end if;

  if jsonb_array_length(p_students) = 0 then
    raise exception 'p_students must not be empty';
  end if;

  if jsonb_array_length(p_students) > v_max_batch_size then
    raise exception 'batch of % students exceeds the maximum of % students per call',
      jsonb_array_length(p_students), v_max_batch_size;
  end if;

  -- -------------------------------------------------------------------
  -- Determine the actual UNIQUE constraint covering students.username,
  -- by asking Postgres directly rather than assuming a name — see
  -- "CONSTRAINT NAME — NOT HARDCODED" in this migration's header
  -- comment. A single-column UNIQUE constraint is identified as: a
  -- table_constraints row of type UNIQUE on public.students whose
  -- key_column_usage columns are exactly {username}.
  --
  -- Every matching constraint name is collected into an array first
  -- (rather than SELECT-ing a single constraint_name directly) so that
  -- more than one match can be detected explicitly. A plain "SELECT ...
  -- INTO" with more than one matching row would otherwise just assign
  -- one of them arbitrarily with no error — exactly the kind of silent
  -- ambiguity this lookup exists to avoid. Zero matches and more than
  -- one match both abort here, before any student is processed; only
  -- an array of exactly one element is accepted.
  -- -------------------------------------------------------------------
  select array_agg(sub.constraint_name)
  into v_username_unique_constraints
  from (
    select kcu.constraint_name
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on kcu.constraint_schema = tc.constraint_schema
     and kcu.constraint_name = tc.constraint_name
    where tc.table_schema = 'public'
      and tc.table_name = 'students'
      and tc.constraint_type = 'UNIQUE'
    group by kcu.constraint_name
    having array_agg(kcu.column_name) = array['username']
  ) sub;

  if v_username_unique_constraints is null or array_length(v_username_unique_constraints, 1) = 0 then
    raise exception 'could not determine the UNIQUE constraint covering public.students.username; aborting rather than guessing';
  elsif array_length(v_username_unique_constraints, 1) > 1 then
    raise exception 'found % UNIQUE constraints covering public.students.username, expected exactly one; aborting rather than guessing which one governs username collisions',
      array_length(v_username_unique_constraints, 1);
  end if;

  v_username_unique_constraint := v_username_unique_constraints[1];

  -- -------------------------------------------------------------------
  -- Per-student processing.
  -- -------------------------------------------------------------------
  for v_idx, v_elem in
    select (ord - 1)::integer, elem
    from jsonb_array_elements(p_students) with ordinality as t(elem, ord)
  loop
    v_error_code := null;
    v_error_message := null;

    -- Reject malformed array elements explicitly (e.g. a bare string,
    -- number, or null in the array) instead of letting -> / ->> quietly
    -- return NULL for everything and misreport this as "full_name is
    -- required". The original input index is still preserved in the
    -- result either way.
    if jsonb_typeof(v_elem) is distinct from 'object' then
      v_results := v_results || jsonb_build_object(
        'index', v_idx,
        'full_name', null,
        'success', false,
        'student_id', null,
        'username', null,
        'error_code', 'invalid_element',
        'error_message', 'array element must be a JSON object with full_name and password'
      );
      continue;
    end if;

    v_full_name_raw := v_elem ->> 'full_name';
    v_password      := v_elem ->> 'password';

    -- Input validation (expected, recoverable — this student fails,
    -- the rest of the batch continues).
    if v_full_name_raw is null or length(btrim(v_full_name_raw)) = 0 then
      v_error_code := 'validation_error';
      v_error_message := 'full_name is required';
    elsif length(v_full_name_raw) > 200 then
      -- 200 is a defensive limit only — students.full_name (0006) has no
      -- length constraint of its own to inherit; this is not enforced
      -- anywhere else in the schema.
      v_error_code := 'validation_error';
      v_error_message := 'full_name exceeds the maximum length of 200 characters';
    elsif v_password is null or length(v_password) = 0 then
      v_error_code := 'validation_error';
      v_error_message := 'password is required';
    elsif length(v_password) < 4 then
      -- Mirrors app.create_student's existing minimum (0017) exactly —
      -- not a new threshold invented for bulk.
      v_error_code := 'validation_error';
      v_error_message := 'password does not meet the minimum length requirement';
    elsif length(v_password) > 128 then
      -- Defensive limit only, like the full_name one above — no existing
      -- schema constraint to mirror here.
      v_error_code := 'validation_error';
      v_error_message := 'password exceeds the maximum length of 128 characters';
    end if;

    if v_error_code is not null then
      v_results := v_results || jsonb_build_object(
        'index', v_idx,
        'full_name', v_full_name_raw,
        'success', false,
        'student_id', null,
        'username', null,
        'error_code', v_error_code,
        'error_message', v_error_message
      );
      continue;
    end if;

    -- Username base generation — see "USERNAME GENERATION" above.
    v_normalized := lower(btrim(v_full_name_raw));
    v_normalized := regexp_replace(v_normalized, '[^[:alnum:][:space:]]', '', 'g');
    v_normalized := btrim(regexp_replace(v_normalized, '\s+', ' ', 'g'));

    if v_normalized = '' then
      v_results := v_results || jsonb_build_object(
        'index', v_idx,
        'full_name', v_full_name_raw,
        'success', false,
        'student_id', null,
        'username', null,
        'error_code', 'invalid_full_name',
        'error_message', 'full_name did not contain any usable characters after normalization'
      );
      continue;
    end if;

    v_parts := regexp_split_to_array(v_normalized, ' ');

    if array_length(v_parts, 1) = 1 then
      v_base_username := v_parts[1];
    else
      v_base_username := v_parts[1] || '.' || array_to_string(v_parts[2:array_length(v_parts, 1)], '');
    end if;

    -- Insert attempt loop — see "USERNAME CONCURRENCY" above. Each
    -- attempt is its own atomic sub-block (students + student_enrollments
    -- + audit log), retried only on the specific username unique
    -- constraint; anything else re-raises and aborts the whole call.
    v_created := false;
    v_attempt := 0;

    while not v_created and v_attempt < v_max_username_suffix_attempts loop
      v_attempt := v_attempt + 1;
      v_candidate := case when v_attempt = 1 then v_base_username else v_base_username || v_attempt::text end;

      begin
        insert into public.students (username, full_name, password_encrypted, created_by)
        values (v_candidate, v_full_name_raw, pgp_sym_encrypt(v_password, p_encryption_key), auth.uid())
        returning id into v_student_id;

        insert into public.student_enrollments (student_id, section_id, status, enrolled_at)
        values (v_student_id, p_section_id, 'active', now());

        perform app.log_audit_event(
          'student_created',
          'students',
          v_student_id,
          jsonb_build_object('section_id', p_section_id, 'bulk', true)
        );

        v_created := true;

        v_results := v_results || jsonb_build_object(
          'index', v_idx,
          'full_name', v_full_name_raw,
          'success', true,
          'student_id', v_student_id,
          'username', v_candidate,
          'error_code', null,
          'error_message', null
        );
      exception when unique_violation then
        get stacked diagnostics v_constraint_name = constraint_name;

        if v_constraint_name is distinct from v_username_unique_constraint then
          -- Not the collision we know how to handle safely (see
          -- "USERNAME CONCURRENCY" above) — propagate and abort rather
          -- than misreport an unrelated constraint violation.
          raise;
        end if;
        -- else: expected username collision, loop retries with the next
        -- numeric suffix.
      end;
    end loop;

    if not v_created then
      v_results := v_results || jsonb_build_object(
        'index', v_idx,
        'full_name', v_full_name_raw,
        'success', false,
        'student_id', null,
        'username', null,
        'error_code', 'username_generation_failed',
        'error_message', format('could not find an available username after %s attempts', v_max_username_suffix_attempts)
      );
    end if;
  end loop;

  return v_results;
end;
$$;

comment on function app.create_students_bulk(uuid, jsonb, text) is
  'Bulk counterpart to app.create_student (0017): creates multiple students into ONE section from a JSONB array of {full_name, password}, generating usernames server-side. Per-student validation/username-collision failures are isolated (that student fails, the rest continue); any unexpected error aborts and rolls back the whole call. MUST be called via an Edge Function that supplies the key from its environment secret and forwards the caller''s own JWT — never service_role, never directly from Flutter.';

grant execute on function app.create_students_bulk(uuid, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- public.create_students_bulk — PostgREST-reachable pass-through.
--
-- Same reason 0020 added public wrappers for the 0017 functions: `app` is
-- intentionally not in PostgREST's exposed-schema list (0001), so
-- app.create_students_bulk is not reachable via `.rpc()` from an Edge
-- Function's supabase-js/supabase-dart client without this wrapper. Adds
-- no logic of its own — `security invoker` (the default, omitted below,
-- exactly like 0020's wrappers) is correct here for the same reason it was
-- correct there: auth.uid() resolves from the request's JWT claims
-- regardless of definer/invoker mode, so a plain pass-through preserves
-- the calling teacher's real identity into app.create_students_bulk's own
-- authorization check.
-- ---------------------------------------------------------------------------
create or replace function public.create_students_bulk(
  p_section_id      uuid,
  p_students        jsonb,
  p_encryption_key  text
)
returns jsonb
language sql
as $$
  select app.create_students_bulk(p_section_id, p_students, p_encryption_key);
$$;

comment on function public.create_students_bulk(uuid, jsonb, text) is
  'Public-schema pass-through to app.create_students_bulk so it is reachable via PostgREST/Edge Functions — mirrors 0020''s pattern for create_student. No additional logic.';

grant execute on function public.create_students_bulk(uuid, jsonb, text) to authenticated;
