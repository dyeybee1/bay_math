-- Give each active student in a grade a unique, consecutive Endless Quiz rank.
-- Best streak decides first; equal streaks sort by name (case-insensitive),
-- then by exact name and student ID so duplicate names remain deterministic.
-- Rank the full grade before limiting the top page or selecting the caller.
-- Recreate the wrappers and implementation together because some deployed
-- databases still have the older three-column return type. PostgreSQL cannot
-- replace that return type in place. RESTRICT (the default) prevents dropping
-- any unexpected dependent object.

begin;

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
    row_number() over (
      order by st.best_endless_streak desc,
               lower(st.full_name) asc,
               st.full_name asc,
               st.id asc
    ) as rank,
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
  'Top 50 by default among active students in the caller''s grade. Unique consecutive positions use best_endless_streak descending, then case-insensitive full_name, exact full_name, and student ID; avatar_id remains available for display.';

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
      row_number() over (
        order by st.best_endless_streak desc,
                 lower(st.full_name) asc,
                 st.full_name asc,
                 st.id asc
      ) as rank,
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
  'The caller''s unique position in the same full-grade Endless Quiz order as app.endless_quiz_leaderboard_top: best streak descending, then case-insensitive name, exact name, and student ID.';

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
  'Public pass-through to app.endless_quiz_leaderboard_top with consecutive ranks and nullable avatar_id.';

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
  'Public pass-through to app.endless_quiz_leaderboard_my_rank with consecutive ranks and nullable avatar_id.';

grant execute on function public.endless_quiz_leaderboard_my_rank() to authenticated;

commit;
