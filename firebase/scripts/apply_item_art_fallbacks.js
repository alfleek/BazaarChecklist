/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const t = argv[i];
    if (!t.startsWith('--')) continue;
    const key = t.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function getRequiredArg(args, key) {
  const v = args[key];
  if (!v || typeof v !== 'string') {
    throw new Error(`Missing required --${key}`);
  }
  return v;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node apply_item_art_fallbacks.js --projectId <project-id> --serviceAccount <path> [--overridesFile <path>] [--dryRun]

Notes:
  - Clears imageThumbUrl/imageFullUrl for item IDs listed in disableImageForItemIds in overrides JSON.
    `.trim());
    return;
  }
  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccountPath = path.resolve(getRequiredArg(args, 'serviceAccount'));
  const overridesPath = path.resolve(
    typeof args.overridesFile === 'string' && args.overridesFile.trim()
      ? args.overridesFile.trim()
      : path.join(__dirname, '..', 'data', 'item_art_overrides.json'),
  );
  const dryRun = args.dryRun === true;

  const svc = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const overrides = JSON.parse(fs.readFileSync(overridesPath, 'utf8'));
  const ids = Array.isArray(overrides.disableImageForItemIds)
    ? overrides.disableImageForItemIds.filter((x) => typeof x === 'string' && x)
    : [];

  admin.initializeApp({
    credential: admin.credential.cert(svc),
    projectId,
  });
  const db = admin.firestore();

  console.log(`disableImageForItemIds count=${ids.length} dryRun=${dryRun}`);
  if (ids.length === 0) return;

  if (dryRun) {
    for (const id of ids) console.log(`would clear image urls for ${id}`);
    return;
  }

  const writeBatchSize = 400;
  let batch = db.batch();
  let ops = 0;
  let updated = 0;
  const commit = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  for (const id of ids) {
    const ref = db.collection('catalog_items').doc(id);
    batch.set(
      ref,
      {
        imageThumbUrl: admin.firestore.FieldValue.delete(),
        imageFullUrl: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    ops += 1;
    updated += 1;
    if (ops >= writeBatchSize) {
      // eslint-disable-next-line no-await-in-loop
      await commit();
    }
  }
  await commit();
  console.log(`cleared image fields for docs=${updated}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

