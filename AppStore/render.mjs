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

const browser = await chromium.launch();
for (const { lang, dir } of LOCALES) {
  const outDir = path.join(here, dir);
  fs.mkdirSync(outDir, { recursive: true });

  const page = await browser.newPage({
    viewport: { width: 430, height: 932 },
    deviceScaleFactor: 3,
  });
  await page.goto(`file://${path.join(here, 'screenshots.html')}?lang=${lang}`);
  await page.waitForTimeout(400);

  const shots = await page.locator('.shot').all();
  if (shots.length !== NAMES.length) {
    throw new Error(`${lang}: expected ${NAMES.length} artboards, found ${shots.length}`);
  }
  for (const [i, shot] of shots.entries()) {
    await shot.screenshot({ path: path.join(outDir, `${NAMES[i]}.png`) });
    console.log(`${dir}/${NAMES[i]}.png`);
  }
  await page.close();
}
await browser.close();
