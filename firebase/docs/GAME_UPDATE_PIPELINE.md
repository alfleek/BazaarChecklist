# Game Update Pipeline Runbook

This runbook defines the review-first update process for new Bazaar game builds.

## Goal

Run one command to fetch/parse/rescan the newest build and produce a review report.
Only after review approval should production seeding run.

## Commands

Run from `firebase/`.

### Review (default safe path)

```bash
npm run pipeline:game-update -- --mode review
```

What this does:

1. Fetches and caches the newest build.
2. Extracts `cards.json` and inspects schema.
3. Generates review reports:
   - `.cache/game-builds/<buildId>/catalog_review_report.json`
   - `.cache/game-builds/<buildId>/catalog_review_report.md`

No Firestore writes occur in this mode.

If you also want image export in the same run:

```bash
npm run pipeline:game-update -- --mode review --includeImages true
```

### Apply (writes enabled after manual review)

```bash
npm run pipeline:game-update -- --mode apply --projectId <projectId> --serviceAccount ./service-account.local.json --confirmApply "I_UNDERSTAND"
```

`apply` mode requires the explicit confirmation token and:

- seeds catalog data from the reviewed build
- uploads/sets image URLs from generated manifests (when present)
- re-applies deterministic forced asset overrides (for example historical feather/blue fixes) and merges those manifests before seeding
- applies controlled image fallback clears from overrides
- applies inactive-name policy from `scripts/deactivate_items_by_name.js`

## Review checklist

- Confirm new item IDs are valid game additions.
- Check changed names/tags/hiddenTags/hero/rarity/size for parser correctness.
- Review active/inactive transitions (especially bracketed debug-like names).
- Validate image fallback/override behavior for unresolved or semantically wrong art.
- Approve before running `--mode apply`.

## Workarounds and fixes (source of truth)

### Name and asset matching workarounds

- `scripts/extract_item_images_from_game.py`
  - `NAME_MISMATCH_OVERRIDES`
  - compact-name matching across spaces/hyphens/case to align card names with texture names
  - texture selection heuristics (`choose_texture_name`, `choose_mask_name`)
  - bundle scoring (`score_texture_bundle_matches`)

### Deterministic art overrides and no-image policy

- `data/item_art_overrides.json`
  - `forcedAssetByItemId`: exact item -> asset binding
  - `disableImageForItemIds`: clear image URLs instead of shipping wrong art
- `scripts/export_item_images_by_asset_name.py`
  - re-exports all `forcedAssetByItemId` entries every migration run
- `scripts/merge_image_manifests.js`
  - overlays deterministic artfix manifests on top of base extraction manifests
  - prevents regressions where historical fixes would otherwise be overwritten

### Inactive/debug item behavior

- `scripts/seed_catalog_from_game.js`
  - bracketed-name heuristic via `shouldDeactivateByBracketedName`
  - optional `--deactivateMissing` for missing old docs
- `scripts/deactivate_items_by_name.js`
  - authoritative inactive-name denylist applied during pipeline `--mode apply`

### Tag handling

- `scripts/seed_catalog_from_game.js` writes both:
  - `typeTags`
  - `hiddenTags`

## Cleanup policy

Always dry-run first:

```bash
npm run cleanup:game-cache
```

For full-repro cleanup analysis inside kept builds:

```bash
npm run cleanup:game-cache:deep
```

Apply cleanup only after reviewing candidates:

```bash
npm run cleanup:game-cache -- --apply
```

By default cleanup keeps:

- canonical snapshot build
- latest build
- last successfully seeded build (from `.cache/game-builds/_metadata/last_seeded_build.json`)
- any explicitly listed keep IDs

### Required artifacts for full reseed reproducibility

For each pinned build, keep all of:

- `cards.json`
- manifest files used for the last successful apply (`thumb` + `full`)
- every PNG referenced by those manifest `imagePath` entries
- deterministic artfix outputs that are referenced by merged manifests

Without both manifest JSON and referenced local PNG assets, image reseeding cannot be replayed directly.

### Deep cleanup behavior

- `--deep` prunes stale `exported_item_*` trial directories **inside kept builds**.
- `--deep` also prunes non-essential report artifacts while preserving:
  - latest build `catalog_review_report.json/.md` and `schema_report.json`
  - canonical forensic reports (`octopus_trace_report.json`, `pathid_scan*.json`)
- It protects manifest roots and referenced image directories for the last-seeded build.
- It skips canonical forensic build internals by default.

## Optional flags

- `--includeImages false`: skip image export during review
- `--includeImages true`: include image export/manifests in pipeline run
- `--includeFull false`: skip full-size manifest export
- `--baselineBuildId <buildId>`: compare report against a specific prior cached build
- `--deactivateMissing`: apply-mode option to deactivate docs missing from current extraction
