/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');

const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
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
  const value = args[key];
  if (!value || typeof value !== 'string') {
    throw new Error(`Missing required argument --${key}`);
  }
  return value;
}

function normalizeName(s) {
  return (s ?? '').toString().trim().toLowerCase();
}

const DEFAULT_NAMES = [
  'Coral',
  'Feather',
  'Ionized Lightning',
  'Nanobot',
  'Nitro',
  'Octopus',
  'Oven',
  'Piggles',
  'Weaponized core',
];

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node find_catalog_item_ids_by_name.js --projectId <project-id> --serviceAccount <path> [--names "a|b|c"]
    `.trim());
    return;
  }

  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccountPath = getRequiredArg(args, 'serviceAccount');

  const serviceAccountAbsPath = path.resolve(serviceAccountPath);
  if (!fs.existsSync(serviceAccountAbsPath)) {
    throw new Error(`Service account file not found: ${serviceAccountAbsPath}`);
  }
  const serviceAccount = JSON.parse(
    fs.readFileSync(serviceAccountAbsPath, 'utf8'),
  );

  const names = (typeof args.names === 'string' && args.names.trim())
    ? args.names.split('|').map((s) => s.trim()).filter(Boolean)
    : DEFAULT_NAMES;
  const wanted = new Map(names.map((n) => [normalizeName(n), n]));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });
  const db = admin.firestore();

  const byNorm = new Map(); // norm -> [{id, name}]
  const pageSize = 500;
  let lastDoc = null;
  while (true) {
    let q = db
      .collection('catalog_items')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    // eslint-disable-next-line no-await-in-loop
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const name = (data.name ?? '').toString();
      const norm = normalizeName(name);
      if (!wanted.has(norm)) continue;
      if (!byNorm.has(norm)) byNorm.set(norm, []);
      byNorm.get(norm).push({
        id: doc.id,
        name,
        active: data.active !== false,
        heroTag: data.heroTag ?? '',
        size: data.size ?? '',
        imageThumbUrl: data.imageThumbUrl ?? null,
        imageFullUrl: data.imageFullUrl ?? null,
      });
    }
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  const out = {};
  for (const [norm, original] of wanted.entries()) {
    out[original] = byNorm.get(norm) ?? [];
  }
  console.log(JSON.stringify(out, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

