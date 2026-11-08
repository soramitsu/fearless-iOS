#!/usr/bin/env node
// Rasterises the approved winged-sun badge into every iOS brand asset (app icons, launch art, in-app marks).
//
// The wing, disc and keyline paths are never redrawn, re-serialised or re-coloured: each output embeds the
// master SVG text and only changes the background treatment around the mark (spec 2026-11-08, section 1).
// Masters: design/brand/winged-sun-badge-lines.svg (>= 48 px) and winged-sun-badge.svg (< 48 px), copied
// from fearless-wallet-web 1275e1a6 src/assets/brand/ and pinned by SHA-256 below.
//
// Requires sharp 0.35 (librsvg). Usage:
//   SHARP_MODULE=/path/to/node_modules/sharp node scripts/brand/generate-ios-brand-assets.mjs [--check]
// --check renders in memory and fails if any output differs from design/brand/ios-brand-assets.manifest.json.

import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ASSETS = join(ROOT, 'fearless', 'Assets.xcassets');
const MANIFEST = join(ROOT, 'design', 'brand', 'ios-brand-assets.manifest.json');
const MASTERS = {
  lines: { file: 'winged-sun-badge-lines.svg', sha256: '9756447ca43921b8098a52cd860e08dc78910bf23fcfe0e04ec1be036853d4d8' },
  plain: { file: 'winged-sun-badge.svg', sha256: 'ff65329596da5e829c1b704fb8bb89d59ae8065fe6f72d68ba30e368f3b00e89' },
};
const BG = '#151831';

const require = createRequire(import.meta.url);
const sharp = require(process.env.SHARP_MODULE || 'sharp');
const check = process.argv.includes('--check');
const sha256 = (data) => createHash('sha256').update(data).digest('hex');

function master(kind) {
  const { file, sha256: pinned } = MASTERS[kind];
  const text = readFileSync(join(ROOT, 'design', 'brand', file), 'utf8');
  const actual = sha256(Buffer.from(text, 'utf8'));
  if (actual !== pinned) throw new Error(`${file}: sha256 ${actual} is not the approved ${pinned}`);
  return text;
}

const marks = { lines: master('lines'), plain: master('plain') };
const markPaths = Object.fromEntries(Object.entries(marks).map(([kind, text]) => [
  kind, ['badge-wings', 'badge-disc-keyline', 'badge-disc'].map((id) => {
    const match = text.match(new RegExp(`<path id="${id}"[^>]*/>`));
    if (!match) throw new Error(`${MASTERS[kind].file}: no ${id} path`);
    return match[0];
  }),
]));

// The badge's circle carries the gradient; the icon fills the whole square with the same gradient instead.
function fullBleed(kind) {
  const text = marks[kind];
  const circle = text.match(/<path d="M256 512C[^"]*" (fill="url\(#[^)]+\)")\/>/);
  if (!circle) throw new Error(`${MASTERS[kind].file}: badge circle not found`);
  const square = text.replace(circle[0], `<rect width="512" height="512" ${circle[1]}/>`);
  assertMarkIntact(kind, square);
  return square;
}

function assertMarkIntact(kind, svg) {
  for (const path of markPaths[kind]) {
    if (!svg.includes(path)) throw new Error('mark path changed');
  }
}

const markFor = (pixels) => (pixels < 48 ? 'plain' : 'lines');

async function rasterSVG(svg, width, height, { opaque = false } = {}) {
  const viewBox = svg.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/);
  const density = Math.max(72, 72 * Math.max(width / Number(viewBox[1]), height / Number(viewBox[2])) * 2);
  let image = sharp(Buffer.from(svg), { density }).resize(width, height, { fit: 'fill' });
  image = opaque ? image.flatten({ background: BG }).removeAlpha() : image.ensureAlpha();
  return image.png({ compressionLevel: 9, adaptiveFiltering: false, palette: false }).toBuffer();
}

