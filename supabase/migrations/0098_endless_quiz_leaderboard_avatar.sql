-- Surface the already-stored fixed-catalog avatar key in both Endless Quiz
-- leaderboard responses. Ranking, grade scoping, tie handling, and exposed
-- identity fields remain otherwise unchanged.

drop function if exists public.endless_quiz_leaderboard_top(int);
drop function if exists public.endless_quiz_leaderboard_my_rank();
drop function if exists app.endless_quiz_leaderboard_top(int);
drop function if exists app.endless_quiz_leaderboard_my_rank();

create function app.endless_quiz_leaderboard_top(p_limit int default 50)
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer,
  avatar_id           text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    rank() over (order by st.best_endless_streak desc) as rank,
    st.full_name,
    st.best_endless_streak,
    st.avatar_id
  from public.students st
  join public.student_enrollments se
    on se.student_id = st.id
    and se.status = 'active'
  join public.sections sec
    on sec.id = se.section_id
  where sec.grade_level = app.student_current_grade()
  order by rank
  limit p_limit;
$$;

comment on function app.endless_quiz_leaderboard_top(int) is
  'Top active students in the caller''s grade ranked by best Endless Quiz streak. Includes the nullable fixed-catalog avatar_id for display; ranking and grade scoping are unchanged from 0036.';

grant execute on function app.endless_quiz_leaderboard_top(int) to authenticated;

create function app.endless_quiz_leaderboard_my_rank()
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer,
  avatar_id           text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ranked.rank,
    ranked.full_name,
    ranked.best_endless_streak,
    ranked.avatar_id
  from (
    select
      rank() over (order by st.best_endless_streak desc) as rank,
      st.id,
      st.full_name,
      st.best_endless_streak,
      st.avatar_id
    from public.students st
    join public.student_enrollments se
      on se.student_id = st.id
      and se.status = 'active'
    join public.sections sec
      on sec.id = se.section_id
    where sec.grade_level = app.student_current_grade()
  ) ranked
  where ranked.id = app.current_student_id();
$$;

comment on function app.endless_quiz_leaderboard_my_rank() is
  'The caller''s rank in the same grade-scoped Endless Quiz ordering. Includes the nullable fixed-catalog avatar_id for display; ranking is unchanged from 0036.';

grant execute on function app.endless_quiz_leaderboard_my_rank() to authenticated;

create function public.endless_quiz_leaderboard_top(p_limit int default 50)
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer,
  avatar_id           text
)
language sql
as $$
  select * from app.endless_quiz_leaderboard_top(p_limit);
$$;

comment on function public.endless_quiz_leaderboard_top(int) is
  'Public pass-through to app.endless_quiz_leaderboard_top, including nullable avatar_id (0098).';

grant execute on function public.endless_quiz_leaderboard_top(int) to authenticated;

create function public.endless_quiz_leaderboard_my_rank()
returns table (
  rank                bigint,
  full_name           text,
  best_endless_streak integer,
  avatar_id           text
)
language sql
as $$
  select * from app.endless_quiz_leaderboard_my_rank();
$$;

comment on function public.endless_quiz_leaderboard_my_rank() is
  'Public pass-through to app.endless_quiz_leaderboard_my_rank, including nullable avatar_id (0098).';

grant execute on function public.endless_quiz_leaderboard_my_rank() to authenticated;
