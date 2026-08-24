# BayMath — Codex Project Instructions

## 1. Project Identity

BayMath is a Flutter + Supabase instructional mathematics application for Grades 4–6.

The application has three primary user areas:

* Student — tablet-first Android experience
* Teacher — desktop/laptop-oriented experience
* Administrator — desktop/laptop-oriented experience

Frontend:

* Flutter
* Dart
* Riverpod
* GoRouter
* Material 3

Backend:

* Supabase
* PostgreSQL
* Supabase RLS
* Supabase RPCs/functions/views
* Supabase Edge Functions

The project is already substantially developed. Do NOT treat it as a greenfield project.

---

# 2. Primary Development Mode

## FRONTEND-FIRST DEVELOPMENT

BayMath is currently in a frontend refinement and visual improvement phase.

The primary purpose of Codex in this project is to improve the Flutter frontend, visual design, usability, responsiveness, and overall user experience.

Unless the user explicitly requests backend changes, treat the following as READ-ONLY:

* Supabase database
* Supabase migrations
* RLS policies
* RPCs
* PostgreSQL functions/views
* Edge Functions
* authentication architecture
* repositories
* providers
* domain/data models
* business logic
* scoring logic
* database queries

When a requested improvement can be achieved entirely in Flutter presentation code, do NOT modify backend or business logic.

If a backend change appears necessary, explain why before making it.

---

# 3. Frontend Creative Freedom

For UI/UX tasks, Codex should act as both:

1. a senior Flutter frontend engineer
2. a senior UI/UX designer

Codex is encouraged to make meaningful visual improvements.

You may substantially improve:

* layout
* visual hierarchy
* spacing
* typography
* color usage
* cards
* buttons
* icons
* illustrations
* backgrounds
* visual grouping
* animations
* transitions
* responsive behavior
* touch interaction
* loading states
* empty states
* error states
* accessibility
* micro-interactions
* overall UX

Do not limit a redesign to changing a few colors or padding values if the existing design would benefit from a stronger structural improvement.

However, preserve all existing functionality and data flow.

The goal is to make BayMath feel like a polished modern educational application, not a generic default Flutter application.

---

# 4. BayMath Design Direction

BayMath targets Grades 4–6.

The visual design should feel:

* modern
* polished
* friendly
* educational
* engaging
* clean
* approachable
* age-appropriate
* professional enough for teachers and administrators

Avoid making the student interface look like:

* a kindergarten application
* an overly childish cartoon application
* a generic corporate dashboard
* a banking application
* an overly dense enterprise application
* a default Flutter template

Aim for a modern 2026 educational technology aesthetic appropriate for approximately Grades 4–6.

The design should balance:

* fun + professionalism
* personality + clarity
* visual interest + usability
* modern aesthetics + age appropriateness

---

# 5. Student UI

The student experience is TABLET-FIRST.

When modifying student screens:

* prioritize tablet layouts
* preserve responsive behavior
* maintain comfortable touch targets
* avoid tiny controls
* avoid desktop-only layouts
* avoid excessive information density
* maintain clear visual hierarchy
* make navigation obvious
* preserve readable typography
* maintain appropriate spacing for touch interaction

Student areas include:

* student login
* home/dashboard
* lessons
* lesson viewer
* quizzes
* quiz taking
* quiz results
* statistics
* endless quiz
* leaderboard
* avatar/profile

For student UI redesigns, Codex may substantially improve the visual presentation as long as functionality remains unchanged.

---

# 6. Teacher UI

Teacher interfaces are primarily desktop/laptop-oriented.

Focus on:

* clear information hierarchy
* efficient workflows
* readable tables
* useful filtering
* clean dashboards
* understandable statistics
* professional visual presentation
* responsive layouts
* consistent controls

Teacher functionality must remain unchanged during visual-only redesigns.

---

# 7. Administrator UI

Administrator interfaces are primarily desktop/laptop-oriented.

Focus on:

* information density without clutter
* clear statistics
* readable charts
* strong visual hierarchy
* professional dashboards
* intuitive filters
* clear reports
* consistent components
* polished empty/loading/error states

Do not change reporting calculations or business rules during visual-only redesigns.

---

# 8. Preserve Existing Functionality

For visual/UI tasks, preserve:

* navigation
* routes
* authentication
* providers
* repositories
* models
* Supabase calls
* RPC calls
* Edge Functions
* database queries
* business rules
* quiz scoring
* lesson progress
* quiz attempts
* statistics calculations
* exports
* permissions

