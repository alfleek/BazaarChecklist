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

function normalizeToString(value) {
  if (value == null) return '';
  if (typeof value === 'string') return value.trim();
  return value.toString().trim();
}

function normalizeToStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((x) => typeof x === 'string')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function pickArrayFirst(value, fallback = '') {
  if (!Array.isArray(value) || value.length === 0) return fallback;
  const v0 = value[0];
  return typeof v0 === 'string' ? v0.trim() : normalizeToString(v0);
}

function shouldDeactivateByBracketedName(name) {
  return /\[[^\]]+\]/.test(normalizeToString(name));
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function stableStringify(value) {
  return JSON.stringify(value, Object.keys(value).sort());
}

function normalizeCardsObject(json) {
  if (!json || typeof json !== 'object') {
    throw new Error('cards.json top-level JSON must be object');
  }
  const versionKey = Object.keys(json).find((k) => Array.isArray(json[k]));
  if (!versionKey) {
    throw new Error('cards.json did not contain an array at any top-level key');
  }
  return { cards: json[versionKey], versionKey };
}

function toSeedShapeFromCard(card) {
  if (!card || typeof card !== 'object') return null;
  if (card.Type !== 'Item') return null;

  const heroes = Array.isArray(card.Heroes) ? card.Heroes : [];
  if (heroes.length !== 1) return null;

  const typeTags = normalizeToStringArray(card.Tags);
  const hiddenTags = normalizeToStringArray(card.HiddenTags);
  if (typeTags.length === 0 && hiddenTags.length === 0) return null;

  const itemId = normalizeToString(card.Id);
  if (!itemId) return null;

  return {
    itemId,
    name: normalizeToString(card.InternalName),
    typeTags: [...typeTags].sort(),
    hiddenTags: [...hiddenTags].sort(),
    heroTag: pickArrayFirst(card.Heroes, ''),
    startingRarity: normalizeToString(card.StartingTier),
    size: normalizeToString(card.Size),
    active: !shouldDeactivateByBracketedName(card.InternalName),
  };
}

function loadSeedShapeMapFromCards(cardsJsonPath) {
  const json = JSON.parse(fs.readFileSync(cardsJsonPath, 'utf8'));
  const { cards, versionKey } = normalizeCardsObject(json);
  const byId = new Map();
  let skipped = 0;
  for (const card of cards) {
    const normalized = toSeedShapeFromCard(card);
    if (!normalized) {
      skipped += 1;
      continue;
    }
    byId.set(normalized.itemId, normalized);
  }
  return {
    versionKey,
    byId,
    totalCards: cards.length,
    includedItems: byId.size,
    skippedCards: skipped,
  };
}

function normalizeFirestoreDoc(docId, data) {
  return {
    itemId: docId,
    name: normalizeToString(data.name),
    typeTags: normalizeToStringArray(data.typeTags).sort(),
    hiddenTags: normalizeToStringArray(data.hiddenTags).sort(),
    heroTag: normalizeToString(data.heroTag),
    startingRarity: normalizeToString(data.startingRarity),
    size: normalizeToString(data.size),
    active: data.active !== false,
  };
}

function sortedUnique(arr) {
  return [...new Set(arr)].sort();
}

function compareMaps({
  sourceMap,
  baselineMap,
  baselineLabel,
  sampleLimit = 200,
}) {
  const sourceIds = sortedUnique(Array.from(sourceMap.keys()));
  const baselineIds = sortedUnique(Array.from(baselineMap.keys()));

  const newItemIds = [];
  const removedItemIds = [];
  const changed = [];
  const unchangedIds = [];

  const baselineIdSet = new Set(baselineIds);
  const sourceIdSet = new Set(sourceIds);

  for (const id of sourceIds) {
    if (!baselineIdSet.has(id)) {
      newItemIds.push(id);
      continue;
    }
    const after = sourceMap.get(id);
    const before = baselineMap.get(id);
    const changedFields = [];
    for (const field of [
      'name',
      'heroTag',
      'startingRarity',
      'size',
      'active',
      'typeTags',
      'hiddenTags',
    ]) {
      const beforeJson = stableStringify({ v: before[field] });
      const afterJson = stableStringify({ v: after[field] });
      if (beforeJson !== afterJson) {
        changedFields.push(field);
      }
    }
    if (changedFields.length === 0) {
      unchangedIds.push(id);
      continue;
    }
    changed.push({
      itemId: id,
      changedFields,
      before,
      after,
    });
  }

  for (const id of baselineIds) {
    if (!sourceIdSet.has(id)) removedItemIds.push(id);
  }

  const changedFieldHistogram = {};
  for (const row of changed) {
    for (const f of row.changedFields) {
      changedFieldHistogram[f] = (changedFieldHistogram[f] ?? 0) + 1;
    }
  }

  const potentialRenames = changed
    .filter((row) => {
      if (row.changedFields.length !== 1) return false;
      return row.changedFields[0] === 'name';
    })
    .map((row) => ({
      itemId: row.itemId,
      beforeName: row.before.name,
      afterName: row.after.name,
    }))
    .slice(0, sampleLimit);

  return {
    baselineLabel,
    counts: {
      sourceItems: sourceIds.length,
      baselineItems: baselineIds.length,
      newItems: newItemIds.length,
      removedItems: removedItemIds.length,
      changedItems: changed.length,
      unchangedItems: unchangedIds.length,
    },
    changedFieldHistogram,
    samples: {
      newItemIds: newItemIds.slice(0, sampleLimit),
      removedItemIds: removedItemIds.slice(0, sampleLimit),
      changed: changed.slice(0, sampleLimit),
      potentialRenames,
    },
  };
}

