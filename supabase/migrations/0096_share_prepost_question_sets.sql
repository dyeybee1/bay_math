-- =============================================================================
-- Migration: 0096_share_prepost_question_sets.sql
--
-- Makes each built-in Grade 4-6 Pre-Test/Post-Test pair use one canonical
-- question set. The canonical rows are the validated regular-quiz questions
-- that migration 0086 copied into the assessment-owned rows for each Pre-Test.
-- Both assessments now link directly to those same question_bank rows, so they
-- also share the same question_choices rows and correct-answer flags.
--
-- Historical safety:
--   * quiz_attempts and all answer/snapshot rows are never deleted.
--   * Completed/superseded answers are never updated. Active-answer live
--     question/choice backlinks are remapped by question position so an
--     in-progress attempt can resume; its frozen prompt, choice snapshots,
--     correctness, and answer timestamp remain byte-for-byte unchanged.
--   * An assessment-owned question is deleted only when no quiz link, answer,
--     or selected-choice backlink still references it.
--   * Legacy rows needed by historical answers remain as unlinked historical
--     records with their choices intact.
--   * The migration refuses to remap an active attempt that already has an
--     answer, because that attempt began with the former question-id set.
-- =============================================================================

begin;

set local lock_timeout = '10s';
set local statement_timeout = '2min';

lock table
  public.quizzes,
  public.quiz_questions,
  public.question_bank,
  public.question_choices,
  public.quiz_attempts,
  public.quiz_attempt_answers,
  public.quiz_attempt_answer_choice_snapshots
in share row exclusive mode;

create temporary table _0096_expected_assessments (
  grade_level grade_level not null,
  assessment_type assessment_type not null,
  title text not null,
  primary key (grade_level, assessment_type)
) on commit drop;

insert into _0096_expected_assessments (
  grade_level,
  assessment_type,
  title
) values
  ('grade_4', 'pre_test',  'Grade 4 Pre-Test'),
  ('grade_4', 'post_test', 'Grade 4 Post-Test'),
  ('grade_5', 'pre_test',  'Grade 5 Pre-Test'),
  ('grade_5', 'post_test', 'Grade 5 Post-Test'),
  ('grade_6', 'pre_test',  'Grade 6 Pre-Test'),
  ('grade_6', 'post_test', 'Grade 6 Post-Test');

do $guard$
declare
  v_expected record;
  v_match_count integer;
begin
  for v_expected in
    select *
    from _0096_expected_assessments
    order by grade_level, assessment_type
  loop
    select count(*)
    into v_match_count
    from public.quizzes q
    where q.title = v_expected.title
      and q.quiz_type = 'internal'
      and q.source_type = 'built_in'
      and q.created_by is null
      and q.grade_level = v_expected.grade_level
      and q.assessment_type = v_expected.assessment_type;

    if v_match_count <> 1 then
      raise exception using
        errcode = '55000',
        message = format(
          '0096 expected exactly one %s (%s); found %s.',
          v_expected.title,
          v_expected.assessment_type,
          v_match_count
        );
    end if;
  end loop;
end;
$guard$;

create temporary table _0096_assessments (
  grade_level grade_level primary key,
  pre_quiz_id uuid not null unique,
  post_quiz_id uuid not null unique
) on commit drop;

insert into _0096_assessments (grade_level, pre_quiz_id, post_quiz_id)
select
  grade.grade_level,
  pre_quiz.id,
  post_quiz.id
from (
  values ('grade_4'::grade_level), ('grade_5'::grade_level),
         ('grade_6'::grade_level)
) as grade(grade_level)
join public.quizzes pre_quiz
  on pre_quiz.title = 'Grade ' || right(grade.grade_level::text, 1) || ' Pre-Test'
 and pre_quiz.quiz_type = 'internal'
 and pre_quiz.source_type = 'built_in'
 and pre_quiz.created_by is null
 and pre_quiz.grade_level = grade.grade_level
 and pre_quiz.assessment_type = 'pre_test'