Do not change functionality merely because a different implementation would be aesthetically cleaner.

---

# 9. Existing Architecture

The project currently uses a structure similar to:

```text
lib/
├── app/
├── core/
├── features/
│   ├── admin/
│   ├── auth/
│   ├── student/
│   └── teacher/
└── main.dart

supabase/
├── migrations/
└── functions/
```

Follow the existing architecture.

Do not reorganize the project simply because another architecture is theoretically cleaner.

Do not perform broad refactors during UI tasks.

---

# 10. Shared UI Components

Before creating a new generic widget, inspect existing shared components.

Look for reusable:

* buttons
* cards
* dialogs
* dropdowns
* text fields
* badges
* chips
* loading states
* error states
* empty states
* page containers
* section headers
* avatars
* navigation components

Reuse or improve existing components where appropriate.

Avoid creating several visually similar widgets that perform the same purpose.

If a shared component is genuinely inconsistent and the requested redesign affects multiple screens, consider improving the shared component instead of duplicating the design separately.

---

# 11. Theme and Design System

Before introducing new colors, typography, spacing, radii, or dimensions:

1. Inspect the existing theme.
2. Inspect existing design constants.
3. Inspect existing shared widgets.
4. Reuse established patterns when appropriate.

Prefer consistent design tokens over arbitrary one-off values.

If the existing design system is weak or inconsistent, Codex may propose improvements to the design system, but should keep the change focused on the requested UI improvement.

---

# 12. Responsive Design

BayMath must remain responsive.

Student:

* tablet-first
* touch-friendly
* landscape and portrait should be considered where applicable

Teacher/Admin:

* desktop/laptop-first
* should remain usable at reasonable window sizes

Do not solve a layout problem by hardcoding a single device width.

Avoid unnecessary fixed dimensions when responsive constraints can be used.

Consider:

* LayoutBuilder
* MediaQuery
* Flexible
* Expanded
* ConstrainedBox
* Wrap
* Grid layouts
* responsive spacing
* adaptive navigation

Use the approach consistent with the existing project.

---

# 13. Visual-Only Task Rule

When the user says a task is:

* redesign
* improve UI
* improve visual
* make it modern
* make it cleaner
* make it polished
* improve UX
* change appearance
* redesign screen
* redesign dashboard
* improve layout

Treat it as a FRONTEND task by default.

Do not modify:

* repositories
* providers
* models
* Supabase
* migrations
* RPCs
* Edge Functions
* authentication
* business logic

unless technically unavoidable.

If technically unavoidable, explain the reason.

---

# 14. Backend Protection

Do not modify database/backend files during a frontend-only task.

This includes:

```text
supabase/migrations/
supabase/functions/
```

Do not:

* create migrations
* edit migrations
* modify RLS
* modify RPCs
* modify Edge Functions
* change database schemas
* change authentication
* change authorization

unless the user explicitly requests backend work.

If a UI problem is caused by a backend issue, identify it and report it instead of silently changing the backend.

---

# 15. Supabase Security

Never:

* expose secrets
* print `.env` values
* copy secrets into source files
* commit `.env`
* put credentials in `AGENTS.md`
* put service-role keys in Flutter code
* put JWT secrets in Flutter code
* put encryption keys in Flutter code

Never weaken RLS to make a UI feature work.

Never move privileged backend operations into the Flutter client merely for convenience.

---

# 16. Authentication Protection

BayMath has separate authentication/session concepts for:

* administrators
* teachers
* students

The student authentication flow includes custom backend handling.

Do not replace authentication with a simpler implementation during frontend work.

Do not change:

* login logic
* session logic
* JWT handling
* role guards
* authorization

unless explicitly requested.

A login screen redesign should modify the presentation only.

---

# 17. Quiz Protection

Quiz functionality is business-critical.

During UI redesigns, preserve:

* question ordering
* answer selection behavior
* answer persistence
* scoring
* attempt state
* retake behavior
* completion state
* timer behavior
* quiz submission
* result calculation

A quiz screen redesign should not alter the underlying quiz logic.

---

# 18. Statistics Protection

Statistics and reports have defined business rules.

During visual redesigns, preserve:

* calculations
* filtering logic
* data sources
* RPCs
* repository methods
* provider behavior
* score definitions
* intervention definitions
* school-year behavior
* attempt definitions

Improve how the information is presented without changing what the information means.

---

# 19. PDF / CSV / XLSX Exports

Existing exports are functional features.

During UI redesigns:

