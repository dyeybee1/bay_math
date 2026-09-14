-- =============================================================================
-- Migration: 0092_repair_duplicate_grade4_types_of_fractions.sql
-- Classification: narrowly scoped data repair only; no persistent schema.
--
-- Migration 0057 was accidentally executed twice in the target database. Both
-- copies are complete and isolated. Preserve the first/earlier graph and remove
-- only the second/later graph plus records that depend on that duplicate.
--
-- Preserved graph (first 0057 execution):
--   quiz   b90cc62e-b0ed-4319-a61d-62c7a8e7676e
--   lesson 5a4eda11-352a-4261-a7eb-f4dfd4f16ce1
--
-- Removed graph (second 0057 execution):
--   quiz   4e21bb8c-26b5-4487-8c2a-56732ca21ba5
--   lesson 8f73371e-9c7b-4d3a-842a-e2da58741dd0
--   attempt 26a9c5cf-f3fd-4e3e-9a23-89175c949405
--
-- The repair is safe on a clean migration replay: if 0057 exists exactly once,
-- 0092 verifies that graph and performs no deletes. If two copies exist but do
-- not have the audited production UUIDs, the migration aborts for reinspection.
-- =============================================================================

begin;

set local lock_timeout = '10s';
set local statement_timeout = '2min';

-- Prevent target-related writes from racing the dependency checks/deletes while
-- still allowing ordinary SELECTs during this short transaction.
lock table
  public.lessons,
  public.lesson_pages,
  public.lesson_sections,
  public.lesson_progress,
  public.quizzes,
  public.quiz_sections,
  public.quiz_questions,
  public.question_bank,
  public.question_choices,
  public.quiz_attempts,
  public.quiz_attempt_answers,
  public.quiz_attempt_answer_choice_snapshots
in share row exclusive mode;

create temporary table _0092_types_repair_state (
  keep_quiz_id uuid not null,
  keep_lesson_id uuid not null,
  delete_quiz_id uuid not null,
  delete_lesson_id uuid not null,
  delete_attempt_id uuid not null,
  keep_attempt_id uuid not null,
  keep_attempt_was_present boolean not null default false,
  repair_required boolean not null default false
) on commit drop;

insert into _0092_types_repair_state (
  keep_quiz_id,
  keep_lesson_id,
  delete_quiz_id,
  delete_lesson_id,
  delete_attempt_id,
  keep_attempt_id
) values (
  'b90cc62e-b0ed-4319-a61d-62c7a8e7676e'::uuid,
  '5a4eda11-352a-4261-a7eb-f4dfd4f16ce1'::uuid,
  '4e21bb8c-26b5-4487-8c2a-56732ca21ba5'::uuid,
  '8f73371e-9c7b-4d3a-842a-e2da58741dd0'::uuid,
  '26a9c5cf-f3fd-4e3e-9a23-89175c949405'::uuid,
  'd40b7089-2d7e-4131-b5aa-04eabade78d8'::uuid
);

do $guard$
declare
  v_lesson_count integer;
  v_quiz_count integer;