join public.quizzes post_quiz
  on post_quiz.title = 'Grade ' || right(grade.grade_level::text, 1) || ' Post-Test'
 and post_quiz.quiz_type = 'internal'
 and post_quiz.source_type = 'built_in'
 and post_quiz.created_by is null
 and post_quiz.grade_level = grade.grade_level
 and post_quiz.assessment_type = 'post_test';

create temporary table _0096_source_plan (
  grade_level grade_level not null,
  source_order smallint not null,
  source_quiz_title text not null,
  take_count smallint not null,
  primary key (grade_level, source_order)
) on commit drop;

insert into _0096_source_plan (
  grade_level,
  source_order,
  source_quiz_title,
  take_count
) values
  (
    'grade_4', 1,
    'Quiz 1: Addition and Subtraction of Numbers up to 1,000,000', 6
  ),
  (
    'grade_4', 2,
    'Quiz 2: Comparing Numbers up to 1,000,000', 6
  ),
  ('grade_4', 3, 'Quiz 3: Place Value of Whole Numbers', 6),
  ('grade_4', 4, 'Quiz 4: Multiplication, Division, and MDAS', 6),
  ('grade_4', 5, 'Quiz 5: Types of Fractions', 6),
  ('grade_5', 1, 'Quiz 3: Multiplying and Dividing Fractions', 10),
  ('grade_5', 2, 'Quiz 4: Finding the Area of Plane Figures', 10),
  (
    'grade_5', 3,
    'Quiz 5: Adding, Subtracting, and Multiplying Decimals', 10
  ),
  ('grade_6', 1, 'Quiz 2: Operations with Decimals', 10),
  ('grade_6', 2, 'Quiz 3: Understanding Ratio and Proportion', 10),
  ('grade_6', 3, 'Quiz 4: Exponents and GEMDAS', 10);

create temporary table _0096_source_quizzes (
  grade_level grade_level not null,
  source_order smallint not null,
  source_quiz_title text not null,
  take_count smallint not null,
  quiz_id uuid,
  primary key (grade_level, source_order)
) on commit drop;

insert into _0096_source_quizzes (
  grade_level,
  source_order,
  source_quiz_title,
  take_count,
  quiz_id
)
select
  plan.grade_level,
  plan.source_order,
  plan.source_quiz_title,
  plan.take_count,
  (
    select q.id
    from public.quizzes q
    where q.title = plan.source_quiz_title
      and q.quiz_type = 'internal'
      and q.source_type = 'built_in'
      and q.created_by is null
      and q.grade_level = plan.grade_level
      and q.assessment_type is null
    order by q.created_at, q.id
    limit 1
  )
from _0096_source_plan plan;

do $source_guard$
declare
  v_source record;
  v_question_count integer;
begin
  for v_source in
    select *
    from _0096_source_quizzes
    order by grade_level, source_order
  loop
    if v_source.quiz_id is null then
      raise exception '0096 source quiz not found for %: %',
        v_source.grade_level, v_source.source_quiz_title;
    end if;

    select count(*)
    into v_question_count
    from public.quiz_questions qq
    where qq.quiz_id = v_source.quiz_id;

    if v_question_count < v_source.take_count then
      raise exception
        '0096 source quiz % needs at least % questions; found %.',
        v_source.source_quiz_title,
        v_source.take_count,
        v_question_count;
    end if;
  end loop;
end;
$source_guard$;

create temporary table _0096_shared_questions (
  grade_level grade_level not null,
  display_order smallint not null,
  question_id uuid not null,
  primary key (grade_level, display_order),
  unique (grade_level, question_id)
) on commit drop;

insert into _0096_shared_questions (
  grade_level,
  display_order,
  question_id
)
select
  source.grade_level,
  (
    coalesce((
      select sum(prior.take_count)
      from _0096_source_quizzes prior
      where prior.grade_level = source.grade_level
        and prior.source_order < source.source_order
    ), 0) + selected.relative_order
  )::smallint,
  selected.question_id
