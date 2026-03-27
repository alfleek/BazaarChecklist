# Firebase tooling

This folder contains local tooling for Firestore seeding and catalog/image workflows.

## Folder layout

- `scripts/` - executable JS/Python tools.
- `data/` - source inputs used by scripts (for example art overrides).
  - `data/sources/` - large local source exports (for example `cards.json`, gitignored).
- `reports/` - generated reports and temporary outputs (ignored by git).
- `docs/` - workflow docs for image/catalog pipelines.

## 1) Install dependencies

From this folder:

```bash
npm install
```

## 2) Add service account JSON (local only)

Download a Firebase service account key and save it in this folder, for example:

`service-account.local.json`

This file is ignored by git via `.gitignore`.

## 3) Run seed

```bash
npm run seed:firestore -- --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json
```

To include sample runs for a specific signed-in user:

```bash
npm run seed:firestore -- --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json --uid <firebase-auth-uid>
```

The script upserts:

- `heroes`
- `catalog_items`
- optional `users/{uid}/runs`
