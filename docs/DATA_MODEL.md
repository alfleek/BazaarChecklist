# Data model (Firestore + local)

**Status**: Baseline confirmed for MVP. Collection names are locked as documented in this file.

## Principles

- **Catalog** is readable by clients according to Security Rules (often read for all app users or public read for catalog only).
- **User runs** are readable/writable only by the owning Firebase Auth `uid`.
- Use **stable string IDs** for catalog items (`itemId`) so runs reference the same item across sessions.

## Firestore collections

### `catalog_items/{itemId}`

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | Display name |
| `typeTags` | array of string | Item type tags |
| `hiddenTags` | array of string | Hidden tags tracked for Challenges; not shown in catalog filter UI |
| `heroTag` | string | Hero association tag |
| `startingRarity` | string | Initial rarity |
| `size` | string or number | Item size (game-parity strings like `"Large"` are OK; legacy numeric seeds may exist) |
| `active` | bool | Soft-disable without deleting references |
| `updatedAt` | timestamp | Optional |

Stretch field:

- `imageThumbUrl` (string, URL).
- `imageFullUrl` (string, URL).

### `heroes/{heroId}`

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | Display name |
| `active` | bool | Optional soft-disable |
| `updatedAt` | timestamp | Optional |

### `users/{uid}/runs/{runId}`

| Field | Type | Notes |
|-------|------|--------|
| `itemIds` | array of string | References `catalog_items` ids |
| `createdAt` | timestamp | |
| `mode` | string enum | `ranked` or `normal` |
| `heroId` | string | References hero list id |
| `wins` | number | Integer 0..10 |
| `perfect` | bool | Perfect run toggle set by user |
| `resultTier` | string enum | `defeat`, `bronzeVictory`, `silverVictory`, `goldVictory`, `diamondVictory` |
| `notes` | string | Optional user-entered note, max 500 chars |
| `screenshotPath` | string | Optional local file path for guest mode |
| `screenshotUrl` | string | Optional cloud URL for signed-in mode (single screenshot per run) |

Stretch field:

- `itemStates` map/object with per-item metadata such as `enchanted`.

**Open decision**: Denormalize item names for offline display vs always join from catalog.

Result tier rules:

- `0..3` wins -> `defeat`
- `4..6` wins -> `bronzeVictory`
- `7..9` wins -> `silverVictory`
- `10` wins -> `goldVictory`
- `10` wins and `perfect = true` -> `diamondVictory`

## Derived/aggregate views (search + challenges)

These are computed on-device from runs + catalog for MVP-scale datasets:

- Per-item won count, best tier, and never-won status.
- Filtered/sorted item lists for search UI.
- **Challenges** tab: full-catalog and grouped checklist completion (hero tag, type tags, size, starting rarity) against a chosen minimum win tier (Bronze / Silver / Gold / Perfect). Uses the same `resultTier` ordering as run records (at-least thresholds: Bronze ≥ `bronzeVictory`, Silver ≥ `silverVictory`, Gold ≥ `goldVictory`, Perfect = `diamondVictory`).
- Navigating from Challenges to Catalog applies attribute filters via in-app session state (`CatalogPrefill`); run-history filter is **not** enabled for that entry path.

## Local storage (guest)

Not a Firestore schema; stored on device only.

| Concept | Purpose |
|---------|---------|
| Guest run records | Same logical shape as cloud runs where possible (`itemIds`, `createdAt`, `mode`, `heroId`, `notes`, …) |
| Catalog cache | Optional snapshot of `catalog_items` for offline browse |

**Guest runs implementation note**: the Flutter MVP stores a JSON array under SharedPreferences key `guest_runs_v1` (see `GuestRunsRepository` in `mobile/lib/features/runs/runs_repository.dart`).

Exact package (e.g. `shared_preferences`, `hive`, `drift`) — see [AI_CODING.md](AI_CODING.md) once chosen.

## Indexes

Add composite indexes only when queries require them (e.g. filter + order). Document new indexes here when added.

## Security Rules (intent)

- **Allow read** of `catalog_items` and the hero list as needed for the app (authenticated or public read to be chosen when locking rules).
- **Deny** all reads/writes to other users’ `users/{uid}/runs/*`.
- **Allow** read/write only for `users/{request.auth.uid}/runs/*` when `request.auth != null`.

## Sync behavior (confirmed)

- On first sign-in (or first cloud sync), local guest runs should be merged into the authenticated user's cloud runs.
- Merge dedupe policy (MVP): deduplicate only exact matches by logical run identity (`itemIds` set + `heroId` + `mode` + `wins` + `perfect` + `createdAt`).
- Near-duplicate or fuzzy matches should not be auto-merged in MVP. Present them in a post-scan review queue so the user can resolve in bulk.

## Offline guarantees (MVP)

- Guest mode: cached catalog and full local history remain available offline.
- Signed-in mode: cached catalog and local history view of already-synced runs remain available offline.
- Offline writes in signed-in mode can be queued locally and synced when network returns (implementation detail may vary by chosen local store).

Paste finalized rules into Firebase Console; keep a comment or snippet here only if the team wants versioned documentation (optional).