from _0096_source_quizzes source
cross join lateral (
  select
    qq.question_id,
    row_number() over (order by qq.display_order)::smallint as relative_order
  from public.quiz_questions qq
  where qq.quiz_id = source.quiz_id
  order by qq.display_order
  limit source.take_count
) selected;

do $content_guard$
begin
  if exists (
    select 1
    from (
      values ('grade_4'::grade_level), ('grade_5'::grade_level),
             ('grade_6'::grade_level)
    ) grade(grade_level)
    where (
      select count(*)
      from _0096_shared_questions shared
      where shared.grade_level = grade.grade_level
    ) <> 30
  ) then
    raise exception '0096 did not build exactly 30 canonical questions per grade.';
  end if;

  if (
    select count(distinct shared.question_id)
    from _0096_shared_questions shared
  ) <> 90 then
    raise exception '0096 canonical question sets overlap across grade levels.';
  end if;

  if exists (
    select 1
    from _0096_shared_questions shared
    left join public.question_bank qb on qb.id = shared.question_id
    where qb.id is null
       or qb.source_type <> 'built_in'
       or qb.created_by is not null
  ) or exists (
    select shared.question_id
    from _0096_shared_questions shared
    left join public.question_choices qc on qc.question_id = shared.question_id
    group by shared.question_id
    having count(qc.id) <> 4
       or count(qc.id) filter (where qc.is_correct) <> 1
  ) then
    raise exception
      '0096 every canonical question must be built-in with four choices and one correct answer.';
  end if;
end;
$content_guard$;

create temporary table _0096_legacy_mappings (
  grade_level grade_level not null,
  quiz_id uuid not null,
  old_question_id uuid not null,
  new_question_id uuid not null,
  display_order smallint not null,
  primary key (quiz_id, old_question_id),
  unique (quiz_id, display_order)
) on commit drop;

insert into _0096_legacy_mappings (
  grade_level,
  quiz_id,
  old_question_id,
  new_question_id,
  display_order
)
select
  assessment.grade_level,
  link.quiz_id,
  link.question_id,
  shared.question_id,
  link.display_order
from _0096_assessments assessment
join public.quiz_questions link
  on link.quiz_id in (assessment.pre_quiz_id, assessment.post_quiz_id)
join _0096_shared_questions shared
  on shared.grade_level = assessment.grade_level
 and shared.display_order = link.display_order;

do $mapping_guard$
begin
  if (select count(*) from _0096_legacy_mappings) <> 180
     or exists (
       select assessment_quiz.quiz_id
       from (
         select pre_quiz_id as quiz_id from _0096_assessments
         union all
         select post_quiz_id from _0096_assessments
       ) assessment_quiz
       left join _0096_legacy_mappings mapping
         on mapping.quiz_id = assessment_quiz.quiz_id
       group by assessment_quiz.quiz_id
       having count(mapping.old_question_id) <> 30
     ) then
    raise exception
      '0096 each of the six existing assessments must have exactly 30 position-mappable questions.';
  end if;
end;
$mapping_guard$;

create temporary table _0096_legacy_questions (
  question_id uuid primary key
) on commit drop;

insert into _0096_legacy_questions (question_id)
select distinct mapping.old_question_id
from _0096_legacy_mappings mapping;

create temporary table _0096_history_counts on commit drop as
select
  count(distinct attempt.id) as attempt_count,
  count(distinct answer.id) as answer_count,
  count(distinct snapshot.id) as snapshot_count
from _0096_assessments assessment
join public.quiz_attempts attempt
  on attempt.quiz_id in (assessment.pre_quiz_id, assessment.post_quiz_id)
left join public.quiz_attempt_answers answer
  on answer.quiz_attempt_id = attempt.id
left join public.quiz_attempt_answer_choice_snapshots snapshot
  on snapshot.quiz_attempt_answer_id = answer.id;

