#!/usr/bin/env node
// Builds every iOS brand asset from the shared Yatagarasu brand kit (approved by the owner on 2026-11-10).
//
// The kit (brand/yatagarasu in the workspace, generated from design/yatagarasu-20261110 package r3) is never committed;
// its manifest.json SHA-256 is pinned below and every kit file this script reads must match that manifest. App icons,
// the vector masters and the welcome hero media are copied byte for byte. Fixed-size slots embed the master's drawing
// (everything inside its <svg>) verbatim inside a new frame; the crest and wordmark paths are never redrawn, warped or
// re-serialised, and every output that carries them is checked against the master's path text.
//
// Usage:
//   node scripts/brand/generate-ios-brand-assets.mjs [--kit <dir>]           write the assets and the manifest
//   node scripts/brand/generate-ios-brand-assets.mjs [--kit <dir>] --check   fail if anything differs
//   node scripts/brand/generate-ios-brand-assets.mjs --check --no-kit        committed files against the manifest only
// The kit defaults to $FEARLESS_BRAND_KIT, else the nearest brand/yatagarasu above this checkout. Without a kit,
// --check still verifies the committed assets against design/brand/ios-brand-assets.manifest.json.
// No renderer is involved: the outputs are pure functions of the kit's bytes, so any machine reproduces them.

import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ASSETS = join(ROOT, 'fearless', 'Assets.xcassets');
const MEDIA = join(ROOT, 'fearless', 'Brand');
const MANIFEST = join(ROOT, 'design', 'brand', 'ios-brand-assets.manifest.json');
const KIT_NAME = 'fearless-yatagarasu-brand-kit';
const KIT_MANIFEST_SHA256 = '70771ec29c8607b1964a966066affb15bb02a2032973227d7f7d2ae3c80c048b';

// Brand colours (kit tokens/colors.json). Solar gold and pink light the badge's glow, as FWSunlit's sun does.
const INK = '#120A2E';
const PINK = '#E6006F';
const GOLD = '#FFC24A';
const SKY = '#8B5CFF';

const sha256 = (data) => createHash('sha256').update(data).digest('hex');
const args = process.argv.slice(2);
const check = args.includes('--check');

function findKit() {
  const flag = args.indexOf('--kit');
  if (flag >= 0) return resolve(args[flag + 1]);
  if (process.env.FEARLESS_BRAND_KIT) return resolve(process.env.FEARLESS_BRAND_KIT);
  for (let dir = ROOT; dir !== dirname(dir); dir = dirname(dir)) {
    const candidate = join(dir, 'brand', 'yatagarasu');
    if (existsSync(join(candidate, 'manifest.json'))) return candidate;
  }
  return null;
}

// --no-kit checks only the committed files against the manifest, as a checkout without the workspace kit does.
const KIT = args.includes('--no-kit') ? null : findKit();

function verifyCommitted() {
  const pinned = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const bad = Object.entries(pinned.outputs).filter(([path, hash]) => {
    const file = join(ROOT, path);
    return !existsSync(file) || sha256(readFileSync(file)) !== hash;
  });
  const stray = ownedDirectories(pinned.outputs).flatMap((dir) => readdirSync(join(ROOT, dir))
    .map((name) => join(dir, name)).filter((path) => !(path in pinned.outputs)));
  if (bad.length || stray.length) {
    console.error(`committed brand assets differ from ${relative(ROOT, MANIFEST)}:\n${[...bad.map(([p]) => p), ...stray.map((p) => `${p} (not generated)`)].join('\n')}`);
    process.exit(1);
  }
  console.log(`${Object.keys(pinned.outputs).length} committed outputs match the manifest (no kit found, so not regenerated)`);
}

/// Imageset and media directories whose every file the generator owns.
function ownedDirectories(outputs) {
  return [...new Set(Object.keys(outputs).map(dirname).filter((dir) => !dir.endsWith('.appiconset')))];
}

if (!KIT) {
  if (!check) throw new Error('brand kit not found: pass --kit <dir> or set FEARLESS_BRAND_KIT');
  verifyCommitted();
  process.exit(0);
}

// ---- The kit, pinned

const kitManifestBytes = readFileSync(join(KIT, 'manifest.json'));
if (sha256(kitManifestBytes) !== KIT_MANIFEST_SHA256) {
  throw new Error(`${KIT}/manifest.json: sha256 ${sha256(kitManifestBytes)} is not the approved ${KIT_MANIFEST_SHA256}`);
}
const kitManifest = JSON.parse(kitManifestBytes);
if (kitManifest.kit !== KIT_NAME) throw new Error(`unexpected kit ${kitManifest.kit}`);
const kitHashes = Object.fromEntries(kitManifest.files.map(({ path, sha256: hash }) => [path, hash]));
const consumed = {};