function isBuildIdDirName(name) {
  return /^[a-f0-9]{64}$/i.test(name);
}

function getBuildDir(cacheBase, buildId) {
  return path.join(cacheBase, buildId);
}

function findBuildCandidates(cacheBase) {
  if (!fs.existsSync(cacheBase)) return [];
  const dirs = fs
    .readdirSync(cacheBase, { withFileTypes: true })
    .filter((d) => d.isDirectory() && isBuildIdDirName(d.name))
    .map((d) => d.name);
  const rows = [];
  for (const dirName of dirs) {
    const cardsJsonPath = path.join(cacheBase, dirName, 'cards.json');
    if (!fs.existsSync(cardsJsonPath)) continue;
    const st = fs.statSync(cardsJsonPath);
    rows.push({
      buildId: dirName,
      cardsJsonPath,
      mtimeMs: st.mtimeMs,
    });
  }
  rows.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return rows;
}

async function loadFirestoreMap({
  projectId,
  serviceAccountPath,
}) {
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
  }
  const db = admin.firestore();
  const map = new Map();

  const pageSize = 500;
  let lastDoc = null;
  while (true) {
    let query = db
      .collection('catalog_items')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);
    // eslint-disable-next-line no-await-in-loop
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      map.set(doc.id, normalizeFirestoreDoc(doc.id, doc.data() ?? {}));
    }
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  return map;
}

