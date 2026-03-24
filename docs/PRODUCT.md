# BazaarChecklist — Product

## One-liner

An **unofficial** companion app for the game **The Bazaar** (deckbuilding autobattler): record winning boards, track which in-game items you have won with, and browse the catalog to see what you have and have not won with yet.

## Audience

Players who want a personal history of successful boards and item coverage, optionally synced across devices.

## Disclaimer (required in-app copy later)

This project is **not affiliated with or endorsed by** the makers of The Bazaar. Item names and related assets may be subject to trademark or copyright; this app is a personal tracker only.

## Confirmed goals (from planning)

- **Platforms**: Flutter for **mobile (priority)** and **web**, with the intent that neither platform is missing core features by design.
- **Backend**: **Firebase** for cloud in the first version (auth + Firestore + hosting for web when applicable). **Ruby / custom servers** are out of scope unless explicitly added here later.
- **Data**: Users can use the app as a **guest** with **local** storage; signed-in users can **sync** data to the cloud so mobile and web can access it.
- **Item catalog**: **Master catalog in Firestore**, seeded and maintained by the project owner (e.g. Console or scripts)—not assumed to be scraped from the game automatically in v1.
- **Timeline**: **Short MVP window (~2–4 weeks)** — ship a demonstrable mobile experience first; web deployment may follow in the same phase or immediately after, per roadmap.

## MVP scope (confirmed)

| Capability | Include in MVP? |
|------------|-----------------|
| Browse/search item catalog (from Firestore) | Yes |
| Record a “win” as a set of items from the catalog | Yes |
| List past wins | Yes |
| Per-item status: won at least once vs. never | Yes |
| Guest mode (local-only wins) | Yes |
| Account + cloud persistence (Firestore) | Yes |
| Merge or upload guest wins after sign-in | Yes (merge local wins into cloud) |
| Web build + hosting | Stretch |

## MVP app navigation (confirmed)

- Bottom navigation has three primary tabs:
  - `Runs` (default home)
  - `Catalog`
  - `Account`
- Run creation is a primary action from `Runs` via a `+ Add run` action (FAB or equivalent), not a dedicated tab.
- `Challenges` remains a stretch feature and should not appear in primary bottom navigation until functional.

## Auth (confirmed for MVP)

- Email/password sign-in.
- Google sign-in option.
- Apple sign-in option.

Current implementation note:
- Apple sign-in is currently surfaced in UI as a coming-soon option; backend auth wiring is pending a follow-up implementation task.

### Guest-first startup flow (confirmed)

- If no authenticated user exists on app start, the app opens in guest context by default.
- Login is an explicit action from onboarding/account surfaces, not an initial blocking wall.
- Guest users should see a lightweight onboarding card on first run with:
  - `Start tracking`
  - `Sign in to sync`

## Win record fields (confirmed)

Each win should support:

- Required: `itemIds`, `createdAt`.
- Required: `mode` (`ranked` or `normal`).
- Required: `hero` (selected from a maintained hero list).
- Required: run outcome metrics (`wins` and `perfect`).
- Optional: screenshot.
- Optional: notes (max 500 characters).

Stretch:

- Per-item `enchanted` toggle on the win board entry.

## Run result classification (confirmed)

Each run can end with up to 10 wins and is classified as:

- `0` to `3` wins: **defeat**
- `4` to `6` wins: **bronzeVictory**
- `7` to `9` wins: **silverVictory**
- `10` wins: **goldVictory**
- `10` wins and `perfect = true`: **diamondVictory** (perfect run)

The app should store enough run data to classify and display these labels consistently.

## Planned feature set additions

### Search and filtering system

The app/site should support:

- Text search for specific items.
- Filter combinations (for example by hero tag, type tags, rarity, size, and won-status).
- Ordering options (for example alphabetical, most won with, least won with, and newest added).

Status: **MVP**.

### Achievement system

The app/site should include an achievement-style progress area inspired by challenge systems:

- Progress by hero (for example “won with X/Y items tagged to hero A”).
- Progress by item type tags.
- Additional category groups can be added later.

Status: **Stretch**.

## Catalog fields (confirmed baseline)

Each catalog item should include:

- Stable id + display name.
- Type tags (list).
- Hero tag.
- Starting rarity.
- Size.

Stretch:

- `imageUrl`.

## Non-goals (v1)

- Official API integration with the game client.
- Automated catalog updates from game patches (manual catalog updates only unless you add a process later).
- Leaderboards, public profiles, or social feeds (unless added to this doc).

## Additional constraints (confirmed)

- Hosted web URL is **not required** for the class grade.
- Mobile remains the first priority for MVP quality.
- Keep Firestore collection names as currently documented.
