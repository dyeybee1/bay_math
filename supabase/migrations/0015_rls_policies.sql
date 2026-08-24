-- =============================================================================
-- Migration: 0015_rls_policies.sql
-- Implements: Phase 2 schema §7 (RLS Responsibility Mapping) as executable
-- row-level security policies.
--
-- Revision (post-Phase-3 hardening audit): multiple corrections applied —
-- see the audit findings inline below, and the full summary in the response
-- accompanying this migration set. Highlights: a critical recursive-RLS bug
-- that would have hidden all lesson/quiz content from every student was
-- fixed; DELETE was removed from historical/permanent-identity tables where
-- it had been inadvertently granted; several student INSERT policies were
-- tightened to validate cross-table consistency they previously skipped.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Small safety trigger: a Teacher may update their own profiles row (schema
-- §7: "Teacher: Read/update own row only") but must never be able to
-- self-approve, change their own role, or forge who approved them. RLS alone
-- is row-level, not column-level, so this is enforced with a trigger rather
-- than a policy — a faithful implementation of the already-approved
-- "Admin approves teachers" rule (blueprint), not a new business rule.
-- ---------------------------------------------------------------------------
create or replace function app.profiles_protect_privileged_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not app.is_admin() then
    if new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.approved_by is distinct from old.approved_by
       or new.approved_at is distinct from old.approved_at then
      raise exception
        'profiles: role, status, approved_by, and approved_at can only be changed by an Admin';
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_privileged_fields before update on public.profiles
  for each row execute function app.profiles_protect_privileged_fields();

-- =============================================================================
-- Enable RLS on every table (default-deny, per schema §11.1).
-- =============================================================================
alter table public.schools enable row level security;
alter table public.school_years enable row level security;
alter table public.profiles enable row level security;
alter table public.sections enable row level security;
alter table public.teacher_sections enable row level security;
alter table public.students enable row level security;
alter table public.student_enrollments enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_sections enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.question_bank enable row level security;
alter table public.question_choices enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_sections enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.quiz_attempt_answers enable row level security;
alter table public.quiz_attempt_answer_choice_snapshots enable row level security;
alter table public.endless_quiz_sessions enable row level security;
alter table public.audit_logs enable row level security;

-- =============================================================================
-- schools — Admin: Full · Teacher: Read · Student: —
-- =============================================================================
create policy schools_select on public.schools for select
  using (app.is_admin() or app.is_approved_teacher());
create policy schools_admin_write on public.schools for all
  using (app.is_admin()) with check (app.is_admin());

-- =============================================================================
-- school_years — Admin: Full · Teacher: Read · Student: —
-- =============================================================================
create policy school_years_select on public.school_years for select
  using (app.is_admin() or app.is_approved_teacher());
create policy school_years_admin_write on public.school_years for all
  using (app.is_admin()) with check (app.is_admin());

-- =============================================================================
-- profiles — Admin: Full · Teacher: Read/update own row only
-- =============================================================================
create policy profiles_select on public.profiles for select
  using (app.is_admin() or id = auth.uid());
create policy profiles_self_update on public.profiles for update
  using (id = auth.uid() or app.is_admin())
  with check (id = auth.uid() or app.is_admin());
create policy profiles_admin_insert on public.profiles for insert
  with check (app.is_admin() or id = auth.uid()); -- self-registration creates own row (role='teacher', status='pending')
create policy profiles_admin_delete on public.profiles for delete
  using (app.is_admin());

-- =============================================================================
-- sections — Admin: Full · Teacher: Read own assigned · Student: indirect only
-- =============================================================================
create policy sections_select on public.sections for select
  using (app.is_admin() or app.teacher_has_section(id));
create policy sections_admin_write on public.sections for all
  using (app.is_admin()) with check (app.is_admin());

-- =============================================================================
-- teacher_sections — Admin: Full · Teacher: Read own rows
-- =============================================================================
create policy teacher_sections_select on public.teacher_sections for select
  using (app.is_admin() or teacher_id = auth.uid());
create policy teacher_sections_admin_write on public.teacher_sections for all
  using (app.is_admin()) with check (app.is_admin());

-- =============================================================================
-- students — Admin: Full · Teacher: R/W scoped to currently assigned section
-- (via active student_enrollments) · Student: —
-- =============================================================================
create policy students_select on public.students for select
  using (app.is_admin() or app.teacher_has_student(id));
