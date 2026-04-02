/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const DEFAULT_BUILD_URL =
  'https://data.playthebazaar.com/game/windows/buildx64.zip';

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

function runStep(command, stepArgs) {
  console.log(`\n> ${command} ${stepArgs.join(' ')}`);
  const result = spawnSync(command, stepArgs, {
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  if (result.status !== 0) {
    throw new Error(`Step failed: ${command} ${stepArgs.join(' ')}`);
  }
}

function getPythonCommand() {
  return process.platform === 'win32' ? 'py' : 'python';
}

function isBuildIdDirName(name) {
  return /^[a-f0-9]{64}$/i.test(name);
}

function resolveLatestBuildId(cacheBase) {
  if (!fs.existsSync(cacheBase)) return null;
  const rows = fs
    .readdirSync(cacheBase, { withFileTypes: true })
    .filter((d) => d.isDirectory() && isBuildIdDirName(d.name))
    .map((d) => {
      const cardsPath = path.join(cacheBase, d.name, 'cards.json');
      if (!fs.existsSync(cardsPath)) {
        return { buildId: d.name, mtimeMs: 0 };
      }
      return {
        buildId: d.name,
        mtimeMs: fs.statSync(cardsPath).mtimeMs,
      };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);
  if (rows.length === 0) return null;
  return rows[0].buildId;
}

function getRequiredArg(args, key) {
  const value = args[key];
  if (!value || typeof value !== 'string') {
    throw new Error(`Missing required --${key}`);
  }
  return value.trim();
}

function parseBool(args, key, fallback) {
  if (args[key] === true) return true;
  if (typeof args[key] !== 'string') return fallback;
  const lc = args[key].trim().toLowerCase();
  if (['1', 'true', 'yes', 'y', 'on'].includes(lc)) return true;
  if (['0', 'false', 'no', 'n', 'off'].includes(lc)) return false;
  return fallback;
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function writeLastSeededMetadata({
  repoRoot,
  buildId,
  projectId,
  storageBucket,
  storagePrefix,
  thumbManifestPath,
  fullManifestPath,
}) {
  const metadataDir = path.join(repoRoot, '.cache', 'game-builds', '_metadata');
  ensureDir(metadataDir);
  const metadataPath = path.join(metadataDir, 'last_seeded_build.json');
  const payload = {
    buildId,
    seededAt: new Date().toISOString(),
    projectId,
    storageBucket: storageBucket || null,
    storagePrefix: storagePrefix || 'catalog_items',
    manifests: {
      thumb: thumbManifestPath ? path.resolve(thumbManifestPath) : null,
      full: fullManifestPath ? path.resolve(fullManifestPath) : null,
    },
  };
  fs.writeFileSync(metadataPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`Wrote last-seeded metadata: ${metadataPath}`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  npm run pipeline:game-update -- [--mode review|apply] [--url <build-url>] [--buildId <id>] [--includeImages true|false] [--includeFull true|false] [--outSuffix <suffix>] [--baselineBuildId <id>] [--projectId <id> --serviceAccount <path>] [--confirmApply "I_UNDERSTAND"] [--deactivateMissing] [--applyInactiveNamePolicy true|false]

Modes:
  - review (default): fetch/parse + optional image extraction + review report only.
  - apply: runs review first, then seeds Firestore (requires explicit confirmation).

Defaults:
  - --includeImages false
  - --includeFull true (only used when --includeImages true)
    `.trim());
    return;
  }

  const mode = typeof args.mode === 'string' ? args.mode.trim().toLowerCase() : 'review';
  const pythonCommand = getPythonCommand();

  if (!['review', 'apply'].includes(mode)) {
    throw new Error(`Unsupported --mode "${mode}"`);
  }

  const includeImages = parseBool(args, 'includeImages', false);
  const includeFull = parseBool(args, 'includeFull', true);
  const applyInactiveNamePolicy = parseBool(args, 'applyInactiveNamePolicy', true);
  const outSuffix = typeof args.outSuffix === 'string' && args.outSuffix.trim()
    ? args.outSuffix.trim()
    : `run_${new Date().toISOString().replace(/[:.]/g, '-')}`;
  const url = typeof args.url === 'string' && args.url.trim()
    ? args.url.trim()
    : DEFAULT_BUILD_URL;

  const repoRoot = path.join(__dirname, '..');
  const cacheBase = path.join(repoRoot, '.cache', 'game-builds');
  fs.mkdirSync(cacheBase, { recursive: true });

  const inspectArgs = ['scripts/inspect_cards_json.js', '--inspect'];
  if (args.buildId) inspectArgs.push('--buildId', args.buildId);
  if (url) inspectArgs.push('--url', url);
  runStep('node', inspectArgs);

  const buildId = typeof args.buildId === 'string' && args.buildId.trim()
    ? args.buildId.trim()
    : resolveLatestBuildId(cacheBase);
  if (!buildId) {
    throw new Error(
      'Could not resolve buildId after inspection. Pass --buildId explicitly.',
    );
  }

  const buildDir = path.join(cacheBase, buildId);
  const cardsJsonPath = path.join(buildDir, 'cards.json');
  if (!fs.existsSync(cardsJsonPath)) {
    throw new Error(`cards.json not found for build ${buildId}: ${cardsJsonPath}`);
  }

  let thumbManifestPath = null;
  let fullManifestPath = null;
  if (includeImages) {
    const extractArgs = [
      'scripts/extract_item_images_from_game.py',
      '--buildId',
      buildId,
      '--outDir',
      `exported_item_thumbs_${outSuffix}`,
    ];
    if (includeFull) {
      extractArgs.push('--includeFull', '--fullOutDir', `exported_item_full_${outSuffix}`);
    }
    runStep(pythonCommand, extractArgs);

    thumbManifestPath = path.join(
      buildDir,
      `exported_item_thumbs_${outSuffix}`,
      'manifest.json',
    );
    fullManifestPath = includeFull
      ? path.join(buildDir, `exported_item_full_${outSuffix}`, 'manifest.json')
      : null;

    // Always re-apply deterministic forced asset fixes so historical corrections
    // (for example feather/blue fix) are preserved across migrations.
    const artfixSuffix = `${outSuffix}_artfix`;
    runStep(pythonCommand, [
      'scripts/export_item_images_by_asset_name.py',
      '--buildId',
      buildId,
      '--outSuffix',
      artfixSuffix,
    ]);

    const artfixThumbManifestPath = path.join(
      buildDir,
      `exported_item_thumbs_${artfixSuffix}`,
      'manifest.json',
    );
    const artfixFullManifestPath = path.join(
      buildDir,
      `exported_item_full_${artfixSuffix}`,
      'manifest.json',
    );

    if (thumbManifestPath && fs.existsSync(thumbManifestPath)
      && fs.existsSync(artfixThumbManifestPath)) {
      const mergedThumbPath = path.join(
        buildDir,
        `exported_item_thumbs_${outSuffix}_merged`,
        'manifest.json',
      );
      runStep('node', [
        'scripts/merge_image_manifests.js',
        '--base',
        thumbManifestPath,
        '--overlay',
        artfixThumbManifestPath,
        '--out',
        mergedThumbPath,
      ]);
      thumbManifestPath = mergedThumbPath;
    }

    if (fullManifestPath && fs.existsSync(fullManifestPath)
      && fs.existsSync(artfixFullManifestPath)) {
      const mergedFullPath = path.join(
        buildDir,
        `exported_item_full_${outSuffix}_merged`,
        'manifest.json',
      );
      runStep('node', [
        'scripts/merge_image_manifests.js',
        '--base',
        fullManifestPath,
        '--overlay',
        artfixFullManifestPath,
        '--out',
        mergedFullPath,
      ]);
      fullManifestPath = mergedFullPath;
    }
  }

  const reportArgs = [
    'scripts/generate_catalog_review_report.js',
    '--buildId',
    buildId,
  ];
  if (typeof args.baselineBuildId === 'string' && args.baselineBuildId.trim()) {
    reportArgs.push('--baselineBuildId', args.baselineBuildId.trim());
  }

  const hasFirestoreContext =
    typeof args.projectId === 'string'
    && args.projectId.trim()
    && typeof args.serviceAccount === 'string'
    && args.serviceAccount.trim();
  if (hasFirestoreContext) {
    reportArgs.push(
      '--projectId',
      args.projectId.trim(),
      '--serviceAccount',
      path.resolve(args.serviceAccount.trim()),
    );
  }
  runStep('node', reportArgs);

  const reviewPath = path.join(buildDir, 'catalog_review_report.md');
  console.log('\nReview stage complete.');
  console.log(`BuildId: ${buildId}`);
  console.log(`Review report: ${reviewPath}`);

  if (mode !== 'apply') {
    console.log(
      'Mode is review. No production writes were executed. Re-run with --mode apply when report is approved.',
    );
    return;
  }

  if (!hasFirestoreContext) {
    throw new Error(
      'Apply mode requires --projectId and --serviceAccount.',
    );
  }
  if (args.confirmApply !== 'I_UNDERSTAND') {
    throw new Error(
      'Apply mode requires --confirmApply "I_UNDERSTAND" to prevent accidental writes.',
    );
  }

  const projectId = getRequiredArg(args, 'projectId');
  const serviceAccount = path.resolve(getRequiredArg(args, 'serviceAccount'));
  const seedArgs = [
    'scripts/seed_catalog_from_game.js',
    '--projectId',
    projectId,
    '--serviceAccount',
    serviceAccount,
    '--cardsJsonPath',
    cardsJsonPath,
  ];

  if (typeof args.storageBucket === 'string' && args.storageBucket.trim()) {
    seedArgs.push('--storageBucket', args.storageBucket.trim());
  }
  if (typeof args.storagePrefix === 'string' && args.storagePrefix.trim()) {
    seedArgs.push('--storagePrefix', args.storagePrefix.trim());
  }
  if (typeof args.signedUrlDays === 'string' && args.signedUrlDays.trim()) {
    seedArgs.push('--signedUrlDays', args.signedUrlDays.trim());
  }
  if (args.deactivateMissing === true) {
    seedArgs.push('--deactivateMissing');
  }

  if (thumbManifestPath && fs.existsSync(thumbManifestPath)) {
    seedArgs.push('--thumbImagesManifest', thumbManifestPath);
  }
  if (fullManifestPath && fs.existsSync(fullManifestPath)) {
    seedArgs.push('--fullImagesManifest', fullManifestPath);
  }

  runStep('node', seedArgs);

  const fallbackArgs = [
    'scripts/apply_item_art_fallbacks.js',
    '--projectId',
    projectId,
    '--serviceAccount',
    serviceAccount,
    '--overridesFile',
    path.join(repoRoot, 'data', 'item_art_overrides.json'),
  ];
  runStep('node', fallbackArgs);

  if (applyInactiveNamePolicy) {
    runStep('node', [
      'scripts/deactivate_items_by_name.js',
      '--projectId',
      projectId,
      '--serviceAccount',
      serviceAccount,
    ]);
  }

  if (typeof args.validateItemIds === 'string' && args.validateItemIds.trim()) {
    runStep('node', [
      'scripts/validate_item_image_parity.js',
      '--projectId',
      projectId,
      '--serviceAccount',
      serviceAccount,
      '--itemIds',
      args.validateItemIds.trim(),
    ]);
  }

  const storageBucket = typeof args.storageBucket === 'string' && args.storageBucket.trim()
    ? args.storageBucket.trim()
    : null;
  const storagePrefix = typeof args.storagePrefix === 'string' && args.storagePrefix.trim()
    ? args.storagePrefix.trim()
    : 'catalog_items';
  writeLastSeededMetadata({
    repoRoot,
    buildId,
    projectId,
    storageBucket,
    storagePrefix,
    thumbManifestPath,
    fullManifestPath,
  });

  console.log('Apply stage complete.');
}

main();
