# CLAUDE.md — BazaarChecklist

Guidance for Claude Code working in this repository. This complements
[AGENTS.md](AGENTS.md); when they overlap, the docs referenced below are the
source of truth.

## What this project is

An **unofficial** companion app for the game **The Bazaar**: players record
winning runs, track which catalog items they've won with, and complete
checklist-style "Challenges." Mobile-first, web as a stretch goal.

- **Client**: one Flutter app in [mobile/](mobile/), targeting iOS, Android, and web.
- **Backend (v1)**: Firebase only — Auth + Cloud Firestore (+ optional Hosting). No custom server.
- **Data pipeline**: a separate Node/Python toolchain in [firebase/](firebase/) seeds and
  maintains the item catalog and extracts item art. Treat it as a distinct context from the app.

## Read before non-trivial work

1. [docs/PRODUCT.md](docs/PRODUCT.md) — scope, MVP boundaries, non-goals. Do not build
   features marked TBD/pending without updating this first.
2. [docs/DATA_MODEL.md](docs/DATA_MODEL.md) — Firestore collections and local-storage shapes
   (collection names are locked).
3. [docs/AI_CODING.md](docs/AI_CODING.md) — conventions, the "adding a feature" checklist,
   and navigation-intent ownership rules.
4. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/ROADMAP.md](docs/ROADMAP.md) — system
   shape and phase order.

## Hard constraints

- **Scope discipline**: implement only what `docs/PRODUCT.md` says is in scope; update that doc
  before adding features.
- **Secrets**: never commit API keys, `google-services.json`, `GoogleService-Info.plist`, or
  Firebase private keys. Service-account and `*.local.json` files are gitignored — keep it that way.
- **Platform parity**: mobile and web share one Flutter codebase; avoid `kIsWeb` branches unless
  documented in PRODUCT.md.
- **No new backend** (e.g. Ruby/custom servers) unless PRODUCT.md explicitly expands scope.
- **Navigation intent**: keep a single owner for cross-flow tab/route intent
  (`SessionController.preferredTabIndex` and friends). Do not duplicate tab-reset logic across
  `LoginPage`, `AuthGate`, and `AppShellPage` — see the navigation section of AI_CODING.md.
- **No drive-by refactors** unrelated to the task at hand.

## Open decision (not yet resolved)

- **State management** is still TBD (no Riverpod/Bloc/Provider chosen). Do not introduce a heavy
  state framework without first recording the choice in `docs/AI_CODING.md` and PRODUCT.md.

## Code layout

- App code: `mobile/lib/features/<feature>/` (auth, catalog, challenges, runs, builds, shell, search, account).
- Shared widgets: `mobile/lib/features/shared/ui/`.
- Tests: `mobile/test/` — the MVP-critical logic (run-tier classification, won/never-won
  derivation, guest→cloud merge dedupe) is covered here.

## Commands (run from `mobile/`)

```bash
flutter pub get        # install dependencies
flutter analyze        # static analysis / lints (analysis_options.yaml)
flutter test           # run unit + widget tests
flutter run            # launch on a connected device/emulator
```

Definition of done for a change: `flutter analyze` and `flutter test` both pass.

## Workflow expectations

- Plan non-trivial changes before editing; confirm scope against PRODUCT.md.
- Follow the "Adding a feature" checklist in AI_CODING.md (confirm in PRODUCT → update DATA_MODEL
  if shapes change → implement → keep mobile/web aligned → update Security Rules if access patterns change).
- Prefer small, testable units for "won / not won" logic over embedding it in widgets.

## Repo hygiene

- Line endings are normalized to **LF** via `.gitattributes`. Keep it that way; do not re-introduce
  CRLF or per-file line-ending changes.