function writeMarkdownReport(markdownPath, report) {
  const lines = [];
  lines.push('# Catalog Review Report');
  lines.push('');
  lines.push(`Generated: ${report.generatedAt}`);
  lines.push(`Current build: ${report.current.buildId}`);
  lines.push(`Current cards file: ${report.current.cardsJsonPath}`);
  lines.push('');
  lines.push('## Current extraction summary');
  lines.push('');
  lines.push(`- total cards in cards.json: ${report.current.summary.totalCards}`);
  lines.push(`- included item docs (seeding shape): ${report.current.summary.includedItems}`);
  lines.push(`- skipped cards: ${report.current.summary.skippedCards}`);
  lines.push('');

  for (const cmp of report.comparisons) {
    lines.push(`## Comparison: current vs ${cmp.baselineLabel}`);
    lines.push('');
    lines.push(`- source items: ${cmp.counts.sourceItems}`);
    lines.push(`- baseline items: ${cmp.counts.baselineItems}`);
    lines.push(`- new items: ${cmp.counts.newItems}`);
    lines.push(`- removed items: ${cmp.counts.removedItems}`);
    lines.push(`- changed items: ${cmp.counts.changedItems}`);
    lines.push('');
    lines.push('### Changed fields histogram');
    lines.push('');
    const histogramEntries = Object.entries(cmp.changedFieldHistogram)
      .sort((a, b) => b[1] - a[1]);
    if (histogramEntries.length === 0) {
      lines.push('- none');
    } else {
      for (const [field, count] of histogramEntries) {
        lines.push(`- ${field}: ${count}`);
      }
    }
    lines.push('');
    lines.push('### Sample new item IDs');
    lines.push('');
    if (cmp.samples.newItemIds.length === 0) {
      lines.push('- none');
    } else {
      for (const id of cmp.samples.newItemIds.slice(0, 25)) {
        lines.push(`- ${id}`);
      }
    }
    lines.push('');
  }

  lines.push('## Review checklist');
  lines.push('');
  lines.push('- Verify changed names are intended (patch rename vs parser mismatch).');
  lines.push('- Review changed tags/hiddenTags and hero assignments.');
  lines.push('- Confirm active/inactive transitions are expected.');
  lines.push('- Validate image overrides and disable list still match unresolved items.');
  lines.push('');

  ensureDir(path.dirname(markdownPath));
  fs.writeFileSync(markdownPath, `${lines.join('\n')}\n`, 'utf8');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node scripts/generate_catalog_review_report.js [--buildId <id>] [--cardsJsonPath <path>] [--baselineBuildId <id>] [--baselineCardsJsonPath <path>] [--projectId <id> --serviceAccount <path>] [--outPath <path>]

Notes:
  - Without --projectId/--serviceAccount, Firestore comparison is skipped.
  - If no baseline is provided, the script compares to the most recent cached prior build.
    `.trim());
    return;
  }

  const cacheBase = path.join(__dirname, '..', '.cache', 'game-builds');
  const buildCandidates = findBuildCandidates(cacheBase);

  let currentBuildId = null;
  let currentCardsJsonPath = null;
  if (typeof args.cardsJsonPath === 'string' && args.cardsJsonPath.trim()) {
    currentCardsJsonPath = path.resolve(args.cardsJsonPath.trim());
    currentBuildId = typeof args.buildId === 'string' ? args.buildId.trim() : 'local';
  } else if (typeof args.buildId === 'string' && args.buildId.trim()) {
    currentBuildId = args.buildId.trim();
    currentCardsJsonPath = path.join(
      getBuildDir(cacheBase, currentBuildId),
      'cards.json',
    );
  } else if (buildCandidates.length > 0) {
    currentBuildId = buildCandidates[0].buildId;
    currentCardsJsonPath = buildCandidates[0].cardsJsonPath;
  } else {
    throw new Error(
      'Could not resolve current cards.json. Provide --buildId or --cardsJsonPath.',
    );
  }

  if (!fs.existsSync(currentCardsJsonPath)) {
    throw new Error(`Current cards.json not found: ${currentCardsJsonPath}`);
  }

  const currentLoaded = loadSeedShapeMapFromCards(currentCardsJsonPath);
  const currentMap = currentLoaded.byId;

  let localBaselineLabel = null;
  let localBaselineMap = null;
  if (typeof args.baselineCardsJsonPath === 'string' && args.baselineCardsJsonPath.trim()) {
    const p = path.resolve(args.baselineCardsJsonPath.trim());
    const loaded = loadSeedShapeMapFromCards(p);
    localBaselineMap = loaded.byId;
    localBaselineLabel = `cards:${p}`;
  } else if (typeof args.baselineBuildId === 'string' && args.baselineBuildId.trim()) {
    const bid = args.baselineBuildId.trim();
    const p = path.join(getBuildDir(cacheBase, bid), 'cards.json');
    if (!fs.existsSync(p)) throw new Error(`Baseline cards.json not found: ${p}`);
    const loaded = loadSeedShapeMapFromCards(p);
    localBaselineMap = loaded.byId;
    localBaselineLabel = `build:${bid}`;
  } else {
    const prior = buildCandidates.find((x) => x.buildId !== currentBuildId);
    if (prior) {
      const loaded = loadSeedShapeMapFromCards(prior.cardsJsonPath);
      localBaselineMap = loaded.byId;
      localBaselineLabel = `build:${prior.buildId}`;
    }
  }

  const comparisons = [];
  if (localBaselineMap) {
    comparisons.push(
      compareMaps({
        sourceMap: currentMap,
        baselineMap: localBaselineMap,
        baselineLabel: localBaselineLabel,
      }),
    );
  }

  const projectId = typeof args.projectId === 'string' ? args.projectId.trim() : '';
  const serviceAccount = typeof args.serviceAccount === 'string'
    ? path.resolve(args.serviceAccount.trim())
    : '';
  if (projectId && serviceAccount) {
    if (!fs.existsSync(serviceAccount)) {
      throw new Error(`Service account file not found: ${serviceAccount}`);
    }
    const firestoreMap = await loadFirestoreMap({
      projectId,
      serviceAccountPath: serviceAccount,
    });
    comparisons.push(
      compareMaps({
        sourceMap: currentMap,
        baselineMap: firestoreMap,
        baselineLabel: `firestore:${projectId}`,
      }),
    );
  }

  const defaultOutPath = path.join(
    getBuildDir(cacheBase, currentBuildId),
    'catalog_review_report.json',
  );
  const outPath = typeof args.outPath === 'string' && args.outPath.trim()
    ? path.resolve(args.outPath.trim())
    : defaultOutPath;

  const markdownPath = outPath.endsWith('.json')
    ? outPath.replace(/\.json$/i, '.md')
    : `${outPath}.md`;

  const report = {
    generatedAt: new Date().toISOString(),
    current: {
      buildId: currentBuildId,
      cardsJsonPath: currentCardsJsonPath,
      summary: {
        versionKey: currentLoaded.versionKey,
        totalCards: currentLoaded.totalCards,
        includedItems: currentLoaded.includedItems,
        skippedCards: currentLoaded.skippedCards,
      },
    },
    comparisons,
  };

  ensureDir(path.dirname(outPath));
  fs.writeFileSync(outPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  writeMarkdownReport(markdownPath, report);

  console.log(`Wrote review JSON: ${outPath}`);
  console.log(`Wrote review markdown: ${markdownPath}`);
  for (const cmp of comparisons) {
    console.log(
      `Comparison ${cmp.baselineLabel}: new=${cmp.counts.newItems} removed=${cmp.counts.removedItems} changed=${cmp.counts.changedItems}`,
    );
  }
  if (comparisons.length === 0) {
    console.log(
      'No baseline comparisons were available. Add --baselineBuildId or Firestore args for a diff.',
    );
  }
}

main().catch((err) => {
  console.error('generate_catalog_review_report failed');
  console.error(err);
  process.exit(1);
});