-- Preserve every former assessment question that had ever produced an answer,
-- including answers in active attempts whose live backlink is remapped below.
-- These rows are historical evidence, not cleanup candidates.
create temporary table _0096_answered_legacy_questions (
  question_id uuid primary key
) on commit drop;

insert into _0096_answered_legacy_questions (question_id)
select distinct answer.question_id
from _0096_assessments assessment
join public.quiz_attempts attempt
  on attempt.quiz_id in (assessment.pre_quiz_id, assessment.post_quiz_id)
join public.quiz_attempt_answers answer
  on answer.quiz_attempt_id = attempt.id
join _0096_legacy_questions legacy
  on legacy.question_id = answer.question_id;

create temporary table _0096_answer_state on commit drop as
select
  answer.id,
  attempt.attempt_status,
  answer.question_id,
  answer.selected_choice_id,
  answer.question_text_snapshot,
  answer.is_correct,
  answer.answered_at,
  coalesce((
    select jsonb_agg(
      jsonb_build_array(
        snapshot.choice_text_snapshot,
        snapshot.was_correct,
        snapshot.was_selected,
        snapshot.display_order
      ) order by snapshot.display_order
    )
    from public.quiz_attempt_answer_choice_snapshots snapshot
    where snapshot.quiz_attempt_answer_id = answer.id
  ), '[]'::jsonb) as choice_snapshots
from _0096_assessments assessment
join public.quiz_attempts attempt
  on attempt.quiz_id in (assessment.pre_quiz_id, assessment.post_quiz_id)
join public.quiz_attempt_answers answer
  on answer.quiz_attempt_id = attempt.id;

do $active_answer_guard$
begin
  if exists (
    select 1
    from _0096_assessments assessment
    join public.quiz_attempts attempt
      on attempt.quiz_id in (
        assessment.pre_quiz_id,
        assessment.post_quiz_id
      )
    join public.quiz_attempt_answers answer
      on answer.quiz_attempt_id = attempt.id
    left join _0096_legacy_mappings mapping
      on mapping.quiz_id = attempt.quiz_id
     and mapping.old_question_id = answer.question_id
    where attempt.attempt_status = 'active'
      and mapping.old_question_id is null
  ) then
    raise exception using
      errcode = '55000',
      message = '0096 found an active assessment answer that cannot be mapped by its former quiz position.';
  end if;
end;
$active_answer_guard$;

-- A selected-choice backlink can be retained only when the old and canonical
-- prompts and complete choice sets are semantically identical. Otherwise the
-- live backlink becomes null; the authoritative frozen choice snapshots stay
-- untouched and continue to preserve the selected answer and correctness.
create temporary table _0096_choice_remap (
  old_choice_id uuid primary key,
  new_choice_id uuid not null
) on commit drop;

insert into _0096_choice_remap (old_choice_id, new_choice_id)
select old_choice.id, new_choice.id
from _0096_legacy_mappings mapping
join public.question_bank old_question
  on old_question.id = mapping.old_question_id
join public.question_bank new_question
  on new_question.id = mapping.new_question_id
join public.question_choices old_choice
  on old_choice.question_id = mapping.old_question_id
join public.question_choices new_choice
  on new_choice.question_id = mapping.new_question_id
 and new_choice.display_order = old_choice.display_order
 and new_choice.choice_text = old_choice.choice_text
 and new_choice.is_correct = old_choice.is_correct
where old_question.prompt_text = new_question.prompt_text
  and not exists (
    select
      source_choice.display_order,
      source_choice.choice_text,
      source_choice.is_correct
    from public.question_choices source_choice
    where source_choice.question_id = mapping.old_question_id
    except
    select
      target_choice.display_order,
      target_choice.choice_text,
      target_choice.is_correct
    from public.question_choices target_choice
    where target_choice.question_id = mapping.new_question_id
  )
  and not exists (
    select
      target_choice.display_order,
      target_choice.choice_text,
      target_choice.is_correct
    from public.question_choices target_choice
    where target_choice.question_id = mapping.new_question_id
    except
    select
      source_choice.display_order,
      source_choice.choice_text,
      source_choice.is_correct
    from public.question_choices source_choice
    where source_choice.question_id = mapping.old_question_id
  );