/// The badge (circle included) in a transparent canvas, centred or anchored to the bottom-right corner,
/// optionally with the sun's glow behind it.
function badgeCanvas(kind, canvasWidth, canvasHeight, badgeSide, { glow = false, inset = null } = {}) {
  const text = marks[kind];
  const inner = text.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  const scale = badgeSide / 512;
  const x = inset === null ? (canvasWidth - badgeSide) / 2 : canvasWidth - badgeSide - inset;
  const y = inset === null ? (canvasHeight - badgeSide) / 2 : canvasHeight - badgeSide - inset;
  const glowRadius = badgeSide * 0.8;
  const glowLayer = glow ? `<defs><radialGradient id="fwglow" cx="${x + badgeSide / 2}" cy="${y + badgeSide / 2}" r="${glowRadius}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#EE2233" stop-opacity="0.55"/><stop offset="0.45" stop-color="#EE0077" stop-opacity="0.18"/><stop offset="1" stop-color="#EE0077" stop-opacity="0"/></radialGradient></defs><rect width="${canvasWidth}" height="${canvasHeight}" fill="url(#fwglow)"/>` : '';
  const svg = `<svg width="${canvasWidth}" height="${canvasHeight}" viewBox="0 0 ${canvasWidth} ${canvasHeight}" fill="none" xmlns="http://www.w3.org/2000/svg">${glowLayer}<g transform="translate(${x} ${y}) scale(${scale})">${inner}</g></svg>`;
  assertMarkIntact(kind, svg);
  return svg;
}

// The wide mark's frame in master units: the wings' span and the keyline disc's height, centred on the disc.
const WINGS_BOX = { x: 15, y: 191.5, width: 482, height: 132.4 };

/// The wings, joint and disc at full span, without the badge's circle, for pages with room for them. The paths
/// are the master's own text; only the circle behind them is gone. Optionally the sun's glow, along the wings.
function wingsCanvas(kind, canvasWidth, canvasHeight, wingsWidth, { glow = false } = {}) {
  const gradient = marks[kind].match(/<linearGradient[\s\S]*?<\/linearGradient>/);
  if (!gradient) throw new Error(`${MASTERS[kind].file}: no gradient`);
  const scale = wingsWidth / WINGS_BOX.width;
  const x = (canvasWidth - wingsWidth) / 2 - WINGS_BOX.x * scale;
  const y = (canvasHeight - WINGS_BOX.height * scale) / 2 - WINGS_BOX.y * scale;
  const centreX = canvasWidth / 2;
  const centreY = canvasHeight / 2;
  const glowGradient = glow ? `<radialGradient id="fwglow" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(${centreX} ${centreY}) scale(${centreX} ${centreY})"><stop offset="0" stop-color="#EE2233" stop-opacity="0.55"/><stop offset="0.45" stop-color="#EE0077" stop-opacity="0.18"/><stop offset="1" stop-color="#EE0077" stop-opacity="0"/></radialGradient>` : '';
  const glowLayer = glow ? `<rect width="${canvasWidth}" height="${canvasHeight}" fill="url(#fwglow)"/>` : '';
  const svg = `<svg width="${canvasWidth}" height="${canvasHeight}" viewBox="0 0 ${canvasWidth} ${canvasHeight}" fill="none" xmlns="http://www.w3.org/2000/svg"><defs>${gradient[0]}${glowGradient}</defs>${glowLayer}<g transform="translate(${x} ${y}) scale(${scale})">${markPaths[kind].join('')}</g></svg>`;
  assertMarkIntact(kind, svg);
  return svg;
}

/// The sun-lit page: bg, the sun bounce (brand 18 %, halving every 0.6 widths) and the violet sky.
function pageSVG(width, height) {
  const sunX = width * 0.5;
  const sunY = height * 0.21;
  const reach = 1.44 * width;
  const stops = [0, 0.25, 0.5, 0.75].map((t) => `<stop offset="${t}" stop-color="#EE0077" stop-opacity="${(0.18 * 2 ** (-2.4 * t)).toFixed(4)}"/>`).join('');
  const sky = 0.55 * Math.hypot(width, height);
  return `<svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b" cx="${sunX}" cy="${sunY}" r="${reach}" gradientUnits="userSpaceOnUse">${stops}<stop offset="1" stop-color="#EE0077" stop-opacity="0"/></radialGradient><radialGradient id="s" cx="${width}" cy="${height}" r="${sky}" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#8B5CFF" stop-opacity="0.10"/><stop offset="1" stop-color="#8B5CFF" stop-opacity="0"/></radialGradient></defs><rect width="${width}" height="${height}" fill="${BG}"/><rect width="${width}" height="${height}" fill="url(#s)"/><rect width="${width}" height="${height}" fill="url(#b)"/></svg>`;
}

