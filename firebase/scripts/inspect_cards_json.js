/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');
const crypto = require('node:crypto');

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

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function writeJson(filePath, value) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2), 'utf8');
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
  const wanted = entries.find((e) => {
    const normalized = e.entryName.replaceAll('\\', '/');
    const wantedRel = CARDS_JSON_REL_PATH.replaceAll('\\', '/');
    return normalized === wantedRel || normalized.endsWith(`/${wantedRel}`);
  });
  if (!wanted) {
    const ends = entries
      .map((e) => ({ entryName: e.entryName.replaceAll('\\', '/'), e }))
      .filter((x) => x.entryName.toLowerCase().includes('cards.json'))
      .slice(0, 10)
      .map((x) => x.entryName);
    throw new Error(
      `Could not find ${CARDS_JSON_REL_PATH} inside zip. ` +
        `Top matching entries: ${ends.join(', ')}`,
    );
  }
  return wanted;
}

function normalizeToArrayOfCards(json) {
  // Expected: top-level array of card objects.
  if (Array.isArray(json)) return { cards: json, cardListPath: '' };
  if (!json || typeof json !== 'object') {
    throw new Error('cards.json top-level must be array or object');
  }

  const directCandidates = [];
  for (const [k, v] of Object.entries(json)) {
    if (!Array.isArray(v)) continue;
    if (v.length === 0) continue;
    if (v[0] && typeof v[0] === 'object' && !Array.isArray(v[0])) {
      directCandidates.push({ key: k, length: v.length });
    }
  }

  if (directCandidates.length === 1) {
    const { key } = directCandidates[0];
    return { cards: json[key], cardListPath: key };
  }

  // Heuristic: choose the array whose objects have the most likely keys.
  const scoreCardObj = (obj) => {
    if (!obj || typeof obj !== 'object') return 0;
    const keys = Object.keys(obj);
    const lc = new Set(keys.map((x) => x.toLowerCase()));
    let score = 0;
    if (lc.has('name')) score += 1;
    if (lc.has('id') || lc.has('cardid') || lc.has('card_id')) score += 2;
    if (Array.isArray(obj.tags) || lc.has('tags')) score += 1;
    if (lc.has('hero') || lc.has('herotag') || lc.has('heroid')) score += 1;
    if (lc.has('startingrarity') || lc.has('rarity')) score += 1;
    if (lc.has('size')) score += 1;
    return score;
  };

  let best = null;
  for (const [k, v] of Object.entries(json)) {
    if (!Array.isArray(v) || v.length === 0) continue;
    if (!v[0] || typeof v[0] !== 'object' || Array.isArray(v[0])) continue;
    const sampleObj = v[Math.min(0, v.length - 1)];
    const score = scoreCardObj(sampleObj) + Math.log10(v.length + 1);
    if (!best || score > best.score) best = { key: k, score };
  }
  if (!best) {
    throw new Error(
      `Could not locate cards array within cards.json object. Candidates: ${directCandidates
        .map((c) => `${c.key}(${c.length})`)
        .join(', ')}`,
    );
  }

  return { cards: json[best.key], cardListPath: best.key };
}

function isArrayOfStrings(arr) {
  if (!Array.isArray(arr)) return false;
  if (arr.length === 0) return false;
  return arr.every((x) => typeof x === 'string');
}

function normalizeToStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((x) => typeof x === 'string').map((s) => s.trim()).filter((s) => s.length > 0);
}

function traverseForArraysOfStrings(obj, { maxNodes = 50000, maxDepth = 6 } = {}) {
  const out = [];
  let nodes = 0;

  function visit(value, pathParts, depth) {
    nodes += 1;
    if (nodes > maxNodes) return;
    if (depth > maxDepth) return;

    const curPath = pathParts.join('.');

    if (Array.isArray(value)) {
      if (isArrayOfStrings(value)) {
        out.push({
          path: curPath,
          arrayLength: value.length,
          sample: value.slice(0, 5),
        });
      }
      return;
    }

    if (!value || typeof value !== 'object') return;
    for (const [k, v] of Object.entries(value)) {
      visit(v, pathParts.concat([k]), depth + 1);
    }
  }

  visit(obj, [], 0);
  return out;
}