-- Narrow, one-time exception to the immutable-row trigger: only the two live
-- relational backlinks of ACTIVE answers are changed. All frozen historical
-- fields and all submitted/superseded answer rows remain untouched.
alter table public.quiz_attempt_answers disable trigger block_update;

update public.quiz_attempt_answers answer
set
  question_id = mapping.new_question_id,
  selected_choice_id = (
    select choice_remap.new_choice_id
    from _0096_choice_remap choice_remap
    where choice_remap.old_choice_id = answer.selected_choice_id
  )
from public.quiz_attempts attempt,
     _0096_legacy_mappings mapping
where answer.quiz_attempt_id = attempt.id
  and attempt.attempt_status = 'active'
  and attempt.quiz_id = mapping.quiz_id
  and answer.question_id = mapping.old_question_id;

alter table public.quiz_attempt_answers enable trigger block_update;

delete from public.quiz_questions link
using _0096_assessments assessment
where link.quiz_id in (assessment.pre_quiz_id, assessment.post_quiz_id);

insert into public.quiz_questions (quiz_id, question_id, display_order)
select assessment.pre_quiz_id, shared.question_id, shared.display_order
from _0096_assessments assessment
join _0096_shared_questions shared
  on shared.grade_level = assessment.grade_level
union all
select assessment.post_quiz_id, shared.question_id, shared.display_order
from _0096_assessments assessment
join _0096_shared_questions shared
  on shared.grade_level = assessment.grade_level;

-- question_choices cascade only for truly unreferenced legacy questions.
-- The selected-choice check is intentionally redundant with normal answer
-- integrity: it protects traceability even if an old row was malformed.
delete from public.question_bank question
using _0096_legacy_questions legacy
where question.id = legacy.question_id
  and not exists (
    select 1
    from _0096_answered_legacy_questions answered
    where answered.question_id = question.id
  )
  and not exists (
    select 1
    from public.quiz_questions link
    where link.question_id = question.id
  )
  and not exists (
    select 1
    from public.quiz_attempt_answers answer
    where answer.question_id = question.id
  )
  and not exists (
    select 1
    from public.quiz_attempt_answers answer
    join public.question_choices choice
      on choice.id = answer.selected_choice_id
    where choice.question_id = question.id
  );

do $verify$
declare
  v_assessment record;
