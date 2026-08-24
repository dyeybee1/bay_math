-- =============================================================================
-- Migration: 0056_fix_bulk_create_students_constraint_lookup.sql
--
-- Fixes a bug in app.create_students_bulk (0055_bulk_create_students.sql)
-- discovered only once run against a live database (that migration's own
-- header comment already disclosed it was "NOT COMPILER-VERIFIED AGAINST A
-- LIVE DATABASE" for exactly this reason).
--
-- BUG: the UNIQUE-constraint-name lookup used
--   having array_agg(kcu.column_name) = array['username']
-- `information_schema.key_column_usage.column_name` is of type
-- `information_schema.sql_identifier` (a domain), not plain `text`, so
-- `array_agg(kcu.column_name)` produces `information_schema.sql_identifier[]`.
-- Postgres has no `=` operator between that array type and a plain
-- `text[]` literal (`array['username']`), so EVERY call to
-- app.create_students_bulk failed immediately with:
--   operator does not exist: information_schema.sql_identifier[] = text[]
--   (SQLSTATE 42883)
-- — before authorization, before validation, before touching any student.
-- Confirmed via the create-students-bulk Edge Function's own logs on a
-- real invocation.
--
-- FIX: cast column_name to text before aggregating
-- (`array_agg(kcu.column_name::text)`), so the comparison is `text[] =
-- text[]`, which Postgres does support. No other logic in the function
-- changes — this migration re-declares the exact same function body from
-- 0055 with only that one line different, via `create or replace`, which
-- is safe to run against a database that already has 0055 applied (and
-- already has student rows created by app.create_student, since this
-- function is a pure addition, not a data migration).
--
-- 0055 itself is intentionally NOT edited/renumbered — once a migration
-- has been applied via `supabase db push`, editing its file afterward
-- causes the file content to stop matching the recorded migration
-- history/checksum. A follow-up migration is the correct way to patch an
-- already-applied function.
-- =============================================================================

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
  if p_section_id is null then
    raise exception 'section_id is required';
  end if;

  if not (app.is_admin() or (app.is_approved_teacher() and app.teacher_has_section(p_section_id))) then
    raise exception 'not authorized to create students in section %', p_section_id;
  end if;

  if p_encryption_key is null or length(btrim(p_encryption_key)) = 0 then
    raise exception 'p_encryption_key is required';
  end if;

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
  -- FIXED per this migration's header comment: kcu.column_name is
  -- explicitly cast to ::text before array_agg, so the comparison below
  -- is text[] = text[], not sql_identifier[] = text[].
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
    having array_agg(kcu.column_name::text) = array['username']
  ) sub;

  if v_username_unique_constraints is null or array_length(v_username_unique_constraints, 1) = 0 then
    raise exception 'could not determine the UNIQUE constraint covering public.students.username; aborting rather than guessing';
  elsif array_length(v_username_unique_constraints, 1) > 1 then
    raise exception 'found % UNIQUE constraints covering public.students.username, expected exactly one; aborting rather than guessing which one governs username collisions',
      array_length(v_username_unique_constraints, 1);
  end if;

  v_username_unique_constraint := v_username_unique_constraints[1];

  for v_idx, v_elem in
    select (ord - 1)::integer, elem
    from jsonb_array_elements(p_students) with ordinality as t(elem, ord)
  loop
    v_error_code := null;
    v_error_message := null;

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

    if v_full_name_raw is null or length(btrim(v_full_name_raw)) = 0 then
      v_error_code := 'validation_error';
      v_error_message := 'full_name is required';
    elsif length(v_full_name_raw) > 200 then
      v_error_code := 'validation_error';
      v_error_message := 'full_name exceeds the maximum length of 200 characters';
    elsif v_password is null or length(v_password) = 0 then
      v_error_code := 'validation_error';
      v_error_message := 'password is required';
    elsif length(v_password) < 4 then
      v_error_code := 'validation_error';
      v_error_message := 'password does not meet the minimum length requirement';
    elsif length(v_password) > 128 then
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
          raise;
        end if;
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
  'Bulk counterpart to app.create_student (0017): creates multiple students into ONE section from a JSONB array of {full_name, password}, generating usernames server-side. Per-student validation/username-collision failures are isolated (that student fails, the rest continue); any unexpected error aborts and rolls back the whole call. MUST be called via an Edge Function that supplies the key from its environment secret and forwards the caller''s own JWT — never service_role, never directly from Flutter. FIXED in 0056: the UNIQUE-constraint-name lookup now casts column_name to text before comparing, avoiding a sql_identifier[] = text[] operator error that previously made every call fail.';

-- No grant/wrapper changes needed — public.create_students_bulk (0055)
-- already passes through to app.create_students_bulk unconditionally, so
-- redefining the app-schema function here is sufficient; the public
-- wrapper picks up the fix automatically on its next call.
