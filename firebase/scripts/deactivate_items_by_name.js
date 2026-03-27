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

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

const DEFAULT_INACTIVE_NAMES = [
  'Artificial Heart',
  'Assembly Line',
  'Atlas',
  'Compass',
  'Coupon',
  'Cybernetic Implants',
  'Cyclops eye',
  'Elixir of immortality',
  'Flying pig',
  'Genie lamp',
  'Holo-Disguise Generator',
  'Javalin',
  'Lucky clover',
  'Mysterious Gift',
  'Nanobot Blue',
  'Nanobot Green',
  'Nanobot Orange',
  'Nanobot Red',
  'Old Barrel',
  'Plasma whip',
  'Poison blades',
  'Pyro Gauntlet',
  'Sonic cannon',
  'Yeti Claw',
].map((n) => n.trim()).filter(Boolean);

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    console.log(`
Usage:
  node deactivate_items_by_name.js --projectId <project-id> --serviceAccount <path> [--dryRun] [--namesFile <path>]

Notes:
  - First tries Firestore 'name in [...]' exact matches (case-sensitive).
  - Then falls back to scanning all catalog_items and matching by lowercased name.
  - Sets { active: false } and updates { updatedAt }.
    `.trim());
    return;
  }

  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccountPath = getRequiredArg(args, 'serviceAccount');
  const dryRun = args.dryRun === true;
  const namesFile =
    typeof args.namesFile === 'string' && args.namesFile.trim()
      ? path.resolve(args.namesFile.trim())
      : null;

  const serviceAccountAbsPath = path.resolve(serviceAccountPath);
  if (!fs.existsSync(serviceAccountAbsPath)) {
    throw new Error(`Service account file not found: ${serviceAccountAbsPath}`);
  }
  const serviceAccount = JSON.parse(
    fs.readFileSync(serviceAccountAbsPath, 'utf8'),
  );

  let inactiveNames = DEFAULT_INACTIVE_NAMES;
  if (namesFile) {
    if (!fs.existsSync(namesFile)) {
      throw new Error(`namesFile not found: ${namesFile}`);
    }
    const raw = fs.readFileSync(namesFile, 'utf8');
    inactiveNames = raw
      .split(/\r?\n/g)
      .map((s) => s.trim())
      .filter(Boolean);
  }

  const wantedByNorm = new Map();
  for (const n of inactiveNames) wantedByNorm.set(normalizeName(n), n);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });
  const db = admin.firestore();

  const matched = new Map(); // norm -> [{id, name}]
  const allDocsToDeactivate = new Map(); // docId -> {name}

  // Firestore 'in' queries accept limited elements; chunk conservatively.
  const chunks = chunk(inactiveNames, 10);
  for (const group of chunks) {
    // eslint-disable-next-line no-await-in-loop
    const snap = await db
      .collection('catalog_items')
      .where('name', 'in', group)
      .get();
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const docName = (data.name ?? '').toString();
      const norm = normalizeName(docName);
      if (!wantedByNorm.has(norm)) continue;
      if (!matched.has(norm)) matched.set(norm, []);
      matched.get(norm).push({ id: doc.id, name: docName });
      allDocsToDeactivate.set(doc.id, { name: docName });
    }
  }

  let notFound = [];
  for (const [norm, original] of wantedByNorm.entries()) {
    if (!matched.has(norm)) notFound.push(original);
  }

  // Fallback: scan all catalog_items and match by normalized name to catch
  // capitalization differences (Firestore string queries are case-sensitive).
  if (notFound.length > 0) {
    const byNormFromDb = new Map(); // norm -> [{id, name}]
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
        const docName = (data.name ?? '').toString();
        const norm = normalizeName(docName);
        if (!norm) continue;
        if (!byNormFromDb.has(norm)) byNormFromDb.set(norm, []);
        byNormFromDb.get(norm).push({ id: doc.id, name: docName });
      }
      lastDoc = snap.docs[snap.docs.length - 1];
    }

    for (const original of notFound) {
      const norm = normalizeName(original);
      const docs = byNormFromDb.get(norm);
      if (!docs || docs.length === 0) continue;
      if (!matched.has(norm)) matched.set(norm, []);
      for (const d of docs) {
        matched.get(norm).push(d);
        allDocsToDeactivate.set(d.id, { name: d.name });
      }
    }

    notFound = [];
    for (const [norm, original] of wantedByNorm.entries()) {
      if (!matched.has(norm)) notFound.push(original);
    }
  }

  console.log(
    JSON.stringify(
      {
        dryRun,
        requestedCount: inactiveNames.length,
        matchedCount: matched.size,
        docsToDeactivateCount: allDocsToDeactivate.size,
        notFoundCount: notFound.length,
      },
      null,
      2,
    ),
  );

  if (notFound.length > 0) {
    console.log('Not found (even after lowercased full-scan match):');
    for (const n of notFound) console.log(`- ${n}`);
  }

  const duplicates = [];
  for (const [norm, docs] of matched.entries()) {
    if (docs.length > 1) {
      duplicates.push({ name: wantedByNorm.get(norm), docs });
    }
  }
  if (duplicates.length > 0) {
    console.log('Warning: multiple catalog_items matched same name:');
    for (const d of duplicates) {
      console.log(`- ${d.name}: ${d.docs.map((x) => x.id).join(', ')}`);
    }
  }

  if (dryRun) {
    console.log('Dry run: no writes performed.');
    return;
  }

  const writeBatchSize = 400;
  let batch = db.batch();
  let ops = 0;
  let updated = 0;

  const commitBatch = async () => {
    if (ops === 0) return;
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  for (const [docId, info] of allDocsToDeactivate.entries()) {
    const ref = db.collection('catalog_items').doc(docId);
    batch.set(
      ref,
      {
        active: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    ops += 1;
    updated += 1;
    if (ops >= writeBatchSize) {
      // eslint-disable-next-line no-await-in-loop
      await commitBatch();
    }
  }
  await commitBatch();

  console.log(`Deactivated docs: ${updated}`);
  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

