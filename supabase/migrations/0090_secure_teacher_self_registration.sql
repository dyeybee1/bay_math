-- =============================================================================
-- Secure Teacher self-registration
--
-- The previous client flow created auth.users and public.profiles in separate
-- requests. A failure in the second request could leave an Auth user without a
-- profile, and email-confirmation deployments might not have an authenticated
-- session available for the profile insert at all. This trigger creates the
-- pending Teacher profile inside the Auth user transaction instead.
-- =============================================================================

-- Fail before changing policies/triggers if the normalized unique index cannot
-- be built from historical data. No data is modified by this check.
do $migration$
begin
  if exists (
    select 1
    from public.profiles
    group by lower(btrim(email))
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'Cannot enforce normalized profile email uniqueness.',
      hint = 'Run the 0090 pre-deployment duplicate-email diagnostic and resolve conflicts before retrying.';
  end if;
end;
$migration$;

create function app.handle_new_teacher_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_full_name text := btrim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  v_email text := lower(btrim(coalesce(new.email, '')));
begin
  -- Auth users created through the Admin bootstrap/management path are outside
  -- this trigger's scope. A caller can request this path, but cannot choose the
  -- resulting role or status: both are fixed below.
  if coalesce(new.raw_user_meta_data ->> 'registration_source', '')
      <> 'teacher_self_signup' then
    return new;
  end if;

  if char_length(v_full_name) not between 1 and 100
      or v_full_name <> btrim(v_full_name)
      or v_full_name ~ '[[:cntrl:]]'
      or v_full_name <>
        translate(
          v_full_name,
          E'0123456789!"#$%&()*+,./:;<=>?@[\\]^_`{|}~',
          ''
        )
      or replace(v_full_name, chr(8217), '''')
        ~ $name_shape$(^[ '-]|[ '-]$|[ '-]{2})$name_shape$ then
    raise exception using
      errcode = '22023',
      message = 'Invalid Teacher registration name.';
  end if;

  if char_length(v_email) not between 3 and 254
      or v_email !~
        '^[a-z0-9.!#$%&''*+/=?^_`{|}~-]{1,64}@[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?([.][a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
      or v_email ~ '^[.]|[.]@|[.][.]'
      or v_email !~ '[.][a-z0-9-]{2,63}$' then
    raise exception using
      errcode = '22023',
      message = 'Invalid Teacher registration email.';
  end if;

  insert into public.profiles (id, role, status, full_name, email)
  values (new.id, 'teacher', 'pending', v_full_name, v_email);

  return new;
end;
$$;

revoke all on function app.handle_new_teacher_signup() from public;
revoke all on function app.handle_new_teacher_signup() from anon;
revoke all on function app.handle_new_teacher_signup() from authenticated;

create trigger on_auth_user_created_create_teacher_profile
  after insert on auth.users
  for each row execute function app.handle_new_teacher_signup();

-- Self-registration no longer needs a direct profiles INSERT from an
-- authenticated client. Keeping that fallback would let a custom client
-- bypass the Auth trigger's metadata-to-email consistency checks.
drop policy if exists profiles_admin_insert on public.profiles;

create policy profiles_admin_insert on public.profiles for insert
  with check (app.is_admin());

comment on policy profiles_admin_insert on public.profiles is
  'Only an approved Admin may insert profiles through PostgREST. Teacher self-registration is created by app.handle_new_teacher_signup with role/status fixed server-side.';

-- NOT VALID avoids blocking deployment because of a historical row that an
-- Administrator may need to clean up. PostgreSQL still enforces these checks
-- for every new or updated Teacher profile, including all new registrations.
alter table public.profiles
  add constraint profiles_teacher_name_valid
  check (
    role <> 'teacher'
    or (
      char_length(full_name) between 1 and 100
      and full_name = btrim(full_name)
      and full_name !~ '[[:cntrl:]]'
      and full_name =
        translate(
          full_name,
          E'0123456789!"#$%&()*+,./:;<=>?@[\\]^_`{|}~',
          ''
        )
      and replace(full_name, chr(8217), '''')
        !~ $name_shape$(^[ '-]|[ '-]$|[ '-]{2})$name_shape$
    )
  ) not valid;

alter table public.profiles
  add constraint profiles_teacher_email_valid
  check (
    role <> 'teacher'
    or (
      char_length(email) between 3 and 254
      and email = lower(btrim(email))
      and email ~
        '^[a-z0-9.!#$%&''*+/=?^_`{|}~-]{1,64}@[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?([.][a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
      and email !~ '^[.]|[.]@|[.][.]'
      and email ~ '[.][a-z0-9-]{2,63}$'
    )
  ) not valid;

-- Auth owns canonical account uniqueness. This mirror-level index prevents
-- case/whitespace variants from diverging inside public.profiles.
create unique index profiles_email_normalized_uidx
  on public.profiles (lower(btrim(email)));

comment on function app.handle_new_teacher_signup() is
  'Creates role=teacher/status=pending profiles atomically for Auth signups explicitly marked teacher_self_signup. Validates metadata and never accepts role/status from the client.';
