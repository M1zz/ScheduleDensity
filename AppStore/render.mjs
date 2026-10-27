// Renders AppStore/screenshots.html to App Store-sized PNGs.
//
//   node AppStore/render.mjs                # every language
//   node AppStore/render.mjs zh-Hant ko     # only these (lang or folder name)
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
  // PLAYWRIGHT_DIR=/some/node_modules/playwright points at a copy kept
  // outside the repo.
  const globalRoot = execSync('npm root -g', { encoding: 'utf8' }).trim();
  const entry = process.env.PLAYWRIGHT_DIR
    ? path.join(process.env.PLAYWRIGHT_DIR, 'index.js')
    : path.join(globalRoot, 'playwright', 'index.js');
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
  '04-steps', '05-widgets',
];
// One artboard set per App Store localisation. The Korean set uses the app's
// own strings; the English one needs the app localised before it can ship
// (see README). Rendering Korean / Chinese needs CJK fonts on the box —
// macOS ships Apple SD Gothic Neo and PingFang TC; on Linux
// `apt-get install fonts-noto-cjk`.
const ALL_LOCALES = [
  { lang: 'en', dir: 'en-US' },
  { lang: 'en-GB', dir: 'en-GB' },      // British English: day-first dates, British spelling
  { lang: 'ko', dir: 'ko' },
  { lang: 'zh-Hant', dir: 'zh-Hant' },   // Traditional Chinese (Taiwan)
  ...['zh-Hans', 'ja', 'de', 'es', 'fr', 'it', 'pt-BR', 'ru', 'cs', 'da', 'el',
      'fi', 'id', 'nb', 'nl', 'pl', 'sv', 'th', 'tr', 'vi'].map(lang => ({ lang, dir: lang })),
];
// Optional filter: `node AppStore/render.mjs zh-Hant` re-renders one set and
// leaves the others' PNGs untouched.
const only = process.argv.slice(2);
const LOCALES = only.length
  ? ALL_LOCALES.filter(l => only.includes(l.lang) || only.includes(l.dir))
  : ALL_LOCALES;
if (only.length && LOCALES.length !== only.length) {
  throw new Error(`unknown language in ${only.join(' ')} — known: ${ALL_LOCALES.map(l => l.lang).join(', ')}`);
}
// App Store Connect validates the exact pixel size of each display slot, so
// every slot the app targets gets its own folder. CSS px = pixels / 3.
const ONLY_SIZE = process.env.SIZE;  // SIZE=1398x2034 renders just that slot
const SIZES_ALL = [
  { key: '1290x2796', w: 430, h: 932 },   // 6.9"
  { key: '1284x2778', w: 428, h: 926 },   // 6.5" / 6.7"
  { key: '1242x2688', w: 414, h: 896 },   // 6.5"
  { key: '1398x2034', w: 466, h: 678 },   // iPhone Duo, outer screen
];
const SIZES = ONLY_SIZE ? SIZES_ALL.filter(s => s.key === ONLY_SIZE) : SIZES_ALL;
if (!SIZES.length) throw new Error(`unknown SIZE ${ONLY_SIZE}`);

const DUO_KEY = '1398x2034';
// marketing folders use the store locale; Norwegian is kept under both nb and no.
const MARKETING_DIRS = { 'en-US': ['en'], nb: ['nb', 'no'] };

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
    // The Duo set also goes where DeployBar picks shots up, next to the
    // iPhone ones: docs/screenshots/marketing/<store locale>/duo-01-....png.
    // DeployBar tells the devices apart by pixel size (1398x2034 = Duo).
    if (key === DUO_KEY) {
      for (const store of MARKETING_DIRS[dir] || [dir]) {
        const mDir = path.join(here, '..', 'docs', 'screenshots', 'marketing', store);
        fs.mkdirSync(mDir, { recursive: true });
        for (const n of NAMES) fs.copyFileSync(path.join(outDir, `${n}.png`), path.join(mDir, `duo-${n}.png`));
      }
    }
    console.log(`${dir}/${key}/  (${NAMES.length} shots)`);
    await page.close();
  }
}
await browser.close();
