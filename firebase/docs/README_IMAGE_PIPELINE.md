# Image Pipeline (Supported)

This document defines the supported image workflow for `catalog_items` image fields.

## Canonical Build Snapshot

We currently retain one full reference build cache for reproducibility and unresolved
asset debugging:

- `firebase/.cache/game-builds/7fa9c6d76587deba235468246222ced7f2a6beb77d2f4a434fa23f1559c04eba`

This retained snapshot intentionally includes `downloaded_bundles/` for forensic work
(for example unresolved external references like Octopus).

## Firestore Fields Used By App

For catalog images, we populate:

- `catalog_items.imageThumbUrl`
- `catalog_items.imageFullUrl`

The app consumes thumbnail/full URLs via `CachedNetworkImage` and now uses
URL-derived cache keys to avoid stale thumbnail/full mismatches after reseeding.

## Supported Scripts

These are the scripts we keep and support in `firebase/scripts/`:

- `extract_item_images_from_game.py`
  - Main extractor from cards/addressables to PNG outputs.
- `export_item_images_by_asset_name.py`
  - Deterministic override export by item ID -> exact asset name.
  - Reads overrides from `item_art_overrides.json`.
- `seed_catalog_from_game.js`
  - Uploads local PNGs from manifests to Firebase Storage and writes signed URLs to
    Firestore fields (`imageThumbUrl`, `imageFullUrl`).
- `merge_image_manifests.js`
  - Merges base extraction manifests with deterministic artfix manifests so forced
    corrections survive future migrations.
- `find_external_pathid_bundle.py`
  - Brute-force pathId resolver across catalog-derived bundles.
- `trace_octopus_maintex.py`
  - Deterministic CardData -> Material -> _MainTex trace report for Octopus.
- `apply_item_art_fallbacks.js`
  - Applies controlled fallback policy (clear image URLs for specific item IDs).
- `validate_item_image_parity.js`
  - Verifies thumb/full parity in Firestore for a target set of item IDs.
- `firebase/data/item_art_overrides.json`
  - Source of truth for deterministic forced item asset picks and no-image fallbacks.

## Deterministic Selection Policy

When selecting item art, use this order:

1. `firebase/data/item_art_overrides.json` forced entry (exact asset name) if present.
2. Standard extractor selection (card-style art textures preferred).
3. If unresolved or semantically wrong candidate (for example monster/combat art),
   use controlled fallback (`disableImageForItemIds`) rather than shipping wrong art.

### No-Wrong-Art Rule

If only clearly incorrect semantic assets are available (monster/combat/enchantment FX
instead of item art), do not publish those images to app fields.

## Octopus Status

Current state (see `octopus_trace_report.json` in the canonical build cache):

- `Octopus_CardData` references material `CF_M_VAN_Octopus`.
- Material `_MainTex` points to an external CAB/pathId:
  - `archive:/CAB-9cecbe5bd5bb067e7aed10c0ae795876/...`
  - `pathId=3848771964933730348`
- Full catalog-derived bundle scan did not resolve that pathId.

Operational fallback:

- Keep Octopus in `disableImageForItemIds` until external reference resolves in a
  future build or we obtain a verified manual source asset.

## Standard Runbook

### 0) Unified review-first pipeline (recommended)

Run from `firebase/`:

```bash
npm run pipeline:game-update -- --mode review
```

This command fetches/parses the latest game build and writes:

- `schema_report.json`
- `catalog_review_report.json`
- `catalog_review_report.md`

for manual review before any production writes.

To include image extraction in that same run:

```bash
npm run pipeline:game-update -- --mode review --includeImages true
```

To apply after review approval:

```bash
npm run pipeline:game-update -- --mode apply --projectId <projectId> --serviceAccount ./service-account.local.json --confirmApply "I_UNDERSTAND"
```

`apply` mode still runs review first, then:

1. extracts images,
2. exports forced overrides (`forcedAssetByItemId`),
3. merges artfix manifests over base manifests,
4. seeds Firestore/Storage,
5. applies controlled fallbacks and inactive-name policy.

### A) Re-export forced fixes

```bash
python scripts/export_item_images_by_asset_name.py --buildId <buildId> --outSuffix <suffix>
```

Optional subset:

```bash
python scripts/export_item_images_by_asset_name.py --buildId <buildId> --outSuffix <suffix> --onlyItemIds "<id1>|<id2>"
```

### B) Seed to Storage + Firestore

```bash
node scripts/seed_catalog_from_game.js \
  --projectId <projectId> \
  --serviceAccount ./service-account.local.json \
  --storageBucket <bucket> \
  --storagePrefix catalog_items \
  --signedUrlDays 365 \
  --thumbImagesManifest <thumb_manifest_path> \
  --fullImagesManifest <full_manifest_path>
```

### C) Apply controlled fallback clears (if needed)

```bash
node scripts/apply_item_art_fallbacks.js \
  --projectId <projectId> \
  --serviceAccount ./service-account.local.json \
  --overridesFile ./data/item_art_overrides.json
```

### D) Validate thumb/full parity

```bash
node scripts/validate_item_image_parity.js \
  --projectId <projectId> \
  --serviceAccount ./service-account.local.json \
  --itemIds "<id1>|<id2>|<id3>"
```

## Cache Retention Policy

Keep:

- Canonical build snapshot directory above (including downloaded bundles).
- Latest build snapshot.
- Last successfully seeded build snapshot (tracked by `.cache/game-builds/_metadata/last_seeded_build.json`).
- Final trace/report artifacts needed for future debugging:
  - `octopus_trace_report.json`
  - `pathid_scan_progress.json` / `pathid_scan_found.json` (if present)
  - final manifests used for seeded corrections
- For full reseed reproducibility, keep both:
  - manifest files used in the last successful apply
  - all PNGs referenced by those manifest `imagePath` values

Safe to purge when space is needed:

- Duplicate temporary export directories from abandoned trials.
- Intermediate scratch outputs not tied to current seeded state.
- Old one-off debugging reports that are superseded by canonical trace/report files.

Use the cleanup tool in dry-run mode first:

```bash
npm run cleanup:game-cache
```

Deep cleanup preview (stale `exported_item_*` trial outputs inside kept builds):

```bash
npm run cleanup:game-cache:deep
```

Deep mode also removes non-essential report files, while preserving latest review reports and canonical forensic reports.

Apply deletions only after verifying the list:

```bash
npm run cleanup:game-cache -- --apply
```

Deep cleanup apply:

```bash
npm run cleanup:game-cache -- --deep --apply
```