create policy students_teacher_insert on public.students for insert
  with check (app.is_admin() or (app.is_approved_teacher() and created_by = auth.uid()));
create policy students_teacher_update on public.students for update
  using (app.is_admin() or app.teacher_has_student(id))
  with check (app.is_admin() or app.teacher_has_student(id));

-- AUDIT FINDING (Severity: MEDIUM-HIGH, fixed here): a students_admin_delete
-- policy previously existed, allowing Admin to hard-delete a student row.
-- `students` is explicitly one of this schema's "permanent-identity"
-- entities (schema §0): it is designed to be transferred/enrolled, never
-- deleted — that is the entire point of student_enrollments existing as a
-- separate, closeable join rather than a mutable section_id on students
-- itself. No DELETE policy is defined for any role here; RLS defaults to
-- deny, so students can never be deleted via the API by anyone, including
-- Admin. (A brand-new student with a FK-restricted enrollment row cannot be
-- deleted anyway due to referential integrity — this policy removal makes
-- that guarantee explicit and immediate rather than incidental.)

-- =============================================================================
-- student_enrollments — Admin: Full (except delete — see below) ·
-- Teacher: R/W scoped to own sections · Student: read own row only
-- =============================================================================
--
-- AUDIT FINDING (Severity: CRITICAL, fixed here): the original select policy
-- had no clause granting a student visibility into their OWN enrollment row.
-- Several OTHER policies (lessons/quizzes/lesson_sections/quiz_sections,
-- student-facing branches) relied on a raw subquery joining against this
-- table to determine section membership. Because Postgres RLS re-applies a
-- table's own policies to every subquery that touches it — regardless of
-- which other policy's USING/WITH CHECK clause embeds that subquery — those
-- raw joins silently returned zero rows for every student, meaning students
-- would never have been able to see ANY lesson or quiz content at all, even
-- with fully working authentication. Fixed two ways together: (1) this
-- policy now explicitly grants a student their own row, and (2) the
-- downstream policies were rewritten to go through the new SECURITY DEFINER
-- app.student_has_section() helper (see 0013), which bypasses this
-- recursion entirely — the same pattern already used for Teacher-side
-- checks via app.teacher_has_section().
create policy student_enrollments_select on public.student_enrollments for select
  using (app.is_admin() or app.teacher_has_section(section_id) or student_id = app.current_student_id());
create policy student_enrollments_teacher_insert on public.student_enrollments for insert
  with check (app.is_admin() or (app.is_approved_teacher() and app.teacher_has_section(section_id)));
create policy student_enrollments_teacher_update on public.student_enrollments for update
  using (app.is_admin() or app.teacher_has_section(section_id))
  with check (app.is_admin() or app.teacher_has_section(section_id));

-- AUDIT FINDING (Severity: MEDIUM-HIGH, fixed here): same reasoning as
-- students_admin_delete above — student_enrollments rows are closed (status
-- transition), never deleted, per the approved transfer workflow ("the old
-- one is closed, not deleted"). No DELETE policy is defined for any role.

-- =============================================================================
-- lessons — Admin: Full · Teacher: CRUD own + read built-in ·
-- Student: read only what's visible via their active section
-- =============================================================================
create policy lessons_teacher_select on public.lessons for select
  using (
    app.is_admin()
    or (app.is_approved_teacher() and (source_type = 'built_in' or created_by = auth.uid()))
  );
create policy lessons_student_select on public.lessons for select
  using (
    app.current_student_id() is not null
    and (
      source_type = 'built_in'
      or exists (
        select 1 from public.lesson_sections ls
        where ls.lesson_id = lessons.id
          and app.student_has_section(ls.section_id)
      )
    )
  );
create policy lessons_teacher_insert on public.lessons for insert
  with check (app.is_admin() or (app.is_approved_teacher() and source_type = 'teacher' and created_by = auth.uid()));
create policy lessons_teacher_update on public.lessons for update
  using (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()))
  with check (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()));
create policy lessons_teacher_delete on public.lessons for delete
  using (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()));

