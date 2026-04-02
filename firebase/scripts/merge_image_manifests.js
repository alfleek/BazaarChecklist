/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');

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
  if (!value || typeof value !== 'string' || !value.trim()) {
    throw new Error(`Missing required --${key}`);
  }
  return path.resolve(value.trim());
}

function loadManifest(p) {
  const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
  const manifest = raw.manifest && typeof raw.manifest === 'object'
    ? raw.manifest
    : raw;
  return {
    root: raw,
    manifest,
    failedItemIds: Array.isArray(raw.failedItemIds) ? raw.failedItemIds : [],
  };
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node scripts/merge_image_manifests.js --base <baseManifest.json> --overlay <overlayManifest.json> --out <outManifest.json>

Behavior:
  - Keeps all base entries.
  - Overlay entries replace base entries for matching item IDs.
  - Preserves remaining base failedItemIds, removing IDs recovered by overlay.
    `.trim());
    return;
  }

  const basePath = getRequiredArg(args, 'base');
  const overlayPath = getRequiredArg(args, 'overlay');
  const outPath = getRequiredArg(args, 'out');

  if (!fs.existsSync(basePath)) {
    throw new Error(`Base manifest not found: ${basePath}`);
  }
  if (!fs.existsSync(overlayPath)) {
    throw new Error(`Overlay manifest not found: ${overlayPath}`);
  }

  const base = loadManifest(basePath);
  const overlay = loadManifest(overlayPath);

  const mergedManifest = { ...base.manifest, ...overlay.manifest };
  const recoveredByOverlay = new Set(Object.keys(overlay.manifest));
  const mergedFailed = base.failedItemIds.filter((id) => !recoveredByOverlay.has(id));

  const out = {
    manifest: mergedManifest,
    failedItemIds: mergedFailed,
    merge: {
      basePath,
      overlayPath,
      mergedAt: new Date().toISOString(),
      baseCount: Object.keys(base.manifest).length,
      overlayCount: Object.keys(overlay.manifest).length,
      mergedCount: Object.keys(mergedManifest).length,
      baseFailedCount: base.failedItemIds.length,
      mergedFailedCount: mergedFailed.length,
      recoveredCount: base.failedItemIds.length - mergedFailed.length,
    },
  };

  ensureDir(path.dirname(outPath));
  fs.writeFileSync(outPath, `${JSON.stringify(out, null, 2)}\n`, 'utf8');

  console.log(`Merged manifest written: ${outPath}`);
  console.log(
    `base=${Object.keys(base.manifest).length} overlay=${Object.keys(overlay.manifest).length} merged=${Object.keys(mergedManifest).length}`,
  );
  console.log(
    `failed base=${base.failedItemIds.length} merged=${mergedFailed.length}`,
  );
}

main();
