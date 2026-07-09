# Instructional Math App

## 1. Project Overview

An instructional mathematics application for **Grades 4–6**, built as a
single Flutter codebase serving two distinct audiences:

- **Students** — Android tablets.
- **Teachers & Administrators** — Desktop/Web.

The backend is **Supabase**, on the Free Tier. All tooling and packages
used across the project are free/open-source — no paid services.

> **Current status:** foundation only. No business features (auth,
> dashboards, lessons, quizzes, statistics, etc.) exist yet. See
> [Current Development Phase](#7-current-development-phase).

## 2. Architecture Overview

**Feature-First architecture** with a clear split between three
responsibilities:

- **`lib/app/`** — everything that *configures* the application as a
  whole: environment/Supabase bootstrap, routing, theming, and
  app-wide constants. If a file's job is "set up how the app behaves
  globally," it lives here.
- **`lib/core/`** — shared, feature-agnostic *infrastructure* that
  features can depend on (error types, extensions, generic services,
  utils, generic widgets, database helpers). Nothing here contains
  business logic or knows about a specific feature.
- **`lib/features/<feature>/`** — isolated, self-contained features.
  Each feature owns its own internal layering (starting with
  `presentation/`, expanding to `domain/`/`data/` as needed in later
  phases). Features do not reach into each other directly.

**State management:** Riverpod (`ProviderScope` at the root).
**Routing:** GoRouter, configured as a Riverpod provider.

## 3. Folder Structure

```
lib/
├── main.dart                     # Entry point: load env → init Supabase → run App
├── app/                          # Everything that configures the app
│   ├── config/                   # Env loading + Supabase bootstrap
│   │   ├── env_config.dart
│   │   └── supabase_config.dart
│   ├── constants/                # App-wide constants (e.g. layout breakpoints)
│   │   └── app_layout_breakpoints.dart
│   ├── router/                   # GoRouter setup + route path constants
│   │   ├── app_router.dart
│   │   └── app_routes.dart
│   ├── theme/                    # Material 3 theme, colors, typography
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_typography.dart
│   └── app.dart                  # Root MaterialApp.router shell
├── core/                         # Shared infrastructure, no business logic
│   ├── database/                 # (reserved) shared DB access helpers
│   ├── errors/                   # (reserved) shared error/failure types
│   ├── extensions/                # (reserved) shared Dart/Flutter extensions
│   ├── models/                    # (reserved) shared cross-feature model contracts
│   ├── services/                  # (reserved) shared feature-agnostic services
│   ├── utils/                     # (reserved) shared stateless helpers
│   └── widgets/                   # (reserved) shared generic presentational widgets
└── features/                     # Isolated, feature-first modules
    ├── splash/presentation/
    ├── auth_placeholder/presentation/
    └── error/presentation/

assets/
├── animations/
├── audio/
├── fonts/
├── icons/
├── images/
└── pdfs/
```

Every `core/` subfolder currently contains only a `README.md` explaining
its intended future purpose — they exist to give later phases a
consistent place to land shared code, and to prevent business logic
from leaking into `core/` by having a clear home for each concern.
`assets/` subfolders currently hold only a `.gitkeep` placeholder each.

## 4. Technology Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (single codebase: Android tablet + Desktop/Web) |
| State management | Riverpod (`flutter_riverpod`) |
| Routing | GoRouter (`go_router`) |
| Backend | Supabase (Free Tier) via `supabase_flutter` |
| Environment/secrets | `flutter_dotenv` (`.env`, git-ignored) |
| Design system | Material 3, single Light Theme (V1) |
| Linting | `flutter_lints`, via `analysis_options.yaml` |

All free/open-source. No paid packages or services are used anywhere
in the project.

## 5. Development Rules

- **Feature isolation.** Features never import from another feature.
  Shared code goes through `core/`; app-wide config goes through `app/`.
- **`app/` vs `core/`.** If it configures the app globally (env,
  Supabase init, routing, theme, app-wide constants) → `app/`. If it's
  reusable infrastructure with no app-configuration role → `core/`.
- **No business logic in `core/`.** `core/` folders hold infrastructure
  only — types, helpers, generic widgets. Feature-specific logic and
  business models live inside the owning feature.
- **No hardcoded secrets.** Supabase URL/key always come from `.env`
  via `EnvConfig`, never hardcoded in source.
- **Single Light Theme for V1.** Dark theme is intentionally not
  configured; keep theme code modular so it can be reintroduced later
  without restructuring.
- **Lint-clean.** Code should pass `flutter analyze` under the
  project's `analysis_options.yaml` before being considered done.

## 6. Setup Instructions

This repository was authored without direct access to the Flutter SDK,
so the native platform folders (`android/`, `web/`, etc.) are not
included yet. One-time setup:

```bash
# 1. Generate the native platform folders (does not touch existing
#    lib/ or pubspec.yaml):
flutter create . --project-name instructional_math_app \
  --platforms=android,web,windows,macos,linux

# 2. Configure environment variables:
cp .env.example .env
# then edit .env with your Supabase project's URL + anon key
# (Supabase dashboard → Settings → API)

# 3. Install dependencies and run:
flutter pub get
flutter run
```

## 7. Current Development Phase

**Phase 0 — Foundation (refined).**

Implemented:
- Feature-first folder structure (`app/`, `core/`, `features/`)
- Riverpod + GoRouter shell with placeholder-only routes (Splash,
  Login Placeholder, Unauthorized Placeholder, Not Found)
- Supabase initialization (no queries, no auth, no schema)
- Material 3 single Light Theme
- Lint configuration
- Reserved, empty `core/` infrastructure folders and `assets/` folders

Explicitly **not yet implemented** (deferred to later phases):
authentication, dashboards, CRUD, lessons, quizzes, statistics,
question bank, printing/PDF generation, file uploads, database schema,
Row Level Security, triggers.