-- =============================================================================
-- lesson_sections — Admin: Full · Teacher: write only own content into own
-- sections · Student: indirect (read via lessons policy above)
-- =============================================================================
create policy lesson_sections_select on public.lesson_sections for select
  using (
    app.is_admin()
    or app.teacher_has_section(section_id)
    or app.student_has_section(section_id)
  );
create policy lesson_sections_teacher_insert on public.lesson_sections for insert
  with check (
    app.is_admin()
    or (
      app.is_approved_teacher()
      and app.teacher_has_section(section_id)
      and exists (select 1 from public.lessons l where l.id = lesson_id and l.created_by = auth.uid())
    )
  );
create policy lesson_sections_teacher_delete on public.lesson_sections for delete
  using (
    app.is_admin()
    or (
      app.is_approved_teacher()
      and app.teacher_has_section(section_id)
      and exists (select 1 from public.lessons l where l.id = lesson_id and l.created_by = auth.uid())
    )
  );

-- =============================================================================
-- lesson_progress — Admin: Read all · Teacher: read scoped to own sections'
-- students · Student: write own rows only
-- =============================================================================
create policy lesson_progress_select on public.lesson_progress for select
  using (app.is_admin() or app.teacher_has_student(student_id) or student_id = app.current_student_id());

-- AUDIT FINDING (Severity: MEDIUM, fixed here): the original INSERT check
-- only verified the row belonged to the calling student, not that the
-- referenced lesson was actually one they have visibility into (built-in,
-- or assigned to their current section). Tightened to match the same
-- validation lessons_student_select itself applies.
create policy lesson_progress_student_insert on public.lesson_progress for insert
  with check (
    app.is_admin()
    or (
      student_id = app.current_student_id()
      and exists (
        select 1 from public.lessons l
        where l.id = lesson_progress.lesson_id
          and (
            l.source_type = 'built_in'
            or exists (
              select 1 from public.lesson_sections ls
              where ls.lesson_id = l.id and app.student_has_section(ls.section_id)
            )
          )
      )
    )
  );
create policy lesson_progress_student_update on public.lesson_progress for update
  using (student_id = app.current_student_id() or app.is_admin())
  with check (student_id = app.current_student_id() or app.is_admin());

-- =============================================================================
-- question_bank — Admin: Full · Teacher: CRUD own + read built-in ·
-- Student: never queried directly (served via a sanitized RPC, Phase 4)
-- =============================================================================
create policy question_bank_teacher_select on public.question_bank for select
  using (app.is_admin() or (app.is_approved_teacher() and (source_type = 'built_in' or created_by = auth.uid())));
create policy question_bank_teacher_insert on public.question_bank for insert
  with check (app.is_admin() or (app.is_approved_teacher() and source_type = 'teacher' and created_by = auth.uid()));
create policy question_bank_teacher_update on public.question_bank for update
  using (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()))
  with check (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()));
create policy question_bank_teacher_delete on public.question_bank for delete
  using (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()));

-- =============================================================================
-- question_choices — Admin: Full · Teacher: CRUD via owning question ·
-- Student: never queried directly
-- =============================================================================
create policy question_choices_teacher_select on public.question_choices for select
  using (
    app.is_admin()
    or (app.is_approved_teacher() and exists (
      select 1 from public.question_bank qb
      where qb.id = question_choices.question_id
        and (qb.source_type = 'built_in' or qb.created_by = auth.uid())
    ))
  );
create policy question_choices_teacher_write on public.question_choices for all
  using (
    app.is_admin()
    or exists (
      select 1 from public.question_bank qb
      where qb.id = question_choices.question_id
        and qb.source_type = 'teacher' and qb.created_by = auth.uid()
    )
  )
  with check (
    app.is_admin()
    or exists (
      select 1 from public.question_bank qb
      where qb.id = question_choices.question_id
        and qb.source_type = 'teacher' and qb.created_by = auth.uid()
    )
  );

-- =============================================================================
-- quizzes — same pattern as lessons (§7.4 shares the ownership model)
-- =============================================================================
create policy quizzes_teacher_select on public.quizzes for select
  using (app.is_admin() or (app.is_approved_teacher() and (source_type = 'built_in' or created_by = auth.uid())));
create policy quizzes_student_select on public.quizzes for select
  using (
    app.current_student_id() is not null
    and (
      source_type = 'built_in'
      or exists (
        select 1 from public.quiz_sections qs
        where qs.quiz_id = quizzes.id
          and app.student_has_section(qs.section_id)
      )
    )
  );
