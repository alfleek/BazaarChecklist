# AI coding conventions

Guidance for humans and Cursor when implementing BazaarChecklist.

## Project facts

- Flutter package: [mobile/](mobile/) (`pubspec.yaml` defines the package name).
- Backend: Firebase (Auth, Firestore); see [DATA_MODEL.md](DATA_MODEL.md) and [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
- MVP auth methods: email/password, Google, Apple.
- Web hosting is stretch; mobile-first delivery is required.

## State management

**Status: TBD** — choose one primary approach and record it here:

- Options to decide: Riverpod, Bloc, Provider/ChangeNotifier, GetX, or other.
- After decision: list folder patterns (e.g. `features/foo/foo_cubit.dart`) and testing expectations.

Until decided, agents should **not** introduce a heavy framework without updating this section and [PRODUCT.md](PRODUCT.md) if scope changes.

## Adding a feature (checklist)

1. Confirm behavior in [PRODUCT.md](PRODUCT.md).
2. Update [DATA_MODEL.md](DATA_MODEL.md) if Firestore or local shapes change.
3. Implement in `lib/` following existing structure once established.
4. Update Security Rules if Firestore access patterns change.
5. Keep **mobile/web** behavior aligned unless documented otherwise.

## Code style

- Follow `analysis_options.yaml` in [mobile/](mobile/).
- Prefer small, testable units for “won / not won” logic over embedding in widgets.
- Avoid drive-by refactors unrelated to the task.
- Keep MVP primary navigation focused on functional destinations only; do not add placeholder tabs to bottom navigation.
- For run creation, prefer contextual entry points (for example FAB from `Runs`) over a dedicated `Build Input` tab.

## Navigation intent ownership

Use a single owner for cross-flow tab/route intent to prevent competing navigation updates.

- Post-auth tab selection must flow through `SessionController.preferredTabIndex`.
- Auth flows (`LoginPage` and first-run auth entry points) should set the preferred destination before exiting.
- `AuthGate` should pass the preferred destination into `AppShellPage` as initialization intent.
- `AppShellPage` should apply that intent once, then clear it, and should avoid resetting tab state from unrelated code paths.
- Do not duplicate "return destination" logic in multiple layers (widget-local state + auth callbacks + gate rebuilds).

## MVP testing baseline

Required tests for MVP:

- Unit tests for run result tier classification (`defeat` through `diamondVictory`).
- Unit tests for per-item won/never-won derivation.
- Unit tests for guest-to-cloud exact dedupe merge logic.

Not required for MVP baseline (add if time allows):

- Widget tests and repository/integration-style tests.

## Secrets and generated files

- Do not commit Firebase private keys or plist/json secrets.
- Do not hand-edit generated FlutterFire files except as tooling expects.

## What not to do without explicit ask

- New backend languages or servers (e.g. Ruby) unless PRODUCT explicitly expands scope.
- Scraping or unofficial game client integration.
- Broad UI redesigns when the task is data/backend only.