function selectCandidateFieldsFromTraversals(traversals) {
  const byPath = new Map();
  for (const t of traversals) {
    const existing = byPath.get(t.path);
    if (!existing) {
      byPath.set(t.path, t);
    } else {
      byPath.set(t.path, {
        path: t.path,
        arrayLength: Math.max(existing.arrayLength, t.arrayLength),
        sample: existing.sample,
      });
    }
  }
  return Array.from(byPath.values());
}

function guessTagFields(arrayStringFields) {
  const lc = (s) => s.toLowerCase();
  const tagLike = (fieldPath) => {
    const p = lc(fieldPath);
    return (
      p === 'tags' ||
      p.endsWith('.tags') ||
      p.includes('tag') ||
      p.includes('type') && p.includes('tag')
    );
  };

  const hiddenLike = (fieldPath) => lc(fieldPath).includes('hidden');

  const visible = arrayStringFields.filter((f) => tagLike(f.path) && !hiddenLike(f.path));
  const hidden = arrayStringFields.filter((f) => tagLike(f.path) && hiddenLike(f.path));

  // Prefer explicit arrays with names like tags/visibleTags and hiddenTags.
  const pickBest = (arr, preferExact) => {
    if (arr.length === 0) return [];
    if (preferExact) {
      const exact = arr.filter((f) => preferExact.includes(f.path.toLowerCase()));
      if (exact.length) return exact.slice(0, 3);
    }
    return arr.slice(0, 5);
  };

  return {
    visibleTagFields: pickBest(
      visible,
      ['tags', 'tag', 'typeTags', 'types.tags'],
    ),
    hiddenTagFields: pickBest(hidden, ['hiddentags']),
    allVisibleTagCandidates: visible.map((f) => f.path),
    allHiddenTagCandidates: hidden.map((f) => f.path),
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const url = typeof args.url === 'string' ? args.url : DEFAULT_URL;
  const buildIdArg = typeof args.buildId === 'string' ? args.buildId.trim() : '';
  const inspectOnly = args.inspect !== undefined;
  const sampleCount = typeof args.sample === 'string' ? Number(args.sample) : 3;
  const cacheBase = path.join(__dirname, '..', '.cache', 'game-builds');
  const localCardsJsonPath = args.cardsJsonPath;

  ensureDir(cacheBase);

  let snapshot = null;
  let cardsJsonPath = null;

  if (localCardsJsonPath) {
    cardsJsonPath = path.resolve(localCardsJsonPath);
    snapshot = { cardsJsonPath, local: true };
  } else {
    let buildId = buildIdArg;
    let buildDir = null;
    let zipPath = null;
    if (buildIdArg) {
      buildDir = path.join(cacheBase, buildIdArg);
      ensureDir(buildDir);
      zipPath = path.join(buildDir, 'buildx64.zip');
      cardsJsonPath = path.join(buildDir, 'cards.json');
      if (!fs.existsSync(cardsJsonPath)) {
        if (!fs.existsSync(zipPath)) {
          throw new Error(
            `buildId provided but missing cached zip/cards.json for ${buildIdArg}.`,
          );
        }
        console.log('Extracting cards.json from cached zip...');
        const zip = new AdmZip(zipPath);
        const entry = findCardsJsonEntry(zip);
        const out = zip.readFile(entry);
        fs.writeFileSync(cardsJsonPath, out);
      } else {
        console.log(`Using cached extracted cards.json: ${cardsJsonPath}`);
      }
    } else {
      const tmpZipPath = path.join(cacheBase, 'download_buildx64.zip');
      console.log(`Downloading build zip: ${url}`);
      await downloadFile(url, tmpZipPath);
      buildId = await sha256File(tmpZipPath);
      buildDir = path.join(cacheBase, buildId);
      ensureDir(buildDir);
      zipPath = path.join(buildDir, 'buildx64.zip');
      if (!fs.existsSync(zipPath)) fs.copyFileSync(tmpZipPath, zipPath);

      cardsJsonPath = path.join(buildDir, 'cards.json');
      if (!fs.existsSync(cardsJsonPath)) {
        console.log('Extracting cards.json from zip...');
        const zip = new AdmZip(zipPath);
        const entry = findCardsJsonEntry(zip);
        const out = zip.readFile(entry);
        fs.writeFileSync(cardsJsonPath, out);
        console.log(`Extracted to ${cardsJsonPath}`);
      } else {
        console.log(`Using cached extracted cards.json: ${cardsJsonPath}`);
      }
    }

    const reportPath = path.join(buildDir, 'schema_report.json');
    snapshot = {
      buildId,
      url,
      zipPath,
      cardsJsonPath,
      extracted: true,
      reportPath,
    };
  }

  console.log(`Reading cards.json: ${cardsJsonPath}`);
  const jsonText = fs.readFileSync(cardsJsonPath, 'utf8');
  let json;
  try {
    json = JSON.parse(jsonText);
  } catch (e) {
    console.error('Failed to parse cards.json as JSON.');
    throw e;
  }

  const { cards, cardListPath } = normalizeToArrayOfCards(json);
  console.log(`cards array count: ${cards.length}`);

  const cardSamples = cards.slice(0, Math.min(sampleCount, cards.length));
  const sampleTraversals = [];
  for (const c of cardSamples) {
    sampleTraversals.push(
      ...traverseForArraysOfStrings(c, { maxNodes: 50000, maxDepth: 6 }),
    );
  }

  const arrayStringFields = selectCandidateFieldsFromTraversals(sampleTraversals);
  const tagGuess = guessTagFields(arrayStringFields);

  // Detect likely ids and name/hero/rarity/size fields from sample cards.
  const sampleKeyStats = {};
  for (const card of cardSamples) {
    if (!card || typeof card !== 'object') continue;
    for (const [k, v] of Object.entries(card)) {
      sampleKeyStats[k] = (sampleKeyStats[k] ?? 0) + 1;
    }
  }

  const topKeys = Object.entries(sampleKeyStats)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .map(([k]) => k);

  const idCandidates = ['id', 'cardId', 'card_id', 'internalId', 'name'];
  const idFieldCandidates = arrayStringFields
    .map((f) => f.path)
    .filter((p) => p.toLowerCase().endsWith('.id') || idCandidates.includes(path.basename(p)));

  const report = {
    source: {
      url,
      localCardsJsonPath: localCardsJsonPath ? path.resolve(localCardsJsonPath) : null,
    },
    snapshot: snapshot
      ? {
          buildId: snapshot.buildId,
          cardsJsonPath: snapshot.cardsJsonPath,
        }
      : null,
    cardsJson: {
      path: cardsJsonPath,
      sizeBytes: fs.statSync(cardsJsonPath).size,
    },
    cardListPath,
    cardCount: cards.length,
    cardSampleCount: cardSamples.length,
    cardSampleTopKeys: topKeys,
    detectedArrayOfStringsFields: arrayStringFields
      .sort((a, b) => b.arrayLength - a.arrayLength)
      .slice(0, 50),
    tagFieldGuess: tagGuess,
    sampleCards: cardSamples.map((c, idx) => {
      // Extract only the likely tag-related fields and basic identity-ish fields to keep output manageable.
      const basic = {};
      for (const k of Object.keys(c)) {
        if (
          ['name', 'id', 'cardId', 'card_id', 'heroTag', 'hero', 'startingRarity', 'rarity', 'size'].includes(k)
        ) {
          basic[k] = c[k];
        }
      }

      // Grab explicit tags/hiddenTags if present.
      const visibleTags = c.tags ?? c.typeTags ?? c.visibleTags ?? null;
      const hiddenTags = c.hiddenTags ?? c.hidden_tags ?? null;

      return {
        index: idx,
        basic,
        visibleTagsCandidate: normalizeToStringArray(visibleTags),
        hiddenTagsCandidate: normalizeToStringArray(hiddenTags),
        // Keep a small raw view of keys that include tag/hidden for debugging.
        tagKeys: Object.keys(c)
          .filter((k) => k.toLowerCase().includes('tag') || k.toLowerCase().includes('hidden'))
          .reduce((acc, k) => {
            acc[k] = c[k];
            return acc;
          }, {}),
      };
    }),
    generatedAt: new Date().toISOString(),
  };

  const outReportPath = snapshot
    ? snapshot.reportPath
    : path.join(path.dirname(cardsJsonPath), 'schema_report.json');
  writeJson(outReportPath, report);

  console.log(`Wrote report: ${outReportPath}`);
  console.log('Tag field guess (visible vs hidden candidates):');
  console.log(JSON.stringify(tagGuess, null, 2));
  console.log('Next step: update parsing/tag split rules based on schema_report.json.');

  if (!inspectOnly && snapshot) {
    console.log('NOTE: Non-inspect seeding is not implemented in this script yet.');
  }
}

main().catch((err) => {
  console.error('inspect_cards_json failed');
  console.error(err);
  process.exit(1);
});