create policy quizzes_teacher_insert on public.quizzes for insert
  with check (app.is_admin() or (app.is_approved_teacher() and source_type = 'teacher' and created_by = auth.uid()));
create policy quizzes_teacher_update on public.quizzes for update
  using (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()))
  with check (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()));
create policy quizzes_teacher_delete on public.quizzes for delete
  using (app.is_admin() or (source_type = 'teacher' and created_by = auth.uid()));

-- =============================================================================
-- quiz_sections — same pattern as lesson_sections
-- =============================================================================
create policy quiz_sections_select on public.quiz_sections for select
  using (
    app.is_admin()
    or app.teacher_has_section(section_id)
    or app.student_has_section(section_id)
  );
create policy quiz_sections_teacher_insert on public.quiz_sections for insert
  with check (
    app.is_admin()
    or (
      app.is_approved_teacher()
      and app.teacher_has_section(section_id)
      and exists (select 1 from public.quizzes q where q.id = quiz_id and q.created_by = auth.uid())
    )
  );
create policy quiz_sections_teacher_delete on public.quiz_sections for delete
  using (
    app.is_admin()
    or (
      app.is_approved_teacher()
      and app.teacher_has_section(section_id)
      and exists (select 1 from public.quizzes q where q.id = quiz_id and q.created_by = auth.uid())
    )
  );

-- =============================================================================
-- quiz_questions — visible/writable only via the owning (Internal) quiz's
-- owner; students never query this directly (served via RPC, Phase 4)
-- =============================================================================
create policy quiz_questions_teacher_select on public.quiz_questions for select
  using (
    app.is_admin()
    or exists (
      select 1 from public.quizzes q
      where q.id = quiz_questions.quiz_id
        and (q.source_type = 'built_in' or q.created_by = auth.uid())
    )
  );
create policy quiz_questions_teacher_write on public.quiz_questions for all
  using (
    app.is_admin()
    or exists (
      select 1 from public.quizzes q
      where q.id = quiz_questions.quiz_id
        and q.source_type = 'teacher' and q.created_by = auth.uid()
    )
  )
  with check (
    app.is_admin()
    or exists (
      select 1 from public.quizzes q
      where q.id = quiz_questions.quiz_id
        and q.source_type = 'teacher' and q.created_by = auth.uid()
    )
  );

-- =============================================================================
-- quiz_attempts — Admin: Read all · Teacher: read scoped to own sections,
-- write only via reset · Student: create/write own attempt only
-- =============================================================================
create policy quiz_attempts_select on public.quiz_attempts for select
  using (app.teacher_has_section(section_id) or student_id = app.current_student_id());

-- AUDIT FINDING (Severity: HIGH, fixed here): the original WITH CHECK only
-- verified student_id matched the caller — it never validated that
-- section_id/school_year_id reflected the student's REAL current enrollment,
-- or that the quiz was actually visible/assigned to that section. A
-- malicious or buggy client could have inserted an attempt row with
-- forged historical context (wrong section, wrong year) or attempted a quiz
-- never assigned to them at all. Tightened to validate both.
create policy quiz_attempts_student_insert on public.quiz_attempts for insert
  with check (
    student_id = app.current_student_id()
    and exists (
      select 1
      from public.student_enrollments se
      join public.sections s on s.id = se.section_id
      where se.student_id = quiz_attempts.student_id
        and se.section_id = quiz_attempts.section_id
        and se.status = 'active'
        and s.school_year_id = quiz_attempts.school_year_id
    )
    and exists (
      select 1 from public.quizzes q
      where q.id = quiz_attempts.quiz_id
        and (
          q.source_type = 'built_in'
          or exists (
            select 1 from public.quiz_sections qs
            where qs.quiz_id = q.id and qs.section_id = quiz_attempts.section_id
          )
        )
    )
  );

-- Student submitting their own in-progress attempt (may not touch
-- attempt_status toward 'superseded' — that is the teacher-reset path only).
create policy quiz_attempts_student_submit on public.quiz_attempts for update
  using (student_id = app.current_student_id())
  with check (student_id = app.current_student_id() and attempt_status = 'active');

