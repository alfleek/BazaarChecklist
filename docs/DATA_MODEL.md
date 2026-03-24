# Data model (Firestore + local)

**Status**: Baseline confirmed for MVP. Collection names are locked as documented in this file.

## Principles

- **Catalog** is readable by clients according to Security Rules (often read for all app users or public read for catalog only).
- **User wins** are readable/writable only by the owning Firebase Auth `uid`.
- Use **stable string IDs** for catalog items (`itemId`) so wins reference the same item across sessions.

## Firestore collections

### `catalog_items/{itemId}`

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | Display name |
| `typeTags` | array of string | Item type tags |
| `heroTag` | string | Hero association tag |
| `startingRarity` | string | Initial rarity |
| `size` | number | Item size value |
| `active` | bool | Soft-disable without deleting references |
| `updatedAt` | timestamp | Optional |

Stretch field:

- `imageUrl` (string).

### `heroes/{heroId}`

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | Display name |
| `active` | bool | Optional soft-disable |
| `updatedAt` | timestamp | Optional |

### `users/{uid}/wins/{winId}`

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
| `screenshotUrl` | string | Optional cloud URL for signed-in mode (single screenshot per win) |

Stretch field:

- `itemStates` map/object with per-item metadata such as `enchanted`.

**Open decision**: Denormalize item names for offline display vs always join from catalog.

Result tier rules:

- `0..3` wins -> `defeat`
- `4..6` wins -> `bronzeVictory`
- `7..9` wins -> `silverVictory`
- `10` wins -> `goldVictory`
- `10` wins and `perfect = true` -> `diamondVictory`

## Derived/aggregate views (search MVP, achievements stretch)

These can be computed on-device from wins + catalog for MVP-scale datasets:

- Per-item won count and never-won status.
- Per-hero progress counts.
- Per-type-tag progress counts.
- Filtered/sorted item lists for search UI.

## Local storage (guest)

Not a Firestore schema; stored on device only.

| Concept | Purpose |
|---------|---------|
| Guest win records | Same logical shape as cloud wins where possible (`itemIds`, `createdAt`, `mode`, `heroId`, `notes`, …) |
| Catalog cache | Optional snapshot of `catalog_items` for offline browse |

Exact package (e.g. `shared_preferences`, `hive`, `drift`) — see [AI_CODING.md](AI_CODING.md) once chosen.

## Indexes

Add composite indexes only when queries require them (e.g. filter + order). Document new indexes here when added.

## Security Rules (intent)

- **Allow read** of `catalog_items` and the hero list as needed for the app (authenticated or public read to be chosen when locking rules).
- **Deny** all reads/writes to other users’ `users/{uid}/wins/*`.
- **Allow** read/write only for `users/{request.auth.uid}/wins/*` when `request.auth != null`.

## Sync behavior (confirmed)

- On first sign-in (or first cloud sync), local guest wins should be merged into the authenticated user's cloud wins.
- Merge dedupe policy (MVP): deduplicate only exact matches by logical run identity (`itemIds` set + `heroId` + `mode` + `wins` + `perfect` + `createdAt`).
- Near-duplicate or fuzzy matches should not be auto-merged in MVP. Present them in a post-scan review queue so the user can resolve in bulk.

## Offline guarantees (MVP)

- Guest mode: cached catalog and full local history remain available offline.
- Signed-in mode: cached catalog and local history view of already-synced wins remain available offline.
- Offline writes in signed-in mode can be queued locally and synced when network returns (implementation detail may vary by chosen local store).

Paste finalized rules into Firebase Console; keep a comment or snippet here only if the team wants versioned documentation (optional).