begin
  select count(*) into v_lesson_count
  from public.lessons
  where source_type = 'built_in'
    and grade_level = 'grade_4'
    and title = 'Types of Fractions';

  select count(*) into v_quiz_count
  from public.quizzes
  where source_type = 'built_in'
    and grade_level = 'grade_4'
    and title = 'Quiz 5: Types of Fractions';

  -- Normal state on a new database, or after this repair was already applied.
  -- The final verification block still validates the one remaining graph.
  if v_lesson_count = 1 and v_quiz_count = 1 then
    return;
  end if;

  if v_lesson_count <> 2 or v_quiz_count <> 2 then
    raise exception using
      errcode = '55000',
      message = format(
        '0092 expected either one or two Types graphs; found %s lessons and %s quizzes.',
        v_lesson_count,
        v_quiz_count
      );
  end if;

  -- The live duplicate IDs must still match the read-only diagnostic result.
  if (
    select count(*)
    from public.quizzes q
    cross join _0092_types_repair_state target
    where q.id in (target.keep_quiz_id, target.delete_quiz_id)
      and q.source_type = 'built_in'
      and q.grade_level = 'grade_4'
      and q.title = 'Quiz 5: Types of Fractions'
      and q.quiz_type = 'internal'
      and q.assessment_type is null
  ) <> 2 then
    raise exception '0092 target quiz UUIDs no longer match both duplicate quizzes.';
  end if;

  if (
    select count(*)
    from public.lessons l
    cross join _0092_types_repair_state target
    where l.id in (target.keep_lesson_id, target.delete_lesson_id)
      and l.source_type = 'built_in'
      and l.grade_level = 'grade_4'
      and l.title = 'Types of Fractions'
      and l.publication_status = 'published'
  ) <> 2 then
    raise exception '0092 target lesson UUIDs no longer match both duplicate lessons.';
  end if;

  if not exists (
    select 1
    from _0092_types_repair_state target
    join public.lessons keep_lesson on keep_lesson.id = target.keep_lesson_id
    join public.lessons delete_lesson on delete_lesson.id = target.delete_lesson_id
    where keep_lesson.linked_quiz_id = target.keep_quiz_id
      and delete_lesson.linked_quiz_id = target.delete_quiz_id
  ) then
    raise exception '0092 lesson-to-quiz pairings changed after diagnostics.';
  end if;

  if exists (
    select 1
    from _0092_types_repair_state target
    join public.lessons keep_lesson on keep_lesson.id = target.keep_lesson_id
    join public.lessons delete_lesson on delete_lesson.id = target.delete_lesson_id
    where row(
      keep_lesson.body,
      keep_lesson.publication_status
    ) is distinct from row(
      delete_lesson.body,
      delete_lesson.publication_status
    )
  ) then
    raise exception '0092 duplicate lesson metadata is not identical.';
  end if;

  if exists (
    select 1
    from _0092_types_repair_state target
    join public.quizzes keep_quiz on keep_quiz.id = target.keep_quiz_id
    join public.quizzes delete_quiz on delete_quiz.id = target.delete_quiz_id
    where row(
      keep_quiz.quiz_type,
      keep_quiz.external_url,
      keep_quiz.external_platform_hint,
      keep_quiz.shuffle_questions,
      keep_quiz.shuffle_choices,
      keep_quiz.assessment_type
    ) is distinct from row(
      delete_quiz.quiz_type,
      delete_quiz.external_url,
      delete_quiz.external_platform_hint,
      delete_quiz.shuffle_questions,
      delete_quiz.shuffle_choices,
      delete_quiz.assessment_type
    )
  ) then
    raise exception '0092 duplicate quiz metadata is not identical.';
  end if;

  -- Confirm both graphs retain 0057's complete 10-page/10-question/40-choice
  -- shape and exactly one correct choice per question.
  if exists (
    select 1
    from (
      select target.keep_lesson_id as lesson_id
      from _0092_types_repair_state target
      union all
      select target.delete_lesson_id
      from _0092_types_repair_state target
    ) candidate
    where (select count(*) from public.lesson_pages lp
           where lp.lesson_id = candidate.lesson_id) <> 10
       or (select count(distinct lp.display_order) from public.lesson_pages lp
           where lp.lesson_id = candidate.lesson_id) <> 10
       or (select min(lp.display_order) from public.lesson_pages lp
           where lp.lesson_id = candidate.lesson_id) <> 1
       or (select max(lp.display_order) from public.lesson_pages lp
           where lp.lesson_id = candidate.lesson_id) <> 10
  ) then
    raise exception '0092 found an incomplete Types lesson graph.';
  end if;

  if exists (
    select 1
    from (
      select target.keep_quiz_id as quiz_id
      from _0092_types_repair_state target
      union all
      select target.delete_quiz_id
      from _0092_types_repair_state target
    ) candidate
    where (select count(*) from public.quiz_questions qq
           where qq.quiz_id = candidate.quiz_id) <> 10
       or (select count(distinct qq.question_id) from public.quiz_questions qq
           where qq.quiz_id = candidate.quiz_id) <> 10
       or (select count(distinct qq.display_order) from public.quiz_questions qq
           where qq.quiz_id = candidate.quiz_id) <> 10
       or (select min(qq.display_order) from public.quiz_questions qq
           where qq.quiz_id = candidate.quiz_id) <> 1
       or (select max(qq.display_order) from public.quiz_questions qq
           where qq.quiz_id = candidate.quiz_id) <> 10
       or (select count(*)
           from public.question_choices qc
           join public.quiz_questions qq on qq.question_id = qc.question_id
           where qq.quiz_id = candidate.quiz_id) <> 40
       or exists (
         select 1
         from public.quiz_questions qq
         join public.question_bank qb on qb.id = qq.question_id
         where qq.quiz_id = candidate.quiz_id
           and (
             qb.source_type <> 'built_in'
             or qb.created_by is not null
             or qb.topic is distinct from 'Types of Fractions'
           )
       )
       or exists (
         select 1
         from public.quiz_questions qq
         left join public.question_choices qc on qc.question_id = qq.question_id
         where qq.quiz_id = candidate.quiz_id
         group by qq.question_id
         having count(qc.id) <> 4
            or count(qc.id) filter (where qc.is_correct) <> 1
       )
  ) then
    raise exception '0092 found an incomplete or invalid Types quiz graph.';
  end if;

  -- Compare semantic content, excluding generated IDs/timestamps. Reseeding is
  -- unnecessary only when the later copy is identical to the original copy.
  if exists (
    select lp.display_order, lp.section_type, lp.title, lp.body, lp.worked_example
    from public.lesson_pages lp
    cross join _0092_types_repair_state target
    where lp.lesson_id = target.keep_lesson_id
    except
    select lp.display_order, lp.section_type, lp.title, lp.body, lp.worked_example
    from public.lesson_pages lp
    cross join _0092_types_repair_state target
    where lp.lesson_id = target.delete_lesson_id
  ) or exists (
    select lp.display_order, lp.section_type, lp.title, lp.body, lp.worked_example
    from public.lesson_pages lp
    cross join _0092_types_repair_state target
    where lp.lesson_id = target.delete_lesson_id
    except
    select lp.display_order, lp.section_type, lp.title, lp.body, lp.worked_example
    from public.lesson_pages lp
    cross join _0092_types_repair_state target
    where lp.lesson_id = target.keep_lesson_id
  ) then
    raise exception '0092 duplicate lesson content is not identical; refusing automatic deletion.';
  end if;

  if exists (
    select
      qq.display_order,
      qb.topic,
      qb.prompt_text,
      qb.explanation_text,
      qc.display_order,
      qc.choice_text,
      qc.is_correct
    from public.quiz_questions qq
    join public.question_bank qb on qb.id = qq.question_id
    join public.question_choices qc on qc.question_id = qb.id
    cross join _0092_types_repair_state target
    where qq.quiz_id = target.keep_quiz_id
    except
    select
      qq.display_order,
      qb.topic,
      qb.prompt_text,
      qb.explanation_text,
      qc.display_order,
      qc.choice_text,
      qc.is_correct
    from public.quiz_questions qq
    join public.question_bank qb on qb.id = qq.question_id
    join public.question_choices qc on qc.question_id = qb.id
    cross join _0092_types_repair_state target
    where qq.quiz_id = target.delete_quiz_id
  ) or exists (
    select
      qq.display_order,
      qb.topic,
      qb.prompt_text,
      qb.explanation_text,
      qc.display_order,
      qc.choice_text,
      qc.is_correct
    from public.quiz_questions qq
    join public.question_bank qb on qb.id = qq.question_id
    join public.question_choices qc on qc.question_id = qb.id
    cross join _0092_types_repair_state target
    where qq.quiz_id = target.delete_quiz_id
    except
    select
      qq.display_order,
      qb.topic,
      qb.prompt_text,
      qb.explanation_text,
      qc.display_order,
      qc.choice_text,
      qc.is_correct
    from public.quiz_questions qq
    join public.question_bank qb on qb.id = qq.question_id
    join public.question_choices qc on qc.question_id = qb.id
    cross join _0092_types_repair_state target
    where qq.quiz_id = target.keep_quiz_id
  ) then
    raise exception '0092 duplicate quiz content is not identical; refusing automatic deletion.';
  end if;

  if exists (
    select 1
    from public.quiz_questions own_link
    join _0092_types_repair_state target
      on target.delete_quiz_id = own_link.quiz_id
    join public.quiz_questions other_link
      on other_link.question_id = own_link.question_id
     and other_link.quiz_id <> target.delete_quiz_id
  ) then
    raise exception '0092 duplicate questions are referenced by another quiz.';
  end if;

  if exists (
    select 1
    from public.lessons l
    cross join _0092_types_repair_state target
    where l.linked_quiz_id = target.delete_quiz_id
      and l.id <> target.delete_lesson_id
  ) then
    raise exception '0092 duplicate quiz is linked by another lesson.';
  end if;

  if exists (
    select 1
    from public.quiz_attempt_answers qaa
    join public.quiz_attempts qa on qa.id = qaa.quiz_attempt_id
    join public.quiz_questions qq on qq.question_id = qaa.question_id
    cross join _0092_types_repair_state target
    where qq.quiz_id = target.delete_quiz_id
      and qa.quiz_id <> target.delete_quiz_id
  ) then
    raise exception '0092 duplicate questions are referenced by an unrelated attempt.';
  end if;

  -- Freeze the exact test-attempt shape supplied by the production diagnostic.
  if (
    select count(*)
    from public.quiz_attempts qa
    cross join _0092_types_repair_state target
    where qa.quiz_id = target.delete_quiz_id
  ) <> 1 or not exists (
    select 1
    from public.quiz_attempts qa
    cross join _0092_types_repair_state target
    where qa.id = target.delete_attempt_id
      and qa.quiz_id = target.delete_quiz_id
  ) then
    raise exception '0092 duplicate attempt set changed after diagnostics.';
  end if;

  if (
    select count(*)
    from public.quiz_attempt_answers qaa
    join public.quiz_attempts qa on qa.id = qaa.quiz_attempt_id
    cross join _0092_types_repair_state target
    where qa.quiz_id = target.delete_quiz_id
  ) <> 4 or (
    select count(*)
    from public.quiz_attempt_answer_choice_snapshots snapshot
    join public.quiz_attempt_answers qaa
      on qaa.id = snapshot.quiz_attempt_answer_id
    join public.quiz_attempts qa on qa.id = qaa.quiz_attempt_id
    cross join _0092_types_repair_state target
    where qa.quiz_id = target.delete_quiz_id
  ) <> 16 then
    raise exception '0092 duplicate attempt answer/snapshot counts changed after diagnostics.';
  end if;

  update _0092_types_repair_state target
  set repair_required = true,
      keep_attempt_was_present = exists (
        select 1
        from public.quiz_attempts qa
        where qa.id = target.keep_attempt_id
          and qa.quiz_id = target.keep_quiz_id
      );
