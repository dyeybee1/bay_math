-- =============================================================================
-- Migration: 0088_repair_educational_unicode_escapes.sql
--
-- Repairs Grade 6 Quiz 4 educational text seeded by 0085. That migration
-- used ordinary PostgreSQL string literals for JSON-style Unicode escape
-- sequences, so PostgreSQL stored the backslash-u text literally. The same
-- question_bank rows feed both regular quizzes and Endless Quiz.
--
-- The replacement set below covers every escaped code point present in 0085:
-- superscript 2/4/5/8, multiplication, division, and mathematical minus.
-- It is deliberately scoped to Quiz 4 and its frozen answer snapshots; it
-- does not reinterpret arbitrary teacher-authored or application text.
--
-- Idempotent: after the first run none of the source strings remain, so a
-- repeated run makes no further changes.
-- =============================================================================

do $$
declare
  v_escape text;
  v_symbol text;
begin
  for v_escape, v_symbol in
    select escaped, symbol
    from (
      values
        (chr(92) || 'u00b2', '²'),
        (chr(92) || 'u00d7', '×'),
        (chr(92) || 'u00f7', '÷'),
        (chr(92) || 'u2074', '⁴'),
        (chr(92) || 'u2075', '⁵'),
        (chr(92) || 'u2078', '⁸'),
        (chr(92) || 'u2212', '−')
    ) as replacements(escaped, symbol)
  loop
    update public.question_bank qb
    set prompt_text = replace(qb.prompt_text, v_escape, v_symbol),
        explanation_text = replace(qb.explanation_text, v_escape, v_symbol)
    where qb.id in (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.title = 'Quiz 4: Exponents and GEMDAS'
        and q.source_type = 'built_in'
        and q.grade_level = 'grade_6'
    )
      and (
        strpos(qb.prompt_text, v_escape) > 0
        or strpos(qb.explanation_text, v_escape) > 0
      );

    update public.question_choices qc
    set choice_text = replace(qc.choice_text, v_escape, v_symbol)
    where qc.question_id in (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.title = 'Quiz 4: Exponents and GEMDAS'
        and q.source_type = 'built_in'
        and q.grade_level = 'grade_6'
    )
      and strpos(qc.choice_text, v_escape) > 0;

    update public.quiz_attempt_answers qaa
    set question_text_snapshot = replace(
      qaa.question_text_snapshot,
      v_escape,
      v_symbol
    )
    where qaa.question_id in (
      select qq.question_id
      from public.quiz_questions qq
      join public.quizzes q on q.id = qq.quiz_id
      where q.title = 'Quiz 4: Exponents and GEMDAS'
        and q.source_type = 'built_in'
        and q.grade_level = 'grade_6'
    )
      and strpos(qaa.question_text_snapshot, v_escape) > 0;

    update public.quiz_attempt_answer_choice_snapshots qacs
    set choice_text_snapshot = replace(
      qacs.choice_text_snapshot,
      v_escape,
      v_symbol
    )
    where qacs.quiz_attempt_answer_id in (
      select qaa.id
      from public.quiz_attempt_answers qaa
      join public.quiz_questions qq on qq.question_id = qaa.question_id
      join public.quizzes q on q.id = qq.quiz_id
      where q.title = 'Quiz 4: Exponents and GEMDAS'
        and q.source_type = 'built_in'
        and q.grade_level = 'grade_6'
    )
      and strpos(qacs.choice_text_snapshot, v_escape) > 0;
  end loop;
end $$;
