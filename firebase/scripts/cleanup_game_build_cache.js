/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_CANONICAL_BUILD_ID =
  '7fa9c6d76587deba235468246222ced7f2a6beb77d2f4a434fa23f1559c04eba';

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

function isBuildIdDirName(name) {
  return /^[a-f0-9]{64}$/i.test(name);
}

function dirSizeBytes(dirPath) {
  let total = 0;
  const stack = [dirPath];
  while (stack.length > 0) {
    const cur = stack.pop();
    if (!fs.existsSync(cur)) continue;
    const entries = fs.readdirSync(cur, { withFileTypes: true });
    for (const e of entries) {
      const full = path.join(cur, e.name);
      if (e.isDirectory()) {
        stack.push(full);
      } else if (e.isFile()) {
        total += fs.statSync(full).size;
      }
    }
  }
  return total;
}

function humanSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KB', 'MB', 'GB', 'TB'];
  let n = bytes / 1024;
  let idx = 0;
  while (n >= 1024 && idx < units.length - 1) {
    n /= 1024;
    idx += 1;
  }
  return `${n.toFixed(1)} ${units[idx]}`;
}

function parseListArg(arg) {
  if (!arg || typeof arg !== 'string') return [];
  return arg
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
}

function readLastSeededMetadata(cacheBase) {
  const metadataPath = path.join(cacheBase, '_metadata', 'last_seeded_build.json');
  if (!fs.existsSync(metadataPath)) {
    return { metadataPath, payload: null };
  }
  try {
    const payload = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
    return { metadataPath, payload };
  } catch {
    return { metadataPath, payload: null };
  }
}

