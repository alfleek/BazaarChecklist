/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const crypto = require('node:crypto');
const admin = require('firebase-admin');

const AdmZip = require('adm-zip');

const DEFAULT_URL =
  'https://data.playthebazaar.com/game/windows/buildx64.zip';
const CARDS_JSON_REL_PATH = 'TheBazaar_Data/StreamingAssets/cards.json';

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

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function sha256File(filePath) {
  const h = crypto.createHash('sha256');
  const s = fs.createReadStream(filePath);
  return new Promise((resolve, reject) => {
    s.on('data', (d) => h.update(d));
    s.on('error', reject);
    s.on('end', () => resolve(h.digest('hex')));
  });
}

function downloadFile(url, outPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(outPath);
    https
      .get(url, (res) => {
        if (res.statusCode !== 200) {
          reject(
            new Error(
              `Download failed: ${url} status=${res.statusCode}`,
            ),
          );
          res.resume();
          return;
        }
        res.pipe(file);
        file.on('finish', () => {
          file.close(() => resolve());
        });
      })
      .on('error', (err) => reject(err));
  });
}

function findCardsJsonEntry(zip) {
  const entries = zip.getEntries();
  const wantedRel = CARDS_JSON_REL_PATH.replaceAll('\\', '/');
  const wanted = entries.find((e) => {
    const normalized = e.entryName.replaceAll('\\', '/');
    return normalized === wantedRel || normalized.endsWith(`/${wantedRel}`);
  });
  if (!wanted) {
    const ends = entries
      .map((e) => e.entryName.replaceAll('\\', '/'))
      .filter((n) => n.toLowerCase().includes('cards.json'))
      .slice(0, 10);
    throw new Error(
      `Could not find ${CARDS_JSON_REL_PATH} inside zip. Top matching: ${ends.join(
        ', ',
      )}`,
    );
  }
  return wanted;
}

function normalizeToStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((x) => typeof x === 'string')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function normalizeToString(value) {
  if (value == null) return '';
  if (typeof value === 'string') return value.trim();
  return value.toString().trim();
}

function pickArrayFirst(value, fallback = '') {
  if (!Array.isArray(value) || value.length === 0) return fallback;
  const v0 = value[0];
  return typeof v0 === 'string' ? v0.trim() : normalizeToString(v0);
}

