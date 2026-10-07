import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';
import * as H from '../harness.mjs';
export { sleep, report, measureFrames } from '../harness.mjs';
export const sleep2 = H.sleep;
const sleep = H.sleep;
export const URL0 = 'http://localhost:8099/';
export const OUTDIR = 'G:/site/gudeteknolojiweb/qa_out/edge-r2';
fs.mkdirSync(OUTDIR, { recursive: true });
const EXE = { edge: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', chrome: 'C:/Program Files/Google/Chrome/Application/chrome.exe' };
export const SZ = { d1440: { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 }, d1024: { viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1 }, d1280: { viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 }, d1920: { viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 } };
export const arg = (i, d) => process.argv[2 + i] ?? d;
export async function openR({ browser = 'edge', size = 'd1440', theme = 'dark', scroll, menu, reduce = false, query = '', noTheme = false, colorScheme } = {}) {
  const q = [noTheme ? '' : 'theme=' + theme, scroll != null ? 'scroll=' + scroll : '', menu ? 'menu=1' : '', query].filter(Boolean).join('&');
  const url = URL0 + (q ? '?' + q : '');
  const errors = [], warnings = [], failed = [], reqs = [], pages = [];
  const b = await chromium.launch({ executablePath: EXE[browser], headless: true, args: ['--enable-gpu-rasterization', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disk-cache-size=1'] });
  const ctx = await b.newContext({ ...SZ[size], locale: 'tr-TR', serviceWorkers: 'block', colorScheme: colorScheme || (theme === 'light' ? 'light' : 'dark'), reducedMotion: reduce ? 'reduce' : 'no-preference' });
  const page = await ctx.newPage();
  page.on('console', (m) => { const t = m.type(); const x = m.text(); if (t === 'error') errors.push('[console.error] ' + x); else if (t === 'warning') warnings.push('[console.warn] ' + x); });
  page.on('pageerror', (e) => errors.push('[pageerror] ' + e.message));
  page.on('requestfailed', (r) => failed.push(`${r.failure()?.errorText} ${r.url()}`));
  page.on('response', (r) => { reqs.push(r.url() + ' ' + r.status()); if (r.status() >= 400) failed.push(`HTTP ${r.status()} ${r.url()}`); });
  ctx.on('page', (p) => pages.push(p));
  const s = { page, ctx, b, browser, size, theme, errors, warnings, failed, reqs, pages, url };
  s.close = async () => { try { await ctx.close(); } catch {} try { await b.close(); } catch {} };
  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 90000 });
  await H.waitForFlutter(page, 90000);
  s.loadMs = Date.now() - t0;
  await sleep(900);
  return s;
}
export async function shotR(s, name, opts = {}) {
  const file = path.join(OUTDIR, `${s.browser}-${s.size}-${s.theme}-${name}.png`);
  await s.page.screenshot({ path: file, ...opts });
  return file;
}
export async function goto(s, q) {
  await s.page.goto(URL0 + '?' + q, { waitUntil: 'load', timeout: 90000 });
  await H.waitForFlutter(s.page, 90000);
  await sleep(1500);
}
export async function nodes(s) {
  await H.enableSemantics(s.page); await sleep(900);
  return s.page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map((n) => {
    const r = n.getBoundingClientRect();
    const text = (n.getAttribute('aria-label') || n.textContent || '').trim().split('\n')[0];
    return { label: text, role: n.getAttribute('role'), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
  }).filter((b) => b.label && b.w > 0 && b.h > 0));
}
export const tap = H.tap;
export async function wheel(s, dy, n = 1, gap = 40) { const vp = s.page.viewportSize(); await s.page.mouse.move(vp.width / 2, vp.height / 2); for (let i = 0; i < n; i++) { await s.page.mouse.wheel(0, dy); await sleep(gap); } }