function listExportDirs(buildDir) {
  if (!fs.existsSync(buildDir)) return [];
  return fs
    .readdirSync(buildDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name.startsWith('exported_item_'))
    .map((d) => {
      const fullPath = path.join(buildDir, d.name);
      return {
        name: d.name,
        fullPath,
        mtimeMs: fs.statSync(fullPath).mtimeMs,
      };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);
}

function loadManifestImageDirs(manifestPath) {
  const dirs = new Set();
  if (!manifestPath || !fs.existsSync(manifestPath)) return dirs;
  try {
    const parsed = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const manifest = parsed.manifest && typeof parsed.manifest === 'object'
      ? parsed.manifest
      : parsed;
    for (const row of Object.values(manifest)) {
      if (!row || typeof row !== 'object') continue;
      if (typeof row.imagePath !== 'string' || !row.imagePath.trim()) continue;
      const resolved = path.resolve(row.imagePath.trim());
      dirs.add(path.dirname(resolved));
    }
  } catch {
    // Ignore malformed manifests; cleanup remains conservative.
  }
  return dirs;
}

function chooseMostRecentDirByPrefix(dirs, prefix) {
  const filtered = dirs.filter((d) => d.name.startsWith(prefix));
  if (filtered.length === 0) return null;
  return filtered[0];
}

function listReportFiles(buildDir) {
  const out = [];
  if (!fs.existsSync(buildDir)) return out;
  const stack = [buildDir];
  while (stack.length > 0) {
    const cur = stack.pop();
    const entries = fs.readdirSync(cur, { withFileTypes: true });
    for (const e of entries) {
      const fullPath = path.join(cur, e.name);
      if (e.isDirectory()) {
        stack.push(fullPath);
        continue;
      }
      if (!e.isFile()) continue;
      const n = e.name.toLowerCase();
      if (
        n.includes('report')
        || n === 'schema_report.json'
        || n.startsWith('pathid_scan')
      ) {
        out.push(fullPath);
      }
    }
  }
  return out;
}

function isProtectedReportFile(reportPath, buildId, latestBuildId, canonicalBuildId) {
  const name = path.basename(reportPath).toLowerCase();
  if (buildId === latestBuildId) {
    if (name === 'catalog_review_report.json') return true;
    if (name === 'catalog_review_report.md') return true;
    if (name === 'schema_report.json') return true;
  }
  if (buildId === canonicalBuildId) {
    if (name === 'octopus_trace_report.json') return true;
    if (name.startsWith('pathid_scan') && name.endsWith('.json')) return true;
  }
  return false;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`
Usage:
  node scripts/cleanup_game_build_cache.js [--apply] [--deep] [--cacheBase <path>] [--canonicalBuildId <id>] [--keepBuildIds <id1,id2>] [--deleteOrphanArtMap]

Defaults:
  - Dry-run mode (no deletion) unless --apply is provided.
  - Keeps canonical build, newest build, last-seeded build metadata target, and any --keepBuildIds.
  - Deep mode prunes stale exported_item_* directories inside kept builds, while preserving manifest-linked PNG roots for last-seeded reproducibility.
    `.trim());
    return;
  }

  const apply = args.apply === true;
  const deep = args.deep === true;
  const cacheBase = typeof args.cacheBase === 'string' && args.cacheBase.trim()
    ? path.resolve(args.cacheBase.trim())
    : path.join(__dirname, '..', '.cache', 'game-builds');
  const canonicalBuildId = typeof args.canonicalBuildId === 'string'
    ? args.canonicalBuildId.trim()
    : DEFAULT_CANONICAL_BUILD_ID;
  const keepBuildIds = new Set(parseListArg(args.keepBuildIds));
  keepBuildIds.add(canonicalBuildId);
  const { metadataPath, payload: lastSeeded } = readLastSeededMetadata(cacheBase);
  const lastSeededBuildId = lastSeeded
    && typeof lastSeeded.buildId === 'string'
    && isBuildIdDirName(lastSeeded.buildId)
    ? lastSeeded.buildId
    : null;
  if (lastSeededBuildId) keepBuildIds.add(lastSeededBuildId);

  if (!fs.existsSync(cacheBase)) {
    console.log(`Cache base does not exist: ${cacheBase}`);
    return;
  }

  const buildRows = fs
    .readdirSync(cacheBase, { withFileTypes: true })
    .filter((d) => d.isDirectory() && isBuildIdDirName(d.name))
    .map((d) => {
      const fullPath = path.join(cacheBase, d.name);
      const cardsPath = path.join(fullPath, 'cards.json');
      const mtimeMs = fs.existsSync(cardsPath)
        ? fs.statSync(cardsPath).mtimeMs
        : fs.statSync(fullPath).mtimeMs;
      return {
        buildId: d.name,
        fullPath,
        mtimeMs,
        hasCards: fs.existsSync(cardsPath),
      };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  if (buildRows.length > 0) {
    keepBuildIds.add(buildRows[0].buildId);
  }
  const latestBuildId = buildRows.length > 0 ? buildRows[0].buildId : null;

  const removableBuilds = [];
  for (const row of buildRows) {
    if (keepBuildIds.has(row.buildId)) continue;
    removableBuilds.push(row);
  }

  const orphanCandidates = [];
  const artMapPath = path.join(__dirname, '..', 'data', 'artkey_to_bestAsset_compact.json');
  if (args.deleteOrphanArtMap === true && fs.existsSync(artMapPath)) {
    orphanCandidates.push(artMapPath);
  }

  const deepRemovals = [];
  const deepReportRemovals = [];
  if (deep) {
    for (const row of buildRows) {
      if (!keepBuildIds.has(row.buildId)) continue;

      if (row.buildId !== canonicalBuildId) {
        const exportDirs = listExportDirs(row.fullPath);
        if (exportDirs.length > 0) {
          const protectedPaths = new Set();
          if (lastSeeded && row.buildId === lastSeededBuildId) {
            const thumbManifestPath = lastSeeded.manifests?.thumb;
            const fullManifestPath = lastSeeded.manifests?.full;
            for (const p of [thumbManifestPath, fullManifestPath]) {
              if (typeof p !== 'string' || !p.trim()) continue;
              const manifestAbs = path.resolve(p);
              if (!manifestAbs.startsWith(path.resolve(row.fullPath))) continue;
              protectedPaths.add(path.dirname(manifestAbs));
              for (const imgDir of loadManifestImageDirs(manifestAbs)) {
                if (imgDir.startsWith(path.resolve(row.fullPath))) {
                  protectedPaths.add(imgDir);
                }
              }
            }
          }

          // Safety: when last-seeded metadata has no manifest paths (for example
          // apply run executed without --includeImages), do not deep-prune this
          // build since we cannot prove which export roots are required.
          if (row.buildId !== lastSeededBuildId || protectedPaths.size > 0) {
            // Keep one latest full/thumb export pair for non-last-seeded latest build.
            if (row.buildId === latestBuildId && row.buildId !== lastSeededBuildId) {
              const latestThumb = chooseMostRecentDirByPrefix(exportDirs, 'exported_item_thumbs_');
              const latestFull = chooseMostRecentDirByPrefix(exportDirs, 'exported_item_full_');
              if (latestThumb) protectedPaths.add(latestThumb.fullPath);
              if (latestFull) protectedPaths.add(latestFull.fullPath);
            }

            const candidates = exportDirs.filter((d) => !protectedPaths.has(d.fullPath));
            if (candidates.length > 0) {
              deepRemovals.push({
                buildId: row.buildId,
                protectedCount: protectedPaths.size,
                dirs: candidates,
              });
            }
          }
        }
      }

      const reportCandidates = listReportFiles(row.fullPath)
        .filter((p) => !isProtectedReportFile(
          p,
          row.buildId,
          latestBuildId,
          canonicalBuildId,
        ));
      if (reportCandidates.length > 0) {
        deepReportRemovals.push({
          buildId: row.buildId,
          files: reportCandidates,
        });
      }
    }
  }

  let reclaimableBytes = 0;
  for (const row of removableBuilds) {
    reclaimableBytes += dirSizeBytes(row.fullPath);
  }
  for (const bucket of deepRemovals) {
    for (const d of bucket.dirs) {
      reclaimableBytes += dirSizeBytes(d.fullPath);
    }
  }
  for (const bucket of deepReportRemovals) {
    for (const f of bucket.files) {
      if (!fs.existsSync(f)) continue;
      reclaimableBytes += fs.statSync(f).size;
    }
  }
  for (const p of orphanCandidates) {
    reclaimableBytes += fs.statSync(p).size;
  }

  console.log(`Mode: ${apply ? 'APPLY' : 'DRY-RUN'}`);
  console.log(`Deep mode: ${deep ? 'ON' : 'OFF'}`);
  console.log(`Cache base: ${cacheBase}`);
  console.log(`Canonical build: ${canonicalBuildId}`);
  console.log(`Last-seeded metadata: ${metadataPath}`);
  console.log(`Last-seeded build: ${lastSeededBuildId ?? '(none)'}`);
  console.log(`Keeping builds: ${Array.from(keepBuildIds).join(', ')}`);
  console.log(`Removable build dirs: ${removableBuilds.length}`);
  for (const row of removableBuilds) {
    console.log(`- ${row.buildId}`);
  }
  if (deepRemovals.length > 0) {
    console.log('Deep removable export dirs inside kept builds:');
    for (const bucket of deepRemovals) {
      console.log(`- build ${bucket.buildId}: ${bucket.dirs.length} dirs (protected roots=${bucket.protectedCount})`);
      for (const d of bucket.dirs) {
        console.log(`  - ${d.name}`);
      }
    }
  }
  if (deepReportRemovals.length > 0) {
    console.log('Deep removable report files inside kept builds:');
    for (const bucket of deepReportRemovals) {
      console.log(`- build ${bucket.buildId}: ${bucket.files.length} files`);
      for (const f of bucket.files) {
        console.log(`  - ${path.relative(cacheBase, f)}`);
      }
    }
  }
  if (orphanCandidates.length > 0) {
    console.log('Optional orphan file candidates:');
    for (const p of orphanCandidates) console.log(`- ${p}`);
  }
  console.log(`Estimated reclaimable size: ${humanSize(reclaimableBytes)}`);

  if (!apply) {
    console.log('Dry-run complete. Re-run with --apply to delete listed paths.');
    return;
  }

  for (const row of removableBuilds) {
    fs.rmSync(row.fullPath, { recursive: true, force: true });
  }
  for (const bucket of deepRemovals) {
    for (const d of bucket.dirs) {
      fs.rmSync(d.fullPath, { recursive: true, force: true });
    }
  }
  for (const bucket of deepReportRemovals) {
    for (const f of bucket.files) {
      fs.rmSync(f, { force: true });
    }
  }
  for (const p of orphanCandidates) {
    fs.rmSync(p, { force: true });
  }
  console.log('Cleanup completed.');
}

main();
