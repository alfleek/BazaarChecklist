# AI coding conventions

Guidance for humans and Cursor when implementing BazaarChecklist.

## Project facts

- Flutter package: [mobile/](mobile/) (`pubspec.yaml` defines the package name).
- Backend: Firebase (Auth, Firestore); see [DATA_MODEL.md](DATA_MODEL.md) and [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
- MVP auth methods: email/password, Google, Apple.
- Mobile and web are dual priorities: web ships hosted (Firebase Hosting) and secured
  (Firestore Security Rules) now; mobile continues toward eventual app-store
  publishing. See [PRODUCT.md](PRODUCT.md#web-hosting--deployment-confirmed).

## Routing

**Status: chosen** — `go_router`, independent of the state-management decision below
(no Provider/Riverpod/Bloc introduced; `go_router` doesn't require one). Routes:
`/runs`, `/catalog`, `/catalog/:itemId`, `/challenges`, `/login`, `/account`. Auth
gating stays a widget wrapper (`AuthGate`), not a `go_router` redirect. See the
"Routing" subsection of [ARCHITECTURE.md](ARCHITECTURE.md) for the full route table and
rationale.

**Non-goal for now**: SEO/SSR. Discoverability "would be nice" but is not a
requirement — Flutter web's canvas-based rendering is fundamentally limited for
crawlability regardless of renderer choice. Revisit only if discoverability becomes a
real priority later (would need a genuinely server-rendered surface, out of scope
today).

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
- Bottom tabs are `Runs`, `Catalog`, and `Challenges` (functional). `Account` is a top-bar action, not a tab. Do not add empty placeholder tabs.
- For run creation, prefer contextual entry points (for example FAB from `Runs`) over a dedicated `Build Input` tab.

## Navigation intent ownership

Use a single owner for cross-flow tab/route intent to prevent competing navigation updates.

- This applies equally to `AppShellPage` (mobile chrome) and `WebShellPage` (web
  chrome, picked by `ResponsiveShell` at a width breakpoint — see
  [ARCHITECTURE.md](ARCHITECTURE.md)). Both consume `SessionController` via the shared
  `ShellTabIntentMixin`; neither shell may reimplement or duplicate the
  tab-reset/account-open logic locally.
- Post-auth **tab** selection must flow through `SessionController.preferredTabIndex` when switching tabs (e.g. jump to Catalog). The **visible** bottom tab is also mirrored in `SessionController.persistShellTabIndex` / `shellTabIndex` (no notify) so `AppShellPage` can restore the correct tab after `AuthGate` rebuilds (e.g. session `notifyListeners` from challenge tier or catalog prefill).
- Post-auth **Account** screen uses `SessionController.requestOpenAccount()` + `takePendingOpenAccount()` in `AppShellPage` (pushed route, not a tab index).
- Challenges **win threshold** (`ChallengeChecklistTier`) is stored on `SessionController` (`challengeChecklistTier` / `setChallengeChecklistTier`) so the hub and pushed category detail screens stay aligned when navigating back.
- Catalog prefill from Challenges uses `SessionController.navigateToCatalogWithPrefill(CatalogPrefillArgs)`; `SearchPage` consumes `pendingCatalogPrefill` on the **next frame** (post-frame) and clears it so apply runs after `AuthGate`/`AnimatedBuilder` rebuild. Optional `preserveAttributeFilters` / `mergeAttributeFilters` exist on `CatalogPrefillArgs`; challenge CTAs use default **replace** (clear attribute filters + apply subgroup or empty for full catalog). `collapseCatalogControls: true` collapses the catalog search/filter panels after apply; users can expand again with **Show search & filters** on the Catalog tab.
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