function shouldDeactivateByBracketedName(name) {
  // Example: "[DEBUG] Something" or "Something [DEBUG] Something".
  // This is a coarse heuristic intended to keep debug/dev/test templates out
  // of the user-facing catalog.
  const n = normalizeToString(name);
  return /\[[^\]]+\]/.test(n);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    console.log(`
Usage:
  npm run seed:catalog-from-game -- --projectId <project-id> --serviceAccount <path> [--url <build-url>] [--dryRun] [--limit <n>] [--cardsJsonPath <path>] [--deactivateMissing]

Examples:
  npm run seed:catalog-from-game -- --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json --dryRun
  npm run seed:catalog-from-game -- --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json --limit 20
    `.trim());
    return;
  }

  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccountPath = getRequiredArg(args, 'serviceAccount');
  const thumbImagesManifestPath =
    typeof args.thumbImagesManifest === 'string'
    && args.thumbImagesManifest.trim()
    ? path.resolve(args.thumbImagesManifest.trim())
    : (
      typeof args.imagesManifest === 'string'
      && args.imagesManifest.trim()
        ? path.resolve(args.imagesManifest.trim())
        : null
    );

  const fullImagesManifestPath =
    typeof args.fullImagesManifest === 'string' && args.fullImagesManifest.trim()
      ? path.resolve(args.fullImagesManifest.trim())
      : null;

  const signedUrlDays =
    typeof args.signedUrlDays === 'string'
      ? Number(args.signedUrlDays)
      : 365;

  const storagePrefix =
    typeof args.storagePrefix === 'string' && args.storagePrefix.trim()
      ? args.storagePrefix.trim().replace(/\/+$/, '')
      : 'catalog_items';

  const storageBucketName =
    typeof args.storageBucket === 'string' && args.storageBucket.trim()
      ? args.storageBucket.trim()
      : null;

  const serviceAccountAbsPath = path.resolve(serviceAccountPath);
  if (!fs.existsSync(serviceAccountAbsPath)) {
    throw new Error(`Service account file not found: ${serviceAccountAbsPath}`);
  }
  const serviceAccount = JSON.parse(
    fs.readFileSync(serviceAccountAbsPath, 'utf8'),
  );

  const url = typeof args.url === 'string' ? args.url : DEFAULT_URL;
  const dryRun = args.dryRun === true;
  const limit = typeof args.limit === 'string' ? Number(args.limit) : undefined;
  const deactivateMissing = args.deactivateMissing === true;

  const cacheBase = path.join(__dirname, '..', '.cache', 'game-builds');
  ensureDir(cacheBase);

  const localCardsJsonPath = args.cardsJsonPath;
  let cardsJsonPath = null;
  let snapshot = null;

  if (typeof localCardsJsonPath === 'string') {
    cardsJsonPath = path.resolve(localCardsJsonPath);
    snapshot = { cardsJsonPath, local: true };
  } else {
    const tmpZipPath = path.join(cacheBase, 'download_buildx64.zip');
    console.log(`Downloading build zip: ${url}`);
    await downloadFile(url, tmpZipPath);

    const buildId = await sha256File(tmpZipPath);
    const buildDir = path.join(cacheBase, buildId);
    ensureDir(buildDir);

    const zipPath = path.join(buildDir, 'buildx64.zip');
    if (!fs.existsSync(zipPath)) fs.copyFileSync(tmpZipPath, zipPath);

    const cardsJsonAbs = path.join(buildDir, 'cards.json');
    if (!fs.existsSync(cardsJsonAbs)) {
      console.log('Extracting cards.json from zip...');
      const zip = new AdmZip(zipPath);
      const entry = findCardsJsonEntry(zip);
      const out = zip.readFile(entry);
      fs.writeFileSync(cardsJsonAbs, out);
      console.log(`Extracted to ${cardsJsonAbs}`);
    } else {
      console.log(`Using cached extracted cards.json: ${cardsJsonAbs}`);
    }

    cardsJsonPath = cardsJsonAbs;
    snapshot = { buildId, cardsJsonPath, local: false };
  }

  console.log(`Reading cards.json: ${cardsJsonPath}`);
  const jsonText = fs.readFileSync(cardsJsonPath, 'utf8');
  const json = JSON.parse(jsonText);

  const topKeys = Object.keys(json);
  // Current schema uses a version string key that holds the card array.
  const versionKey = topKeys.find((k) => Array.isArray(json[k]));
  if (!versionKey) {
    throw new Error(
      `cards.json did not contain an array at a top-level key. keys=${topKeys.join(
        ',',
      )}`,
    );
  }
  const cards = json[versionKey];
  console.log(`cards array count: ${cards.length} (from key: ${versionKey})`);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });
  const db = admin.firestore();

  function loadImagesManifest(manifestPath) {
    if (!manifestPath) return new Map();
    if (!fs.existsSync(manifestPath)) {
      throw new Error(`imagesManifest not found: ${manifestPath}`);
    }
    const raw = fs.readFileSync(manifestPath, 'utf8');
    const parsed = JSON.parse(raw);
    const manifest = parsed.manifest || parsed;

    // Expected shape: { manifest: { [itemId]: { imagePath: ... } } }
    const out = new Map();
    for (const [itemId, v] of Object.entries(manifest)) {
      if (!v || typeof v !== 'object') continue;
      if (typeof v.imagePath !== 'string') continue;
      out.set(itemId, path.resolve(v.imagePath));
    }
    return out;
  }

  const thumbLocalByItemId = loadImagesManifest(thumbImagesManifestPath);
  const fullLocalByItemId = loadImagesManifest(fullImagesManifestPath);

  let signedThumbUrlByItemId = new Map();
  let signedFullUrlByItemId = new Map();

  if (!dryRun && (thumbLocalByItemId.size > 0 || fullLocalByItemId.size > 0)) {
    const bucket = storageBucketName
      ? admin.storage().bucket(storageBucketName)
      : admin.storage().bucket();
    const daysMs = signedUrlDays * 24 * 60 * 60 * 1000;
    const expires = Date.now() + daysMs;

    async function uploadAndSignAll(localByItemId, kind) {
      const out = new Map();
      const entries = Array.from(localByItemId.entries());
      console.log(
        `Uploading + signing ${kind} images: count=${entries.length} prefix=${storagePrefix}`,
      );

      // Sequential upload avoids overloading local networking.
      for (const [itemId, localPath] of entries) {
        const destination = `${storagePrefix}/${kind}/${itemId}.png`;
        const file = bucket.file(destination);

        await bucket.upload(localPath, {
          destination,
          metadata: { cacheControl: 'public,max-age=31536000' },
        });

        const [url] = await file.getSignedUrl({
          action: 'read',
          expires,
        });
        out.set(itemId, url);
      }
      return out;
    }

    signedThumbUrlByItemId = await uploadAndSignAll(
      thumbLocalByItemId,
      'thumbs',
    );
    signedFullUrlByItemId = await uploadAndSignAll(
      fullLocalByItemId,
      'full',
    );
    console.log(
      `Signed URLs ready: thumbs=${signedThumbUrlByItemId.size} full=${signedFullUrlByItemId.size} days=${signedUrlDays}`,
    );
  }

  let included = 0;
  const includedItemIds = new Set();
  const sampleItemIds = [];
  let skippedType = 0;
  let skippedHero = 0;
  let skippedPlaceholder = 0;
  let deactivated = 0;

  const writeBatchSize = 400;
  let batch = db.batch();
  let ops = 0;

  const commitBatch = async () => {
    if (ops === 0) return;
    if (dryRun) {
      batch = db.batch();
      ops = 0;
      return;
    }
    await batch.commit();
    batch = db.batch();
    ops = 0;
  };

  const runLimit = (limit && Number.isFinite(limit)) ? limit : Infinity;

  for (let i = 0; i < cards.length; i += 1) {
    if (included >= runLimit) break;
    const card = cards[i];
    if (!card || typeof card !== 'object') continue;

    if (card.Type !== 'Item') {
      skippedType += 1;
      continue;
    }

    const heroes = Array.isArray(card.Heroes) ? card.Heroes : [];
    if (heroes.length !== 1) {
      skippedHero += 1;
      continue;
    }

    const typeTags = normalizeToStringArray(card.Tags);
    const hiddenTags = normalizeToStringArray(card.HiddenTags);
    if (typeTags.length === 0 && hiddenTags.length === 0) {
      skippedPlaceholder += 1;
      continue;
    }

    const itemId = normalizeToString(card.Id);
    if (!itemId) continue;

    const data = {
      name: normalizeToString(card.InternalName),
      typeTags,
      hiddenTags,
      heroTag: pickArrayFirst(card.Heroes, ''),
      startingRarity: normalizeToString(card.StartingTier),
      size: normalizeToString(card.Size),
      active: !shouldDeactivateByBracketedName(card.InternalName),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const thumbUrl = signedThumbUrlByItemId.get(itemId);
    if (thumbUrl) data.imageThumbUrl = thumbUrl;
    const fullUrl = signedFullUrlByItemId.get(itemId);
    if (fullUrl) data.imageFullUrl = fullUrl;

    const ref = db.collection('catalog_items').doc(itemId);
    batch.set(ref, data, { merge: true });
    ops += 1;
    included += 1;
    includedItemIds.add(itemId);
    if (sampleItemIds.length < 10) sampleItemIds.push(itemId);

    if (ops >= writeBatchSize) {
      // eslint-disable-next-line no-await-in-loop
      await commitBatch();
    }
  }

  await commitBatch();

  if (deactivateMissing && !dryRun) {
    console.log('Deactivating missing catalog items...');

    const docsRef = db
      .collection('catalog_items')
      .orderBy(admin.firestore.FieldPath.documentId());

    const pageSize = 500;
    let lastDoc = null;
    while (true) {
      let q = docsRef.limit(pageSize);
      if (lastDoc) q = q.startAfter(lastDoc);
      // eslint-disable-next-line no-await-in-loop
      const snap = await q.get();
      if (snap.empty) break;

      for (const doc of snap.docs) {
        if (!includedItemIds.has(doc.id) && doc.data().active !== false) {
          batch.set(
            doc.ref,
            {
              active: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          ops += 1;
          deactivated += 1;
          if (ops >= writeBatchSize) {
            // eslint-disable-next-line no-await-in-loop
            await commitBatch();
          }
        }
      }

      lastDoc = snap.docs[snap.docs.length - 1];
    }

    await commitBatch();
    console.log(`Deactivated: ${deactivated}`);
  }

  console.log('Seed completed');
  console.log(
    JSON.stringify(
      {
        snapshot,
        totalCards: cards.length,
        included,
        skippedType,
        skippedHero,
        skippedPlaceholder,
        deactivated,
        dryRun,
        deactivateMissing,
        sampleItemIds,
      },
      null,
      2,
    ),
  );
}

main().catch((err) => {
  console.error('seed_catalog_from_game failed');
  console.error(err);
  process.exit(1);
});

