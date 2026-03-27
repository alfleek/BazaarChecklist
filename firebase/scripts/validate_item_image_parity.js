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
  if (!v || typeof v !== 'string') throw new Error(`Missing --${key}`);
  return v;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node validate_item_image_parity.js --projectId <project-id> --serviceAccount <path> --itemIds "<id1>|<id2>|..."

Notes:
  - Checks thumb/full URL presence parity for targeted catalog item docs.
    `.trim());
    return;
  }
  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccountPath = path.resolve(getRequiredArg(args, 'serviceAccount'));
  const itemIds = typeof args.itemIds === 'string'
    ? args.itemIds.split('|').map((s) => s.trim()).filter(Boolean)
    : [];

  const svc = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(svc),
    projectId,
  });
  const db = admin.firestore();

  if (itemIds.length === 0) {
    console.log('No itemIds provided.');
    return;
  }

  const out = [];
  for (const id of itemIds) {
    // eslint-disable-next-line no-await-in-loop
    const snap = await db.collection('catalog_items').doc(id).get();
    const data = snap.data() || {};
    const thumb = typeof data.imageThumbUrl === 'string' && data.imageThumbUrl.length > 0;
    const full = typeof data.imageFullUrl === 'string' && data.imageFullUrl.length > 0;
    out.push({
      id,
      name: data.name || '',
      thumbPresent: thumb,
      fullPresent: full,
      parityOk: thumb === full,
    });
  }

  const bad = out.filter((x) => !x.parityOk);
  console.log(JSON.stringify({ checked: out.length, parityMismatchCount: bad.length, rows: out }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