* preserve export functionality
* preserve generated data
* preserve report calculations
* preserve existing export behavior

Do not remove export functionality simply because the UI is being redesigned.

---

# 20. Flutter Code Style

Follow the existing `analysis_options.yaml`.

Maintain the existing project conventions including:

* explicit return types
* strict typing
* single quotes
* trailing commas
* const where appropriate
* final locals where appropriate
* clean imports
* avoid unnecessary widgets
* avoid unnecessary nesting
* avoid `print`

Do not disable lint rules merely to make a UI change compile.

Do not add broad analyzer ignores.

---

# 21. Dependencies

Do not add a package simply to create a visual effect that can reasonably be implemented with Flutter.

Before adding a dependency:

1. Check existing `pubspec.yaml`.
2. Check whether the project already has suitable functionality.
3. Check whether Flutter itself can provide the required behavior.
4. Explain why a new dependency is needed.
5. Avoid upgrading unrelated packages.

Do not modify dependencies during a visual task unless necessary.

---

# 22. Animation

Animations are welcome when they improve UX.

Prefer animations that are:

* subtle
* purposeful
* responsive
* performant
* appropriate for Grades 4–6

Avoid excessive animation that makes the application distracting or difficult to use.

Do not introduce animation everywhere simply because the feature exists.

---

# 23. Accessibility and Usability

UI improvements should consider:

* readable text
* sufficient contrast
* touch target size
* clear interaction states
* meaningful labels
* keyboard usability where relevant
* screen-size adaptability
* clear error messages

Do not sacrifice usability merely for visual aesthetics.

---

# 24. Before Editing

For every non-trivial UI task:

1. Inspect the current screen.
2. Inspect related widgets.
3. Inspect the theme/design system.
4. Identify reusable components.
5. Identify what must remain unchanged.
6. Check whether the screen is student, teacher, or admin.
7. Check the target device orientation/size.
8. Check Git status.
9. Then implement.

Do not immediately rewrite the screen without understanding the existing implementation.

---

# 25. UI Design Review Before Implementation

For substantial redesigns, first explain:

### Current UI

What is currently working and what looks weak.

### Proposed direction

Describe the new visual direction.

### Components affected

List the screens/widgets that will change.

### Functionality preserved

Explicitly state what will remain unchanged.

Then implement.

For small visual fixes, this planning step can be brief.

---

# 26. Change Discipline

Do not make unrelated changes.

Do not:

* refactor unrelated code
* rename unrelated files
* upgrade unrelated dependencies
* change backend code
* change database code
* reformat entire files unnecessarily
* rewrite working business logic

Keep the diff focused on the requested UI/UX improvement.

---

# 27. Git Safety

Before substantial changes:

```bash
git status
```

Preserve all existing user changes.

Never run destructive commands such as:

```bash
git reset --hard
git checkout -- .
git clean -fd
```

unless the user explicitly requests that exact operation.

Do not overwrite unrelated work.

---

# 28. Validation

After Flutter changes, run:

```bash
flutter analyze
```

When relevant:

```bash
flutter test
```

If possible, also visually inspect the affected screen on the intended device/window size.

Do not claim a command passed unless it was actually executed.

If a command cannot be run, state that clearly.

---

# 29. Final Diff Review

Before finishing a task, inspect the final diff for:

* accidental backend changes
* accidental business logic changes
* duplicated widgets
* broken imports
* unnecessary dependencies
* responsive layout problems
* inconsistent styling
* unrelated formatting changes

For a frontend-only task, verify that backend files were not changed.

---

# 30. Task Protocol

For a substantial UI task:

### Phase A — Inspect

Understand the current implementation.

### Phase B — Design

Identify the visual problems and proposed solution.

### Phase C — Implement

Make the frontend changes.

### Phase D — Validate

Run Flutter analysis/tests as appropriate.

### Phase E — Review

Inspect the final diff and verify that functionality was preserved.

### Phase F — Report

Report:

* files changed
* visual improvements
* functionality preserved
* validation performed
* any remaining issues

---

# 31. BayMath Principle

The goal is NOT to turn BayMath into a generic AI-generated Flutter application.

The goal is to make the existing BayMath application feel like a polished, modern 2026 educational product while preserving its existing functionality and architecture.

Codex should be creative with the FRONTEND.

Codex should be conservative with the BACKEND.

When uncertain:

> Be creative with presentation.
>
> Be conservative with functionality.
>
> Inspect before changing.
>
> Preserve the existing architecture.
