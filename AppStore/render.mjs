// Renders AppStore/screenshots.html to App Store-sized PNGs.
//
//   node AppStore/render.mjs
//
// Each artboard is authored at 430x932 CSS px and captured at
// deviceScaleFactor 3 -> 1290x2796, the 6.9" iPhone size App Store
// Connect accepts for every iPhone display size.

import { fileURLToPath, pathToFileURL } from 'node:url';
import { execSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

// Use a local playwright if the repo has one, otherwise fall back to a
// globally installed copy (ESM ignores NODE_PATH, so resolve it by hand).
async function loadPlaywright() {
  try {
    const mod = await import('playwright');
    return mod.chromium ? mod : mod.default;
  } catch {}
  const globalRoot = execSync('npm root -g', { encoding: 'utf8' }).trim();
  const entry = path.join(globalRoot, 'playwright', 'index.js');
  if (!fs.existsSync(entry)) {
    throw new Error('playwright not found — run: npm i -D playwright');
  }
  const mod = await import(pathToFileURL(entry).href);
  return mod.chromium ? mod : mod.default;
}
const { chromium } = await loadPlaywright();

const here = path.dirname(fileURLToPath(import.meta.url));
const NAMES = [
  '01-rainbow', '02-list', '03-two-questions',
  '04-steps', '05-widgets', '06-free',
];
// One artboard set per App Store localisation. The Korean set uses the app's
// own strings; the English one needs the app localised before it can ship
// (see README). Rendering Korean needs a Hangul font on the box —
// `apt-get install fonts-noto-cjk`.
const LOCALES = [
  { lang: 'en', dir: 'en-US' },
  { lang: 'ko', dir: 'ko' },
];
// App Store Connect validates the exact pixel size of each display slot, so
// every slot the app targets gets its own folder. CSS px = pixels / 3.
const SIZES = [
  { key: '1290x2796', w: 430, h: 932 },   // 6.9"
  { key: '1284x2778', w: 428, h: 926 },   // 6.5" / 6.7"
  { key: '1242x2688', w: 414, h: 896 },   // 6.5"
];

const browser = await chromium.launch();
for (const { lang, dir } of LOCALES) {
  for (const { key, w, h } of SIZES) {
    const outDir = path.join(here, dir, key);
    fs.mkdirSync(outDir, { recursive: true });

    const page = await browser.newPage({
      viewport: { width: w, height: h },
      deviceScaleFactor: 3,
    });
    await page.goto(`file://${path.join(here, 'screenshots.html')}?lang=${lang}&size=${key}`);
    await page.waitForTimeout(400);

    const shots = await page.locator('.shot').all();
    if (shots.length !== NAMES.length) {
      throw new Error(`${lang}/${key}: expected ${NAMES.length} artboards, found ${shots.length}`);
    }
    for (const [i, shot] of shots.entries()) {
      const file = path.join(outDir, `${NAMES[i]}.png`);
      await shot.screenshot({ path: file });
      const { width, height } = await shot.boundingBox();
      if (Math.round(width * 3) !== +key.split('x')[0] ||
          Math.round(height * 3) !== +key.split('x')[1]) {
        throw new Error(`${file}: rendered ${width * 3}x${height * 3}, expected ${key}`);
      }
    }
    console.log(`${dir}/${key}/  (${NAMES.length} shots)`);
    await page.close();
  }
}
await browser.close();