end;
$guard$;

create temporary table _0092_duplicate_questions on commit drop as
select qq.question_id as id
from public.quiz_questions qq
join _0092_types_repair_state target
  on target.delete_quiz_id = qq.quiz_id
where target.repair_required;

-- Delete only dependencies of the audited later duplicate. Child rows are
-- explicit even where an FK also defines ON DELETE CASCADE.
delete from public.quiz_attempt_answer_choice_snapshots snapshot
using public.quiz_attempt_answers answer,
      public.quiz_attempts attempt,
      _0092_types_repair_state target
where target.repair_required
  and snapshot.quiz_attempt_answer_id = answer.id
  and answer.quiz_attempt_id = attempt.id
  and attempt.quiz_id = target.delete_quiz_id;

delete from public.quiz_attempt_answers answer
using public.quiz_attempts attempt,
      _0092_types_repair_state target
where target.repair_required
  and answer.quiz_attempt_id = attempt.id
  and attempt.quiz_id = target.delete_quiz_id;

delete from public.quiz_attempts attempt
using _0092_types_repair_state target
where target.repair_required
  and attempt.quiz_id = target.delete_quiz_id;

delete from public.lesson_progress progress
using _0092_types_repair_state target
where target.repair_required
  and progress.lesson_id = target.delete_lesson_id;

