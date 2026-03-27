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

async function upsertDoc(ref, data) {
  await ref.set(
    {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function seedHeroes(db) {
  const heroes = [
    { id: 'Vanessa', name: 'Vanessa', active: true },
    { id: 'Dooley', name: 'Dooley', active: true },
    { id: 'Pygmalien', name: 'Pygmalien', active: true },
    { id: 'Stelle', name: 'Stelle', active: true },
    { id: 'Jules', name: 'Jules', active: true },
    { id: 'Karnok', name: 'Karnok', active: true },
  ];

  for (const hero of heroes) {
    await upsertDoc(db.collection('heroes').doc(hero.id), hero);
  }
  console.log(`Seeded ${heroes.length} heroes`);
}

async function seedCatalogItems(db) {
  const items = [
    {
      id: 'anaconda',
      name: 'Anaconda',
      typeTags: ['Weapon', 'Vehicle', 'Aquatic', 'Friend'],
      heroTag: 'Karnok',
      startingRarity: 'Gold',
      size: 'Large',
      active: true,
    },
    {
      id: 'boiling_kettle',
      name: 'Boiling Kettle',
      typeTags: ['Weapon', 'Burn'],
      heroTag: 'Vanessa',
      startingRarity: 'Rare',
      size: 'Medium',
      active: true,
    },
    {
      id: 'spark_lantern',
      name: 'Spark Lantern',
      typeTags: ['Tool', 'Burn'],
      heroTag: 'Vanessa',
      startingRarity: 'Common',
      size: 'Small',
      active: true,
    },
    {
      id: 'anchor_cannon',
      name: 'Anchor Cannon',
      typeTags: ['Weapon', 'Aquatic'],
      heroTag: 'Vanessa',
      startingRarity: 'Epic',
      size: 'Large',
      active: true,
    },
    {
      id: 'salvage_hook',
      name: 'Salvage Hook',
      typeTags: ['Weapon', 'Economy'],
      heroTag: 'Dooley',
      startingRarity: 'Rare',
      size: 'Medium',
      active: true,
    },
    {
      id: 'scrap_press',
      name: 'Scrap Press',
      typeTags: ['Tool', 'Economy'],
      heroTag: 'Dooley',
      startingRarity: 'Common',
      size: 'Small',
      active: true,
    },
    {
      id: 'brass_bulwark',
      name: 'Brass Bulwark',
      typeTags: ['Shield', 'Defense'],
      heroTag: 'Dooley',
      startingRarity: 'Rare',
      size: 'Large',
      active: true,
    },
    {
      id: 'coin_splitter',
      name: 'Coin Splitter',
      typeTags: ['Weapon', 'Economy'],
      heroTag: 'Pygmalien',
      startingRarity: 'Uncommon',
      size: 'Medium',
      active: true,
    },
    {
      id: 'gilded_gloves',
      name: 'Gilded Gloves',
      typeTags: ['Accessory', 'Crit'],
      heroTag: 'Pygmalien',
      startingRarity: 'Rare',
      size: 'Small',
      active: true,
    },
    {
      id: 'market_map',
      name: 'Market Map',
      typeTags: ['Tool', 'Economy'],
      heroTag: 'Pygmalien',
      startingRarity: 'Common',
      size: 'Small',
      active: true,
    },
  ];

  for (const item of items) {
    await upsertDoc(db.collection('catalog_items').doc(item.id), item);
  }
  console.log(`Seeded ${items.length} catalog items`);
}

function getRunsSeed(uid) {
  return [
    {
      id: '2026_03_24_ranked_vanessa_10',
      data: {
        itemIds: ['boiling_kettle', 'anchor_cannon', 'spark_lantern'],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        mode: 'ranked',
        heroId: 'Vanessa',
        wins: 10,
        perfect: false,
        resultTier: 'goldVictory',
        notes: 'Strong burn scaling after mid game.',
        screenshotPath: '',
        screenshotUrl: '',
        ownerUid: uid,
      },
    },
    {
      id: '2026_03_24_normal_dooley_6',
      data: {
        itemIds: ['salvage_hook', 'scrap_press', 'brass_bulwark'],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        mode: 'normal',
        heroId: 'Dooley',
        wins: 6,
        perfect: false,
        resultTier: 'bronzeVictory',
        notes: 'Stabilized early, weak final fights.',
        screenshotPath: '',
        screenshotUrl: '',
        ownerUid: uid,
      },
    },
  ];
}

async function seedRuns(db, uid) {
  const runs = getRunsSeed(uid);
  const runsCollection = db.collection('users').doc(uid).collection('runs');
  for (const run of runs) {
    await upsertDoc(runsCollection.doc(run.id), run.data);
  }
  console.log(`Seeded ${runs.length} runs for uid=${uid}`);
}

function loadServiceAccount(serviceAccountPath) {
  const absolutePath = path.resolve(serviceAccountPath);
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Service account file not found: ${absolutePath}`);
  }
  return JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node seed_firestore.js --projectId <project-id> --serviceAccount <path> [--uid <auth-uid>]

Examples:
  node seed_firestore.js --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json
  node seed_firestore.js --projectId bazaarchecklist-f55e5 --serviceAccount ./service-account.local.json --uid roBL1moygcWc9oThYB3R9BwXhlC3
    `.trim());
    return;
  }

  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccountPath = getRequiredArg(args, 'serviceAccount');
  const uid = typeof args.uid === 'string' ? args.uid.trim() : '';

  const serviceAccount = loadServiceAccount(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });

  const db = admin.firestore();
  await seedHeroes(db);
  await seedCatalogItems(db);
  if (uid) {
    await seedRuns(db, uid);
  } else {
    console.log('Skipped runs seed (no --uid provided)');
  }
  console.log('Firestore seed completed');
}

main().catch((error) => {
  console.error('Firestore seed failed');
  console.error(error);
  process.exit(1);
});
