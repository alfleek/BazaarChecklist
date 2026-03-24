# Firebase setup

**Purpose**: Human-run checklist to create the Firebase project and connect the Flutter app. **Do not commit secrets.**

## Prerequisites

- Firebase account
- Flutter SDK installed
- FlutterFire CLI (`dart pub global activate flutterfire_cli`) when you are ready to wire the app.

## Steps (high level)

1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Register apps: **Android**, **iOS**, and **Web** for the Flutter project under [mobile/](mobile/).
3. Enable **Authentication** — email/password, Google, and Apple.
4. Create a **Firestore** database (production mode), then deploy **Security Rules** aligned with [DATA_MODEL.md](DATA_MODEL.md).
5. (Optional for web) Enable **Firebase Hosting** for `flutter build web` output.

## Manual catalog seeding (MVP)

For MVP, catalog data is entered manually in Firebase Console (no seed script required).

Create documents under `catalog_items/{itemId}` with these baseline fields:

- `name` (string)
- `typeTags` (array of strings)
- `heroTag` (string)
- `startingRarity` (string)
- `size` (number)
- `active` (bool, set `true` for visible items)
- `updatedAt` (timestamp, optional)
- `imageUrl` (string, optional)

Example document (`catalog_items/vanessa_boiling_kettle`):

- `name`: `Boiling Kettle`
- `typeTags`: `["burn", "weapon"]`
- `heroTag`: `vanessa`
- `startingRarity`: `rare`
- `size`: `2`
- `active`: `true`

## Files that must stay out of git (typical)

- `google-services.json` (Android) — often gitignored; confirm team policy.
- `GoogleService-Info.plist` (iOS) — same.
- Any API keys in source — prefer FlutterFire / build-time configuration; never paste keys into `docs/`.

## FlutterFire

When you start implementation, run `flutterfire configure` from the Flutter package directory and follow official FlutterFire docs for the current Flutter/Dart SDK.

## Open items

- Screenshot strategy is split by mode: guest uses local image storage; signed-in users may upload screenshots to Firebase Storage.
- Whether to use separate Firebase projects for dev/staging/prod (recommended for production; for class, a single project may suffice).