delete from public.lesson_sections assignment
using _0092_types_repair_state target
where target.repair_required
  and assignment.lesson_id = target.delete_lesson_id;

delete from public.lesson_pages page
using _0092_types_repair_state target
where target.repair_required
  and page.lesson_id = target.delete_lesson_id;

delete from public.lessons lesson
using _0092_types_repair_state target
where target.repair_required
  and lesson.id = target.delete_lesson_id;

delete from public.quiz_sections assignment
using _0092_types_repair_state target
where target.repair_required
  and assignment.quiz_id = target.delete_quiz_id;

delete from public.quiz_questions link
using _0092_types_repair_state target
where target.repair_required
  and link.quiz_id = target.delete_quiz_id;

delete from public.question_choices choice
using _0092_duplicate_questions question
where choice.question_id = question.id;

delete from public.question_bank question
using _0092_duplicate_questions target
where question.id = target.id;

delete from public.quizzes quiz
using _0092_types_repair_state target
where target.repair_required
  and quiz.id = target.delete_quiz_id;

do $verify$
declare
  v_quiz_id uuid;
  v_lesson_id uuid;
  v_repair_required boolean;
begin
  select repair_required into v_repair_required
  from _0092_types_repair_state;

  select id into strict v_quiz_id
  from public.quizzes
  where source_type = 'built_in'
    and grade_level = 'grade_4'
    and title = 'Quiz 5: Types of Fractions';

  select id into strict v_lesson_id
  from public.lessons
  where source_type = 'built_in'
    and grade_level = 'grade_4'
    and title = 'Types of Fractions';

  if v_repair_required and not exists (
    select 1
    from _0092_types_repair_state target
    where v_quiz_id = target.keep_quiz_id
      and v_lesson_id = target.keep_lesson_id
  ) then
    raise exception '0092 did not preserve the audited original graph.';
  end if;

  if (select linked_quiz_id from public.lessons where id = v_lesson_id)
       is distinct from v_quiz_id
     or (select count(*) from public.lesson_pages
         where lesson_id = v_lesson_id) <> 10
     or (select count(distinct display_order) from public.lesson_pages
         where lesson_id = v_lesson_id) <> 10
     or (select count(*) from public.quiz_questions
         where quiz_id = v_quiz_id) <> 10
     or (select count(distinct question_id) from public.quiz_questions
         where quiz_id = v_quiz_id) <> 10
     or (select count(*)
         from public.question_choices qc
         join public.quiz_questions qq on qq.question_id = qc.question_id
         where qq.quiz_id = v_quiz_id) <> 40
     or exists (
       select 1
       from public.quiz_questions qq
       left join public.question_choices qc on qc.question_id = qq.question_id
       where qq.quiz_id = v_quiz_id
       group by qq.question_id
       having count(qc.id) <> 4
          or count(qc.id) filter (where qc.is_correct) <> 1
     ) then
    raise exception '0092 remaining Types of Fractions graph is incomplete.';
  end if;

  if v_repair_required and (
    exists (
      select 1
      from public.quiz_attempts qa
      cross join _0092_types_repair_state target
      where qa.id = target.delete_attempt_id
         or qa.quiz_id = target.delete_quiz_id
    )
    or exists (
      select 1
      from public.lessons l
      cross join _0092_types_repair_state target
      where l.id = target.delete_lesson_id
    )
    or exists (
      select 1
      from public.quizzes q
      cross join _0092_types_repair_state target
      where q.id = target.delete_quiz_id
    )
    or exists (
      select 1
      from public.question_bank qb
      join _0092_duplicate_questions duplicate on duplicate.id = qb.id
    )
    or exists (
      select 1
      from _0092_types_repair_state target
      where target.keep_attempt_was_present
        and not exists (
          select 1
          from public.quiz_attempts qa
          where qa.id = target.keep_attempt_id
            and qa.quiz_id = target.keep_quiz_id
        )
    )
  ) then
    raise exception '0092 targeted deletion or preserved-attempt verification failed.';
  end if;
end;
$verify$;

commit;
