# Skill: update-catalog

Run the Bazaar item catalog update pipeline after a game update. Drives review → human gate → apply in sequence, surfacing the review report so script edits can be made before any Firestore writes occur.

---

## How to invoke

`/update-catalog` — full pipeline (review + images, then optionally apply)
`/update-catalog review` — review phase only, stop before apply prompt
`/update-catalog apply` — skip re-review, go straight to apply (use only if review already done this session)

---

## Pipeline constants

```
FIREBASE_DIR      : firebase/          (relative to repo root)
PROJECT_ID        : bazaarchecklist-f55e5
SERVICE_ACCOUNT   : ./service-account.local.json   (relative to firebase/)
```

---

## Step 1 — Review phase

Run from `firebase/`:

```bash
npm run pipeline:game-update -- --mode review --includeImages true
```

This will:
- Download the latest game build ZIP from `https://data.playthebazaar.com/`
- Extract and hash it into `.cache/game-builds/<buildId>/`
- Validate `cards.json` schema → `schema_report.json`
- Generate catalog diff → `catalog_review_report.json` + `catalog_review_report.md`
- Extract item images from Unity bundles → PNG files + manifests
- Re-export forced asset overrides from `data/item_art_overrides.json`
- Merge manifests (preserving historical art fixes)

**After this completes**, locate the report:

```bash
# Find the report for the newly downloaded build
ls .cache/game-builds/
# The newest timestamped directory is the current build
```

Read `.cache/game-builds/<buildId>/catalog_review_report.md` and present a structured summary to the user covering:
- New items added (count + names)
- Items removed or deactivated
- Items with changed fields (name, rarity, hero, tags, hiddenTags, size)
- Any schema warnings from `schema_report.json`
- Any image extraction warnings (unresolved assets, items without images)
- Bracketed/debug-name items that will be auto-deactivated

---

## Step 2 — Human review gate

After presenting the summary, pause and ask the user:

> "Review the findings above. Check the review checklist below before proceeding:
>
> - [ ] New item IDs look like valid game additions (not test/debug items)
> - [ ] Changed names/tags/hero/rarity look like parser-correct game data
> - [ ] Active→inactive transitions make sense (bracketed debug names expected)
> - [ ] Image fallback behavior is correct for unresolved/wrong-semantic art
> - [ ] `data/item_art_overrides.json` updated if any new items need forced asset bindings
> - [ ] Any script workarounds needed for new irregularities (e.g. `NAME_MISMATCH_OVERRIDES` in `extract_item_images_from_game.py`)
>
> Ready to apply to Firestore? (yes / no / I need to make script changes first)"

If the user says **no** or wants to make script changes: stop here. Remind them to re-run `/update-catalog review` after edits if image extraction needs to be redone, or `/update-catalog apply` if only metadata scripts changed and the manifests are already correct.

If the user says **yes**: proceed to Step 3.

---

## Step 3 — Apply phase

Run from `firebase/`:

```bash
npm run pipeline:game-update -- --mode apply --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json --storageBucket bazaarchecklist-f55e5.firebasestorage.app --confirmApply "I_UNDERSTAND"
```

This will:
- Seed all catalog item metadata to Firestore `catalog_items`
- Upload PNGs to Firebase Storage and write signed URLs
- Apply art fallback clears from `disableImageForItemIds`
- Deactivate items matching the inactive-name denylist

Report back the apply output — specifically: items seeded count, images uploaded count, items deactivated, any errors.

---

## Step 4 — Validate image parity

After apply succeeds, run a quick parity check. If there are specific item IDs to check (e.g. newly added items flagged during review), run:

```bash
node scripts/validate_item_image_parity.js --itemIds "<id1>|<id2>" --serviceAccount ./service-account.local.json --projectId bazaarchecklist-f55e5
```

Report any items missing thumb or full URLs.

---

## Step 5 — Cache cleanup (optional)

Offer cleanup at the end:

> "Run a dry-run cache cleanup to see what old builds can be purged?"

If yes, run from `firebase/`:

```bash
npm run cleanup:game-cache
```

Present the list of build directories flagged for deletion. If the user wants to apply:

```bash
npm run cleanup:game-cache -- --apply
```

Remind the user: the cleanup always keeps the canonical build, the latest build, and the last successfully seeded build. The `--deep` flag additionally prunes trial export directories and stale reports inside kept builds.

---

## Error handling guidance

| Symptom | Likely cause | What to suggest |
|---|---|---|
| Image extraction fails for a specific item | New item has unusual Unity asset layout | Check `octopus_trace_report.json`; may need entry in `item_art_overrides.json` |
| Item appears with wrong art (monster/combat texture) | Heuristic mismatch | Add to `disableImageForItemIds` or `forcedAssetByItemId` in `data/item_art_overrides.json` |
| New items missing from report | Parser not recognizing new card type | Check `NAME_MISMATCH_OVERRIDES` and schema validation warnings |
| Apply fails with auth error | Service account file missing or expired | Verify `firebase/service-account.local.json` exists and is current |
| Build already cached (no download) | Same build hash as last run | Game hasn't updated; confirm with user before exiting |