const outputs = [];
const record = (path, data) => outputs.push({ path, data });

async function appIcons(set) {
  const contents = JSON.parse(readFileSync(join(ASSETS, `${set}.appiconset`, 'Contents.json'), 'utf8'));
  const seen = new Set();
  for (const image of contents.images) {
    if (!image.filename || seen.has(image.filename)) continue;
    seen.add(image.filename);
    const points = Number(image.size.split('x')[0]);
    const pixels = Math.round(points * Number(image.scale.replace('x', '')));
    record(join(ASSETS, `${set}.appiconset`, image.filename), await rasterSVG(fullBleed(markFor(pixels)), pixels, pixels, { opaque: true }));
  }
}

const IMAGESETS = [
  // New sun-lit marks.
  { name: 'fwSunBadge', width: 160, height: 160, badge: 160 },
  { name: 'fwSunBadgeSmall', width: 32, height: 32, badge: 32 },
  { name: 'fwSunGlow', width: 240, height: 240, badge: 128, glow: true },
  // The wide mark for pages with room for the full span; FWWingsView adds the glow.
  { name: 'fwWings', width: 480, height: 132, wings: 480 },
  // The launch art keeps its name and shows the wide mark with its glow.
  { name: 'logo', width: 480, height: 200, wings: 470, glow: true },
  // Old bird assets keep their names and point sizes; the badge replaces the bird.
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
];

async function imagesets() {
  for (const set of IMAGESETS) {
    const images = [];
    for (const scale of [1, 2, 3]) {
      const width = Math.round(set.width * scale);
      const height = Math.round(set.height * scale);
      const badge = set.badge * scale;
      const inset = set.inset === undefined ? null : set.inset * scale;
      const svg = set.wings
        ? wingsCanvas('lines', width, height, set.wings * scale, { glow: set.glow })
        : badgeCanvas(markFor(badge), width, height, badge, { glow: set.glow, inset });
      const filename = `${set.name}@${scale}x.png`;
      record(join(ASSETS, `${set.name}.imageset`, filename), await rasterSVG(svg, width, height));
      images.push({ filename, idiom: 'universal', scale: `${scale}x` });
    }
    record(join(ASSETS, `${set.name}.imageset`, 'Contents.json'), Buffer.from(`${JSON.stringify({ images, info: { author: 'xcode', version: 1 } }, null, 2)}\n`));
  }
  const page = [];
  for (const scale of [2, 3]) {
    const filename = `backgroundImage@${scale}x.png`;
    record(join(ASSETS, 'backgroundImage.imageset', filename), await rasterSVG(pageSVG(375 * scale, 812 * scale), 375 * scale, 812 * scale, { opaque: true }));
    page.push({ filename, idiom: 'universal', scale: `${scale}x` });
  }
  record(join(ASSETS, 'backgroundImage.imageset', 'Contents.json'), Buffer.from(`${JSON.stringify({ images: page, info: { author: 'xcode', version: 1 } }, null, 2)}\n`));
}

await appIcons('AppIcon');
await appIcons('AppIconDev');
await imagesets();

const manifest = {
  generator: 'scripts/brand/generate-ios-brand-assets.mjs',
  masters: Object.values(MASTERS),
  renderer: { sharp: sharp.versions?.sharp ?? null, librsvg: sharp.versions?.rsvg ?? null, vips: sharp.versions?.vips ?? null },
  outputs: Object.fromEntries(outputs.map(({ path, data }) => [relative(ROOT, path), sha256(data)])),
};

if (check) {
  const pinned = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const stale = [...new Set([...Object.keys(manifest.outputs), ...Object.keys(pinned.outputs)])].filter((path) => {
    const hash = manifest.outputs[path];
    const asset = join(ROOT, path);
    return !hash || pinned.outputs[path] !== hash || !existsSync(asset) || sha256(readFileSync(asset)) !== hash;
  });
  if (stale.length) {
    console.error(`differs from the manifest (renderer ${JSON.stringify(manifest.renderer)}):\n${stale.join('\n')}`);
    process.exit(1);
  }
  console.log(`${outputs.length} outputs match the manifest`);
} else {
  for (const { path, data } of outputs) {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, data);
  }
  writeFileSync(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`wrote ${outputs.length} outputs and ${relative(ROOT, MANIFEST)}`);
}
