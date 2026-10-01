begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(6);

insert into auth.users (id, email)
values
  ('98000000-0000-0000-0000-000000000001', 'history-admin@baymath.test'),
  ('98000000-0000-0000-0000-000000000002', 'history-pending@baymath.test'),
  ('98000000-0000-0000-0000-000000000003', 'history-approved@baymath.test'),
  ('98000000-0000-0000-0000-000000000004', 'history-rejected@baymath.test'),
  ('98000000-0000-0000-0000-000000000005', 'history-archived@baymath.test');

insert into public.profiles (
  id,
  role,
  status,
  full_name,
  email,
  approved_by,
  approved_at
)
values
  (
    '98000000-0000-0000-0000-000000000001',
    'admin',
    'approved',
    'History Admin',
    'history-admin@baymath.test',
    null,
    now()
  ),
  (
    '98000000-0000-0000-0000-000000000002',
    'teacher',
    'pending',
    'Pending Teacher',
    'history-pending@baymath.test',
    null,
    null
  ),
  (
    '98000000-0000-0000-0000-000000000003',
    'teacher',
    'approved',
    'Approved Teacher',
    'history-approved@baymath.test',
    '98000000-0000-0000-0000-000000000001',
    now()
  ),
  (
    '98000000-0000-0000-0000-000000000004',
    'teacher',
    'rejected',
    'Rejected Teacher',
    'history-rejected@baymath.test',
    null,
    null
  ),
  (
    '98000000-0000-0000-0000-000000000005',
    'teacher',
    'archived',
    'Archived Teacher',
    'history-archived@baymath.test',
    null,
    null
  );

select set_config(
  'request.jwt.claim.sub',
  '98000000-0000-0000-0000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"98000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select count(*)
    from public.profiles
    where role = 'teacher'
      and status in ('approved', 'rejected')
  ),
  2::bigint,
  'An approved Admin can read both processed Teacher registrations'
);

select is(
  (
    select count(*)
    from public.profiles
    where role = 'teacher'
      and status in ('approved', 'rejected')
      and status = 'approved'
  ),
  1::bigint,
  'The Approved history filter has one row'
);

select is(
  (
    select count(*)
    from public.profiles
    where role = 'teacher'
      and status in ('approved', 'rejected')
      and status = 'rejected'
  ),
  1::bigint,
  'The Rejected history filter has one row'
);

select is(
  (
    select count(*)
    from public.profiles
    where role = 'teacher'
      and status in ('approved', 'rejected')
      and status = 'pending'
  ),
  0::bigint,
  'Pending registrations are excluded from history'
);

select is(
  (
    select count(*)
    from public.profiles
    where role = 'teacher'
      and status in ('approved', 'rejected')
      and status = 'archived'
  ),
  0::bigint,
  'Archived accounts are excluded from registration history'
);

select is(
  (
    select approver.full_name
    from public.profiles teacher
    left join public.profiles approver on approver.id = teacher.approved_by
    where teacher.id = '98000000-0000-0000-0000-000000000003'
  ),
  'History Admin'::text,
  'The approving Admin remains readable through the self-reference'
);

select * from finish();
rollback;
