// SVG'yi Chrome ile PNG'ye çizer. Kullanım: node tool/logo/render_svg.mjs <girdi.svg> <cikti.png> <genislik_px> [zemin: #rrggbb | transparent]
// SVG, file:// yerine data: URL ile yüklenir (boş sayfa file:// görsellerini yüklemez).
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(here, '..', 'qa', 'package.json'));
const { chromium } = require('playwright-core');

const [, , input, output, widthArg, bg = 'transparent'] = process.argv;
if (!input || !output || !widthArg) {
  console.error('kullanım: node render_svg.mjs <girdi.svg> <cikti.png> <genislik> [zemin]');
  process.exit(2);
}
const svgText = fs.readFileSync(input, 'utf8');
const vb = /viewBox="([\d.\s-]+)"/.exec(svgText);
if (!vb) {
  console.error('SVG içinde viewBox yok');
  process.exit(2);
}
const [, , vw, vh] = vb[1].trim().split(/\s+/).map(Number);
const width = Number(widthArg);
const height = Math.round((width * vh) / vw);

const chrome = ['C:/Program Files/Google/Chrome/Application/chrome.exe', 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find((p) => fs.existsSync(p));
const browser = await chromium.launch({ executablePath: chrome, headless: true });
const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
const url = 'data:image/svg+xml;base64,' + Buffer.from(svgText, 'utf8').toString('base64');
await page.setContent(`<!doctype html><html><body style="margin:0;background:${bg}"><img src="${url}" style="display:block;width:${width}px;height:${height}px"></body></html>`);
await page.waitForFunction(() => document.images[0].complete);
await page.screenshot({ path: output, omitBackground: bg === 'transparent' });
await browser.close();
console.log(`${output} (${width}x${height}, zemin ${bg})`);