begin
  for v_assessment in
    select *
    from _0096_assessments
    order by grade_level
  loop
    if (
      select count(*)
      from public.quiz_questions
      where quiz_id = v_assessment.pre_quiz_id
    ) <> 30 or (
      select count(*)
      from public.quiz_questions
      where quiz_id = v_assessment.post_quiz_id
    ) <> 30 then
      raise exception '0096 assessment item count failed for %.',
        v_assessment.grade_level;
    end if;

    if exists (
      select pre.display_order, pre.question_id
      from public.quiz_questions pre
      where pre.quiz_id = v_assessment.pre_quiz_id
      except
      select post.display_order, post.question_id
      from public.quiz_questions post
      where post.quiz_id = v_assessment.post_quiz_id
    ) or exists (
      select post.display_order, post.question_id
      from public.quiz_questions post
      where post.quiz_id = v_assessment.post_quiz_id
      except
      select pre.display_order, pre.question_id
      from public.quiz_questions pre
      where pre.quiz_id = v_assessment.pre_quiz_id
    ) then
      raise exception '0096 Pre-Test/Post-Test IDs or order differ for %.',
        v_assessment.grade_level;
    end if;

    raise notice '0096 %: Pre-Test %, Post-Test %, 30 shared questions',
      v_assessment.grade_level,
      v_assessment.pre_quiz_id,
      v_assessment.post_quiz_id;
  end loop;

  if exists (
    select 1
    from _0096_legacy_questions legacy
    join public.question_bank question on question.id = legacy.question_id
    where not exists (
      select 1
      from public.quiz_questions link
      where link.question_id = question.id
    )
      and not exists (
        select 1
        from _0096_answered_legacy_questions answered
        where answered.question_id = question.id
      )
      and not exists (
        select 1
        from public.quiz_attempt_answers answer
        where answer.question_id = question.id
      )
      and not exists (
        select 1
        from public.quiz_attempt_answers answer
        join public.question_choices choice
          on choice.id = answer.selected_choice_id
        where choice.question_id = question.id
      )
  ) then
    raise exception '0096 left an unreferenced legacy assessment question.';
  end if;

  if exists (
    select 1
    from _0096_answer_state before_answer
    join public.quiz_attempt_answers after_answer
      on after_answer.id = before_answer.id
    where before_answer.attempt_status <> 'active'
      and row(
        after_answer.question_id,
        after_answer.selected_choice_id,
        after_answer.question_text_snapshot,
        after_answer.is_correct,
        after_answer.answered_at
      ) is distinct from row(
        before_answer.question_id,
        before_answer.selected_choice_id,
        before_answer.question_text_snapshot,
        before_answer.is_correct,
        before_answer.answered_at
      )
  ) then
    raise exception '0096 changed a completed or superseded historical answer.';
  end if;

  if exists (
    select 1
    from _0096_answer_state before_answer
    join public.quiz_attempt_answers after_answer
      on after_answer.id = before_answer.id
    where before_answer.attempt_status = 'active'
      and row(
        after_answer.question_text_snapshot,
        after_answer.is_correct,
        after_answer.answered_at,
        coalesce((
          select jsonb_agg(
            jsonb_build_array(
              snapshot.choice_text_snapshot,
              snapshot.was_correct,
              snapshot.was_selected,
              snapshot.display_order
            ) order by snapshot.display_order
          )
          from public.quiz_attempt_answer_choice_snapshots snapshot
          where snapshot.quiz_attempt_answer_id = after_answer.id
        ), '[]'::jsonb)
      ) is distinct from row(
        before_answer.question_text_snapshot,
        before_answer.is_correct,
        before_answer.answered_at,
        before_answer.choice_snapshots
      )
  ) then
    raise exception '0096 changed an active answer snapshot or grading result.';
  end if;

  if exists (
    select 1
    from _0096_assessments assessment
    join public.quiz_attempts attempt
      on attempt.quiz_id in (
        assessment.pre_quiz_id,
        assessment.post_quiz_id
      )
    join public.quiz_attempt_answers answer
      on answer.quiz_attempt_id = attempt.id
    where attempt.attempt_status = 'active'
      and not exists (
        select 1
        from public.quiz_questions link
        where link.quiz_id = attempt.quiz_id
          and link.question_id = answer.question_id
      )
  ) then
    raise exception '0096 left an active answer outside its remapped quiz.';
  end if;

  if exists (
    select 1
    from _0096_history_counts before_counts
    cross join lateral (
      select
        count(distinct attempt.id) as attempt_count,
        count(distinct answer.id) as answer_count,
        count(distinct snapshot.id) as snapshot_count
      from _0096_assessments assessment
      join public.quiz_attempts attempt
        on attempt.quiz_id in (
          assessment.pre_quiz_id,
          assessment.post_quiz_id
        )
      left join public.quiz_attempt_answers answer
        on answer.quiz_attempt_id = attempt.id
      left join public.quiz_attempt_answer_choice_snapshots snapshot
        on snapshot.quiz_attempt_answer_id = answer.id
    ) after_counts
    where row(
      before_counts.attempt_count,
      before_counts.answer_count,
      before_counts.snapshot_count
    ) is distinct from row(
      after_counts.attempt_count,
      after_counts.answer_count,
      after_counts.snapshot_count
    )
  ) then
    raise exception '0096 changed historical attempt, answer, or snapshot counts.';
  end if;
end;
$verify$;

commit;