function kitFile(path) {
  const expected = kitHashes[path];
  if (!expected) throw new Error(`${path} is not in the kit manifest`);
  const bytes = readFileSync(join(KIT, path));
  if (sha256(bytes) !== expected) throw new Error(`${path}: sha256 ${sha256(bytes)} differs from the kit manifest`);
  consumed[path] = expected;
  return bytes;
}

const kitText = (path) => kitFile(path).toString('utf8');
/// A master's drawing: everything inside its <svg> element, reused verbatim inside new frames.
const inner = (svg) => svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const pathData = (svg) => [...svg.matchAll(/ d="([^"]+)"/g)].map((match) => match[1]);

const masters = {
  crest: kitText('svg/launch-crest.svg'),
  lockup: kitText('masters/fearless-lockup-stacked.svg'),
  badge: kitText('svg/crest-badge.svg'),
  badgeSmall: kitText('svg/crest-badge-small.svg'),
};
if (masters.crest !== kitText('masters/fearless-crest.svg')) throw new Error('the launch crest is not the master crest');

/// Every path of `master` must appear in `svg` with its exact text.
function assertDrawingIntact(svg, master, label) {
  const paths = pathData(master);
  if (!paths.length) throw new Error(`${label}: master has no paths`);
  for (const d of paths) {
    if (!svg.includes(` d="${d}"`)) throw new Error(`${label}: a master path changed`);
  }
}

// ---- Outputs

const outputs = [];
const record = (path, data) => outputs.push({ path, data: Buffer.isBuffer(data) ? data : Buffer.from(data, 'utf8') });
const contents = (images, properties) => `${JSON.stringify({ images, info: { author: 'xcode', version: 1 }, ...(properties ? { properties } : {}) }, null, 2)}\n`;
const VECTOR = { 'preserves-vector-representation': true, 'template-rendering-intent': 'original' };

/// A single-scale vector imageset holding `svg`.
function vectorImageset(name, svg) {
  record(join(ASSETS, `${name}.imageset`, `${name}.svg`), svg);
  record(join(ASSETS, `${name}.imageset`, 'Contents.json'), contents([{ filename: `${name}.svg`, idiom: 'universal' }], VECTOR));
}

// 1. App icons: the kit's opaque rasters, one per pixel size, under each set's existing filenames.
function appIcons(set, prefix) {
  const json = JSON.parse(readFileSync(join(ASSETS, `${set}.appiconset`, 'Contents.json'), 'utf8'));
  const seen = new Set();
  for (const image of json.images) {
    if (!image.filename || seen.has(image.filename)) continue;
    seen.add(image.filename);
    const pixels = Math.round(Number(image.size.split('x')[0]) * Number(image.scale.replace('x', '')));
    record(join(ASSETS, `${set}.appiconset`, image.filename), kitFile(`png/${prefix}/${prefix}-${pixels}.png`));
  }
}
appIcons('AppIcon', 'app-icon');
appIcons('AppIconDev', 'app-icon-dev');

// 2. Marks copied byte for byte. `logo` is the launch screen's and the root screen's white crest; the stacked lockup
// is the full-page mark (PIN, welcome, onboarding start, About); the badge fills round slots such as the wallet hero.
vectorImageset('logo', masters.crest);
vectorImageset('fwLockupStacked', masters.lockup);
vectorImageset('fwCrestBadge', masters.badge);

// 3. Fixed-size slots. Older screens size themselves from these images' point sizes, so each keeps its name and size
// and shows the badge inside it. Slots under 32 pt (under 64 px at 2x) take the small crest, per the kit's rule.
const glowDefs = (cx, cy, r) => `<radialGradient id="fwglow" cx="${cx}" cy="${cy}" r="${r}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${GOLD}" stop-opacity="0.55"/><stop offset="0.45" stop-color="${PINK}" stop-opacity="0.18"/><stop offset="1" stop-color="${PINK}" stop-opacity="0"/></radialGradient>`;