-- Teacher performing a manual reset within their own section.
create policy quiz_attempts_teacher_reset on public.quiz_attempts for update
  using (app.is_approved_teacher() and app.teacher_has_section(section_id))
  with check (app.is_approved_teacher() and app.teacher_has_section(section_id) and attempt_status = 'superseded');

-- AUDIT FINDING (Severity: HIGH, fixed here): a single `for all` admin
-- policy inadvertently granted Admin DELETE on quiz_attempts, contradicting
-- the approved "historical quiz records are never deleted, only superseded"
-- rule — a rule that applies to every role, Admin included. Split into
-- three command-specific policies so DELETE is never granted to anyone.
create policy quiz_attempts_admin_select on public.quiz_attempts for select
  using (app.is_admin());
create policy quiz_attempts_admin_insert on public.quiz_attempts for insert
  with check (app.is_admin());
create policy quiz_attempts_admin_update on public.quiz_attempts for update
  using (app.is_admin()) with check (app.is_admin());

-- =============================================================================
-- quiz_attempt_answers — same visibility shape as quiz_attempts, joined
-- through it (no direct section_id/student_id column on this table)
-- =============================================================================
create policy quiz_attempt_answers_select on public.quiz_attempt_answers for select
  using (
    app.is_admin()
    or exists (
      select 1 from public.quiz_attempts qa
      where qa.id = quiz_attempt_answers.quiz_attempt_id
        and (app.teacher_has_section(qa.section_id) or qa.student_id = app.current_student_id())
    )
  );

-- AUDIT FINDING (Severity: MEDIUM, fixed here): the original check verified
-- the answer belonged to the student's own active attempt, but never
-- verified that question_id was actually one of the quiz's own questions —
-- a student could submit an answer row referencing an unrelated question.
create policy quiz_attempt_answers_student_insert on public.quiz_attempt_answers for insert
  with check (
    app.is_admin()
    or exists (
      select 1 from public.quiz_attempts qa
      where qa.id = quiz_attempt_answers.quiz_attempt_id
        and qa.student_id = app.current_student_id()
        and qa.attempt_status = 'active'
        and exists (
          select 1 from public.quiz_questions qq
          where qq.quiz_id = qa.quiz_id and qq.question_id = quiz_attempt_answers.question_id
        )
    )
  );

-- =============================================================================
-- quiz_attempt_answer_choice_snapshots — same shape, one join deeper
-- =============================================================================
create policy quiz_attempt_answer_choice_snapshots_select on public.quiz_attempt_answer_choice_snapshots for select
  using (
    app.is_admin()
    or exists (
      select 1 from public.quiz_attempt_answers qaa
      join public.quiz_attempts qa on qa.id = qaa.quiz_attempt_id
      where qaa.id = quiz_attempt_answer_choice_snapshots.quiz_attempt_answer_id
        and (app.teacher_has_section(qa.section_id) or qa.student_id = app.current_student_id())
    )
  );
create policy quiz_attempt_answer_choice_snapshots_student_insert on public.quiz_attempt_answer_choice_snapshots for insert
  with check (
    app.is_admin()
    or exists (
      select 1 from public.quiz_attempt_answers qaa
      join public.quiz_attempts qa on qa.id = qaa.quiz_attempt_id
      where qaa.id = quiz_attempt_answer_choice_snapshots.quiz_attempt_answer_id
        and qa.student_id = app.current_student_id()
        and qa.attempt_status = 'active'
    )
  );

-- =============================================================================
-- endless_quiz_sessions — Admin: Read all · Teacher: NO ACCESS (structural —
-- no teacher policy is defined at all, so RLS default-deny applies) ·
-- Student: write own rows at session end only
-- =============================================================================
create policy endless_quiz_sessions_select on public.endless_quiz_sessions for select
  using (app.is_admin() or student_id = app.current_student_id());
create policy endless_quiz_sessions_student_insert on public.endless_quiz_sessions for insert
  with check (student_id = app.current_student_id() or app.is_admin());

-- =============================================================================
-- audit_logs — Admin: Read only. No INSERT/UPDATE/DELETE policy for any
-- role — the only write path is app.log_audit_event() (0013), a SECURITY
-- DEFINER function that runs as the function owner and therefore is not
-- subject to these RLS policies at all.
-- =============================================================================
create policy audit_logs_admin_select on public.audit_logs for select
  using (app.is_admin());