function badgeFrame({ width, height, badge, glow = false, inset = null }) {
  const master = badge < 32 ? masters.badgeSmall : masters.badge;
  const x = inset === null ? (width - badge) / 2 : width - badge - inset;
  const y = inset === null ? (height - badge) / 2 : height - badge - inset;
  const cx = x + badge / 2;
  const cy = y + badge / 2;
  const light = glow ? `<defs>${glowDefs(cx, cy, badge * 0.8)}</defs><rect width="${width}" height="${height}" fill="url(#fwglow)"/>` : '';
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-label="Fearless">${light}<g transform="translate(${x} ${y}) scale(${badge / 512})">${inner(master)}</g></svg>\n`;
  assertDrawingIntact(svg, master, `${width}x${height}`);
  return svg;
}

const FIXED_SLOTS = [
  { name: 'iconFearlessBig', width: 142, height: 61, badge: 61 },
  { name: 'iconFearlessLog', width: 246, height: 122, badge: 122 },
  { name: 'iconFearlessRounded', width: 40, height: 40, badge: 40 },
  { name: 'iconFearlessSmall', width: 24, height: 24, badge: 24 },
  { name: 'fearlessPink', width: 50, height: 26, badge: 26 },
  { name: 'fearlessRoundedIconSmall', width: 16, height: 16, badge: 16 },
  { name: 'iconBirdGreen', width: 32, height: 32, badge: 32 },
  { name: 'qrFearless', width: 96, height: 43, badge: 43 },
  // The backup banner's art sits in its bottom-right corner, clear of the banner's text and button.
  { name: 'FearlessBanner', width: 175, height: 139, badge: 64, glow: true, inset: 16 },
  // The NFT media placeholder: the badge in its own warm light.
  { name: 'fwCrestBadgeGlow', width: 240, height: 240, badge: 128, glow: true },
];
for (const slot of FIXED_SLOTS) vectorImageset(slot.name, badgeFrame(slot));

// 4. The page paint older screens show behind their content: ink, the brand bounce from the top (pink at 18 %, halving
// every 0.6 widths) and the violet sky from the bottom-right corner, as FWSunlitBackgroundView paints it.
function pageSVG(width, height) {
  const reach = 1.44 * width;
  const stops = [0, 0.25, 0.5, 0.75].map((t) => `<stop offset="${t}" stop-color="${PINK}" stop-opacity="${(0.18 * 2 ** (-2.4 * t)).toFixed(4)}"/>`).join('');
  const sky = 0.55 * Math.hypot(width, height);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><defs><radialGradient id="b" cx="${width * 0.5}" cy="${(height * 0.21).toFixed(2)}" r="${reach.toFixed(2)}" gradientUnits="userSpaceOnUse">${stops}<stop offset="1" stop-color="${PINK}" stop-opacity="0"/></radialGradient><radialGradient id="s" cx="${width}" cy="${height}" r="${sky.toFixed(2)}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="${SKY}" stop-opacity="0.10"/><stop offset="1" stop-color="${SKY}" stop-opacity="0"/></radialGradient></defs><rect width="${width}" height="${height}" fill="${INK}"/><rect width="${width}" height="${height}" fill="url(#s)"/><rect width="${width}" height="${height}" fill="url(#b)"/></svg>\n`;
}
vectorImageset('backgroundImage', pageSVG(375, 812));

// 5. The welcome hero: the looping crow (muted, no audio track), the call (with sound), its poster, and the call's
// sound alone for Reduce Motion. Copied byte for byte into the app bundle.
const HERO = {
  'welcome-idle.mp4': 'hero/welcome-idle.mp4',
  'welcome-caw.mp4': 'hero/welcome-caw.mp4',
  'welcome-poster.webp': 'hero/welcome-poster.webp',
  'welcome-caw.m4a': 'audio/caw.m4a',
};
for (const [name, path] of Object.entries(HERO)) record(join(MEDIA, name), kitFile(path));

// ---- Manifest, write or check

const manifest = {
  generator: 'scripts/brand/generate-ios-brand-assets.mjs',
  kit: {
    name: KIT_NAME,
    manifestSha256: KIT_MANIFEST_SHA256,
    designManifestSha256: kitManifest.source?.designManifestSha256 ?? null,
    files: Object.fromEntries(Object.entries(consumed).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))),
  },
  outputs: Object.fromEntries(outputs.map(({ path, data }) => [relative(ROOT, path), sha256(data)])),
};
const manifestText = `${JSON.stringify(manifest, null, 2)}\n`;
const owned = ownedDirectories(manifest.outputs);

if (check) {
  const stale = outputs.filter(({ path, data }) => !existsSync(path) || !readFileSync(path).equals(data)).map(({ path }) => relative(ROOT, path));
  const stray = owned.flatMap((dir) => (existsSync(join(ROOT, dir)) ? readdirSync(join(ROOT, dir)) : [])
    .map((name) => join(dir, name)).filter((path) => !(path in manifest.outputs)));
  const manifestStale = !existsSync(MANIFEST) || readFileSync(MANIFEST, 'utf8') !== manifestText;
  if (stale.length || stray.length || manifestStale) {
    console.error(`brand assets differ from the kit:\n${[...stale, ...stray.map((p) => `${p} (not generated)`), ...(manifestStale ? [relative(ROOT, MANIFEST)] : [])].join('\n')}`);
    process.exit(1);
  }
  console.log(`${outputs.length} outputs match the kit (${Object.keys(consumed).length} kit files, manifest ${KIT_MANIFEST_SHA256.slice(0, 12)}…)`);
} else {
  for (const dir of owned) rmSync(join(ROOT, dir), { recursive: true, force: true });
  for (const { path, data } of outputs) {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, data);
  }
  writeFileSync(MANIFEST, manifestText);
  console.log(`wrote ${outputs.length} outputs from ${Object.keys(consumed).length} kit files and ${relative(ROOT, MANIFEST)}`);
}
